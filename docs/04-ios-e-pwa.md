# iPhone: atalho do Safari (PWA) e .ipa

Há dois jeitos de ter o app no iPhone:

| | **Atalho do Safari / PWA** (o que usamos) | **.ipa nativo (sideload)** |
| --- | --- | --- |
| Como instala | Safari → Compartilhar → "Adicionar à Tela de Início" | Gerado no GitHub Actions e instalado com Sideloadly/AltStore |
| Custo | Zero | Zero (o repositório é público: minutos de macOS ilimitados) |
| Validade | Não expira | **7 dias** com Apple ID gratuito (1 ano com conta paga de US$ 99/ano) |
| Atualização | Automática a cada deploy | Novo build + reinstalar |
| Precisa de | O app no ar na rede local (`http://<ip-do-pc>:8090`) | Windows ou macOS com Sideloadly/AltServer (no Linux, só ferramentas não oficiais) |

A web já é requisito do projeto, então o atalho do Safari sai de graça e é o
caminho atual. O `.ipa` fica documentado como alternativa (ver o fim deste
guia).

---

## Atalho do Safari (PWA sem HTTPS)

### 1. App no ar

Build e hospedagem já estão resolvidos pelo compose do repositório principal
[ishinydex](https://github.com/nunesvictor/ishinydex) (nginx em `:8090`, app
compilado com `API_BASE_URL=/api`, ver [06-deploy-local.md](06-deploy-local.md)).
Não precisa de mais nada: nem HTTPS, nem domínio, nem build separado.

### 2. Instalar no iPhone

1. Com o iPhone na **mesma rede Wi-Fi** do PC, abra
   `http://<ip-do-pc>:8090` no **Safari** (ex.: `http://192.168.0.193:8090`).
2. Toque em **Compartilhar** → **Adicionar à Tela de Início**.
3. O ícone aparece na Tela de Início e o app abre em **tela cheia**, sem a
   barra do Safari, com o nome e o ícone do [manifest](../web/manifest.json)
   e das metatags `apple-mobile-web-app-*` do
   [index.html](../web/index.html).

**Barra de status (relógio, sinal, bateria):** acompanha o modo claro/escuro
do sistema. O iOS pinta a barra com o `theme-color` da página
(`apple-mobile-web-app-status-bar-style=default`) e escolhe o texto que
contrasta. O `index.html` traz um `theme-color` por modo (a cor do AppBar de
cada tema, conferida em `test/web_index_test.dart`), e o app atualiza a cor ao
trocar de modo com ele aberto (`Title` no `builder` de
[app.dart](../lib/app.dart)). Depois de mudar o `index.html`, remova e
recrie o atalho se a barra não mudar: o iOS guarda parte da configuração na
hora em que o atalho é criado.

