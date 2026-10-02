# Imagem Docker e deploy

> **Este repositório não faz deploy sozinho.** O app completo (backend +
> frontend) é instalado e sobe pelo repositório principal
> [ishinydex](https://github.com/nunesvictor/ishinydex), que traz este código
> como submodule e constrói a imagem com o [Dockerfile](../Dockerfile) daqui:
>
> ```bash
> git clone --recurse-submodules https://github.com/nunesvictor/ishinydex.git
> cd ishinydex && cp .env.example .env   # troque os change-me
> docker compose up -d --build           # app em http://<ip-do-pc>:8090
> ```
>
> Este guia explica **como a imagem funciona** (build, nginx, cache). Para
> desenvolver, use o `flutter run` (ver o [README](../README.md)).

O app fica acessível pelo navegador do PC e de qualquer celular na mesma rede
Wi-Fi, em `http://<ip-do-pc>:8090`, e volta sozinho quando o PC reinicia
(`restart: unless-stopped` no compose do repositório principal).

## Como funciona

```
Navegador (PC ou celular)
        │  http://192.168.0.193:8090
        ▼
┌──────────────── container "frontend" (imagem deste repositório) ─┐
│ nginx                                                            │
│   /                         → arquivos do app (build web)        │
│   /api/ /media/ /static/ /admin/ → repassa para o backend  ──────┼──┐
└──────────────────────────────────────────────────────────────────┘  │
                                                                      │ http://backend:8000
┌──────────────── container "backend" (imagem do ishinydex-backend) ┐  │ (rede interna do compose)
│ uwsgi + Django                                              ◄────┼──┘
└──────────────────────────────────────────────────────────────────┘
```

Três conceitos que aparecem aqui:

- **Build multi-stage** ([Dockerfile](../Dockerfile)): o primeiro estágio tem o
  SDK do Flutter (~2 GB) e compila o app para web. O segundo estágio copia só o
  resultado (`build/web`) para uma imagem **nginx**. O SDK não vai para a
  imagem final, que fica com ~150 MB.
- **Proxy reverso** ([default.conf.template](../deploy/nginx/default.conf.template)):
  o nginx recebe todas as requisições. As que começam com `/api`, `/media`,
  `/static` ou `/admin` ele repassa para o backend e devolve a resposta. O
  navegador nem sabe que existe outro servidor.
  O nome do backend é resolvido **a cada requisição** (`resolver` +
  `proxy_pass` com variável), e não só quando o nginx inicia. Sem isso, com o
  backend parado o nginx nem subia (`host not found in upstream`) e o app
  inteiro ficava fora do ar (issue #46). Agora o app carrega e só as rotas do
  backend respondem 502.
- **Mesma origem**: para o navegador, app e API estão no mesmo endereço
  (`http://ip:8090`). Por isso não existe CORS, e o app é compilado com
  `API_BASE_URL=/api`, uma URL relativa ao endereço da página. O mesmo build
  funciona em `localhost`, no IP da rede ou em qualquer domínio futuro.
- **WebAssembly** (issue #91): por padrão a imagem é compilada com
  `flutter build web --wasm`, que gera dois builds. O loader do Flutter
  escolhe no navegador: o build em WebAssembly, com o renderizador `skwasm`,
  nos navegadores Chromium (Chrome, Brave, Edge), onde o app fica bem mais
  fluido; e o JavaScript (`main.dart.js` + CanvasKit) nos demais. Safari e
  Firefox ficam no JavaScript por padrão do Flutter: num teste no iPhone
  liberando o wasm (`wasmAllowList`), o ganho foi sutil e não compensa o risco
  de defeitos do WebKit. O nginx serve o `main.dart.mjs` como
  `application/javascript` (o `mime.types` dele não conhece `.mjs`).
- **Cache com endereço versionado**: o Flutter sempre gera os mesmos nomes
  (`main.dart.js`, `assets/...`), e um cache longo nesses nomes faria o
  navegador rodar a versão antiga depois de um deploy (issue #5). Por isso:
  - no build, o [Dockerfile](../Dockerfile) calcula um hash do código
    (`main.dart.js` e, com wasm, `main.dart.wasm` e `main.dart.mjs`) e dos
    assets e o grava no
    [`web/flutter_bootstrap.js`](../web/flutter_bootstrap.js), que carrega o
    app de `/v/<hash>/` (`entrypointBaseUrl` e `assetBase` do loader);
  - o nginx serve `/v/<hash>/...` com cache de um ano (`immutable`), porque
    cada versão tem um endereço novo; todo o resto é `no-cache`, com
    revalidação barata por ETag.

  O `index.html` e o `flutter_bootstrap.js` são sempre revalidados, então o
  navegador passa a pedir os endereços novos assim que a versão nova sobe. Fora
  do Docker (`flutter run`, CI), o marcador `__BUILD_VERSION__` não é trocado e
  tudo carrega da raiz, como no padrão.

O nginx repassa o cabeçalho `Host` original, então o Django gera as URLs dos
sprites com o endereço que o navegador usou
(`http://192.168.0.193:8090/media/...`).

## Configuração da imagem

| Variável | Padrão | Uso |
| --- | --- | --- |
| `BACKEND_URL` (ambiente do container) | definido pelo compose principal (`http://backend:8000`) | Backend para onde o nginx repassa a API |
| `WEB_WASM` (build arg) | `true` | Gera também o build em WebAssembly. `false` volta ao build só JavaScript (no compose principal: `X_WEB_WASM`) |

A porta publicada (`X_WEB_PORT`, padrão `8090`) e o dia a dia (atualizar,
logs, backup) ficam no repositório principal: veja o README e o `CLAUDE.md`
de lá. Se o celular não abrir a página, libere a porta no firewall (só se o
`ufw` estiver ativo; confira com `sudo ufw status`): `sudo ufw allow 8090/tcp`.

> **Dica:** o IP pode mudar quando o roteador reinicia. Para evitar isso,
> reserve um IP fixo para o PC nas configurações de DHCP do roteador.

## Login e armazenamento do token

Na web, o token fica no `localStorage` do navegador
([`PrefsTokenStorage`](../lib/features/auth/data/token_storage.dart)). O
armazenamento "seguro" da web depende de WebCrypto, que o navegador só libera
em **HTTPS ou localhost**. Pelo IP da rede, em HTTP, o login falharia. No app
nativo de iOS, o token continua no Keychain.

## Problemas comuns

| Sintoma | Causa provável |
| --- | --- |
| Tela de erro "Erro no servidor" / nginx responde **502** | O backend está parado. No repositório principal: `docker compose ps` e `docker compose logs backend`. |
| API responde **500** e o log do backend mostra `MemoryError` | Limite de memória do uwsgi (`limit-as` em `src/uwsgi/django-pokedex.ini` do backend) curto demais. Em 2026-09 foi preciso subir de 1024 para 2048 MB e fixar `offload-threads = 2`; o padrão `%k` cria uma thread por núcleo. |
| Celular não abre a página | Celular em outra rede (ex.: 4G), firewall bloqueando a porta 8090, ou IP mudou. |
| Mudança no código não aparece | O submodule não foi atualizado (PR de bump no principal) ou faltou `--build` no `docker compose up`. Depois, recarregue a página: o `flutter_bootstrap.js` nunca fica em cache e aponta para `/v/<hash>/` da versão nova. Para conferir a versão no ar: `curl -s localhost:8090/flutter_bootstrap.js \| grep buildVersion`. |
| Sprites sem imagem | Veja se `http://<ip>:8090/media/sprites/pokemon/other/home/1.png` abre. Se não abrir, o volume `sprites` não foi populado (serviço `sprites` do compose principal). |

## Próximos passos (fora do escopo por enquanto)

- **HTTPS** (acesso fora de casa, offline): hoje desnecessário; se um dia precisar, ver a nota sobre Tailscale em [04-ios-e-pwa.md](04-ios-e-pwa.md).
