# Deploy local (Docker)

Este guia coloca o app para rodar **permanentemente** na sua máquina, acessível
pelo navegador do PC e de qualquer celular na mesma rede Wi-Fi:

```
http://<ip-do-pc>:8090
```

O padrão é o mesmo do backend: Docker Compose, imagem multi-stage e
`restart: unless-stopped`, para voltar sozinho quando o PC reinicia.

## Como funciona

```
Navegador (PC ou celular)
        │  http://192.168.0.193:8090
        ▼
┌─────────────────────────── container "web" (este repositório) ───┐
│ nginx                                                            │
│   /                         → arquivos do app (build web)        │
│   /api/ /media/ /static/ /admin/ → repassa para o backend  ──────┼──┐
└──────────────────────────────────────────────────────────────────┘  │
                                                                      │ http://host.docker.internal:8080
┌─────────────────────────── container "prod" (ishinydex-backend) ─┐  │
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
- **Mesma origem**: para o navegador, app e API estão no mesmo endereço
  (`http://ip:8090`). Por isso não existe CORS, e o app é compilado com
  `API_BASE_URL=/api`, uma URL relativa ao endereço da página. O mesmo build
  funciona em `localhost`, no IP da rede ou em qualquer domínio futuro.

O nginx repassa o cabeçalho `Host` original, então o Django gera as URLs dos
sprites com o endereço que o navegador usou
(`http://192.168.0.193:8090/media/...`).

## Subindo tudo

### 1. Backend em modo produção

No repositório do backend:

```bash
cd ../ishinydex-backend
docker compose --profile prod up -d --build prod
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/api/personal-dexes/   # 401 = ok
```

O serviço `prod` usa uwsgi com `DEBUG=False` e compartilha o banco com o
ambiente de desenvolvimento. O `web` (porta 8008) pode continuar rodando em
paralelo para você programar.

### 2. Frontend

```bash
cd ../ishinydex-frontend
docker compose up -d --build        # primeira vez: ~5 min (baixa o SDK do Flutter)
```

### 3. Acessar

```bash
hostname -I | awk '{print $1}'      # IP do PC na rede, ex.: 192.168.0.193
```

- No PC: <http://localhost:8090>
- No celular (mesma rede Wi-Fi): `http://192.168.0.193:8090`

Se o celular não abrir, libere a porta no firewall (só se o `ufw` estiver
ativo; confira com `sudo ufw status`):

```bash
sudo ufw allow 8090/tcp
```

> **Dica:** o IP pode mudar quando o roteador reinicia. Para evitar isso,
> reserve um IP fixo para o PC nas configurações de DHCP do roteador.

## Dia a dia

| Tarefa | Comando |
| --- | --- |
| Atualizar depois de mudar o código | `git pull && docker compose up -d --build` |
| Ver logs do nginx | `docker compose logs -f web` |
| Parar | `docker compose down` |
| Status | `docker compose ps` |
| Usar o backend de dev em vez do prod | `BACKEND_URL=http://host.docker.internal:8008 docker compose up -d` |

Configurações ficam num `.env` (copie de [.env.example](../.env.example)):

| Variável | Padrão | Uso |
| --- | --- | --- |
| `X_WEB_PORT` | `8090` | Porta do host |
| `BACKEND_URL` | `http://host.docker.internal:8080` | Backend para onde o nginx repassa a API |

## Login e armazenamento do token

Na web, o token fica no `localStorage` do navegador
([`PrefsTokenStorage`](../lib/features/auth/data/token_storage.dart)). O
armazenamento "seguro" da web depende de WebCrypto, que o navegador só libera
em **HTTPS ou localhost**. Pelo IP da rede, em HTTP, o login falharia. No app
nativo de iOS, o token continua no Keychain.

## Problemas comuns

| Sintoma | Causa provável |
| --- | --- |
| Tela de erro "Erro no servidor" / nginx responde **502** | O backend `prod` está parado. Suba com o comando do passo 1 e veja `docker compose --profile prod logs prod` no backend. |
| Celular não abre a página | Celular em outra rede (ex.: 4G), firewall bloqueando a porta 8090, ou IP mudou. |
| Mudança no código não aparece | Faltou `--build` no `docker compose up`. Depois, recarregue a página. O `index.html` nunca fica em cache. |
| Sprites sem imagem | Veja se `http://<ip>:8090/media/sprites/pokemon/other/home/1.png` abre. Se não abrir, o volume `sprites` do backend não foi populado. |

## Próximos passos (fora do escopo por enquanto)

- **HTTPS + PWA no iPhone** com Tailscale: ver [04-ios-e-pwa.md](04-ios-e-pwa.md).