Uso real testado em 30/09/2026. A decisão de não usar HTTPS está em
[ishinydex#10](https://github.com/nunesvictor/ishinydex/issues/10).

### No GitHub Pages (modo local): HTTPS e offline

No Pages (`https://nunesvictor.github.io/ishinydex/`), com HTTPS, o
navegador libera o **service worker**. O nosso ([web/sw.js](../web/sw.js))
guarda cada arquivo do app na primeira vez que ele é usado, sem lista fixa:

- versionados (`v/<hash>/`, `canvaskit/`): **cache primeiro**, porque nunca
  mudam (um build novo tem outro hash);
- o resto do site (`index.html`, `flutter_bootstrap.js`, manifesto,
  `catalog/catalog.json`): **rede primeiro**, com o cache de reserva, então
  uma versão nova chega assim que há internet;
- sprites: cache primeiro, num cache próprio que sobrevive às versões;
- `/api/`, `/admin/` e o que não é GET nunca passam pelo cache.

O cache tem a versão do build no nome (`__BUILD_VERSION__`, trocado no build
como no `flutter_bootstrap.js`); ao ativar uma versão nova, fica também a
anterior, para o app abrir offline mesmo logo depois de uma atualização.
Depois de um uso online, o app abre e funciona **sem internet**, porque os
dados já estão no aparelho.

### O que funciona e o que não funciona sem HTTPS

Em HTTP (fora de `localhost`), o navegador não libera recursos de "contexto
seguro": **service worker** e **WebCrypto**.

| Recurso | Sem HTTPS | Faz falta? |
| --- | --- | --- |
| Tela cheia, ícone e nome na Tela de Início | ✅ funciona | — |
| Login e uso normal do app | ✅ funciona | — |
| Atualização a cada deploy | ✅ automática (o `flutter_bootstrap.js` é sempre revalidado; ver [06-deploy-local.md](06-deploy-local.md)) | — |
| Token salvo | ✅ no `localStorage` ([`PrefsTokenStorage`](../lib/features/auth/data/token_storage.dart)), porque o armazenamento seguro da web depende de WebCrypto | Não: o app só é acessível na rede de casa |
| Uso **offline** | ❌ (precisa de service worker) | Não: sem o backend não há dados para mostrar |
| Cache do app para abrir sem rede | ❌ (service worker) | Não, pelo mesmo motivo |
| Notificações push | ❌ (service worker + HTTPS) | Não usamos |

### Com o servidor fora do ar

| Situação | O que o iPhone mostra |
| --- | --- |
| PC desligado, fora da rede ou nginx parado | O Safari mostra "não foi possível conectar ao servidor": não há nada para carregar. |
| Só o backend parado | O app carrega normalmente (o nginx serve os arquivos), e as telas que dependem da API mostram o erro do servidor (nginx responde **502**; issue #46). Ao subir o backend, "Tentar novamente" volta a funcionar. |
| Celular em outra rede (4G, outro Wi-Fi) | Não conecta: o endereço só existe na rede local. |

> **Se um dia precisar de HTTPS** (acesso fora de casa, offline, push): o
> caminho mais simples é o **Tailscale**. Com ele instalado no PC e no
> iPhone, `tailscale serve --bg --https=443 http://localhost:8090` publica a
> mesma porta com HTTPS válido num domínio `*.ts.net`, visível só para os seus
> dispositivos. App e API continuam na mesma origem, sem CORS e sem rebuild
> (o `API_BASE_URL=/api` é relativo).

---

## .ipa via GitHub Actions

> **Por que não é o caminho atual:** o atalho do Safari já dá tela cheia e
> atualização automática, sem custo nem validade. O `.ipa` sem conta paga
> **expira a cada 7 dias**; a conta da Apple custa **US$ 99/ano**. A
> instalação precisa de Sideloadly ou AltServer, que só existem
> oficialmente para Windows e macOS (no Linux, só o AltServer-Linux, não
> oficial). Para compilar localmente, só com um Mac. Fica aqui para o dia em
> que um app nativo fizer sentido.

O workflow [ios.yml](../.github/workflows/ios.yml) compila o app num runner
**macOS** (compilar para iOS exige Xcode) e gera um `.ipa` **sem assinatura**.
A assinatura é feita depois, na hora de instalar, pela ferramenta de sideload.

### Custo

O repositório é **público**, e em repositórios públicos os runners padrão do
GitHub (incluindo o `macos-latest`) são **gratuitos e ilimitados**. Se um dia
ele voltar a ser privado, o plano Free dá 2.000 minutos/mês, mas o macOS conta
**10×** (cerca de 200 minutos reais, ou 13–20 builds). Por isso o workflow
**só roda manualmente ou em tags**.

### 1. Configurar a URL da API (uma vez)

O app nativo não roda no `localhost` do PC, então a URL da API precisa ser
embutida no build. Como o repositório é público e os logs do Actions também,
guarde a URL num **secret**, que é mascarado nos logs:

- GitHub → *Settings* → *Secrets and variables* → *Actions* → aba *Secrets* →
  **New repository secret** → `API_BASE_URL` = `http://<ip-do-pc>:8090/api`
  (ou a URL HTTPS, se um dia houver).
  Ou pelo terminal: `gh secret set API_BASE_URL`.

O campo `api_base_url` ao disparar o workflow também funciona, mas o valor
aparece nos logs públicos.

> O `.ipa` é público (artifacts e releases de repositórios públicos podem ser
> baixados por qualquer pessoa) e contém a URL embutida. Com um IP da rede
> local (ou um domínio do Tailscale), isso não é um problema: a URL só
> responde dentro da sua rede.

> O `Info.plist` libera HTTP **apenas na rede local**
> (`NSAllowsLocalNetworking`), por exemplo `http://192.168.0.193:8090/api`.
> Fora da rede local, use HTTPS.

### 2. Gerar o .ipa

- **Manual**: GitHub → *Actions* → **iOS (.ipa)** → *Run workflow*.
- **Por tag**: `git tag v0.1.0 && git push origin v0.1.0`. O `.ipa` também é
  anexado a uma *Release*.

Ao terminar, baixe o artifact **ishinydex-ipa** na página da execução. Ele vem
num `.zip` com o `ishinydex-unsigned.ipa` dentro.

### 3. Instalar no iPhone (sideload)

**Não precisa de jailbreak.** A ferramenta assina o `.ipa` com o seu Apple ID
e instala via cabo ou Wi-Fi.

| Ferramenta | Sistemas | Observação |
| --- | --- | --- |
| [Sideloadly](https://sideloadly.io) | Windows, macOS | Mais simples: arraste o `.ipa`, informe o Apple ID, conecte o iPhone |
| [AltStore](https://altstore.io) | Windows, macOS (AltServer) | **Renova sozinho** os 7 dias se o AltServer estiver rodando na mesma rede Wi-Fi |
| [AltServer-Linux](https://github.com/NyaMisty/AltServer-Linux) | Linux | Não oficial; funciona, mas dá mais trabalho |

Passos no iPhone, na primeira vez:

1. **Ajustes → Privacidade e Segurança → Modo de Desenvolvedor**: ativar e
   reiniciar (iOS 16+).
2. Depois de instalar: **Ajustes → Geral → VPN e Gerenciamento de
   Dispositivos** → confiar no seu Apple ID.

Limitações do Apple ID **gratuito**:

- o app **expira em 7 dias** (reinstale ou deixe o AltStore renovar);
- no máximo **3 apps** sideloaded ativos ao mesmo tempo;
- no máximo 10 App IDs novos a cada 7 dias.

Com a **conta paga** (Apple Developer Program), a assinatura vale 1 ano.

### Build local num Mac (alternativa)

Com um Mac e Xcode, dá para rodar direto no iPhone conectado:

1. `open ios/Runner.xcworkspace` → *Runner* → *Signing & Capabilities* →
   selecione seu *Team* (Apple ID).
2. `flutter run -d <iphone> --release --dart-define=API_BASE_URL=...`

A mesma regra de 7 dias vale para Apple ID gratuito.

## Ícone do app

O ícone (brilho shiny dourado sobre o índigo do tema, #3F51B5) é gerado por
[`tool/icon/generate_icons.py`](../tool/icon/generate_icons.py), que
sobrescreve todos os arquivos de uma vez:

```bash
pip install pillow          # uma vez
python3 tool/icon/generate_icons.py
```

| Arquivo | Uso | Detalhe |
|---|---|---|
| `web/icons/Icon-192.png` / `Icon-512.png` | Tela de Início do iPhone (`apple-touch-icon`) e PWA | Quadrado cheio: o iOS arredonda os cantos sozinho |
| `web/icons/Icon-maskable-*.png` | Android | Desenho a 80%: o Android recorta o ícone (círculo, gota...) e só a área central é garantida |
| `web/favicon.png` | Aba do navegador (16 px) | Só a estrela grande: as pequenas somem nesse tamanho |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png` | App nativo (.ipa) | Tamanhos lidos do `Contents.json`; sem transparência, a Apple recusa ícone com canal alfa |

O iPhone guarda o ícone quando o atalho é criado: para ver um ícone novo,
remova o atalho da Tela de Início e adicione de novo pelo Safari.
