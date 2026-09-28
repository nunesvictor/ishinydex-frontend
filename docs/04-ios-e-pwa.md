# iPhone: PWA e .ipa

Há dois jeitos de ter o app no iPhone:

| | **PWA** (recomendado) | **.ipa nativo (sideload)** |
| --- | --- | --- |
| Como instala | Safari → Compartilhar → "Adicionar à Tela de Início" | Gerado no GitHub Actions e instalado com AltStore/Sideloadly |
| Custo | Zero | Zero (o repositório é público: minutos de macOS ilimitados) |
| Validade | Não expira | **7 dias** com Apple ID gratuito (1 ano com conta paga de US$ 99) |
| Atualização | Automática a cada deploy | Novo build + reinstalar |
| Precisa de | HTTPS acessível pelo iPhone | Um PC com AltServer/Sideloadly na mesma rede |

A web já é requisito do projeto, então o **PWA sai de graça** e é o caminho
principal. O `.ipa` fica como alternativa.

---

## PWA

### 1. Gerar o build web

```bash
flutter build web --release --dart-define=API_BASE_URL=https://SEU-HOST/api
```

O resultado é uma pasta estática em `build/web/`. Qualquer servidor HTTP serve
(nginx, Caddy, o próprio Django, GitHub Pages...).

### 2. Hospedar com HTTPS

O iPhone precisa acessar **a web e a API** por **HTTPS**. O armazenamento
seguro do token (WebCrypto) só funciona em HTTPS ou `localhost`.

Opções, da mais simples para uso pessoal à mais trabalhosa:

1. **Tailscale** (sugerido): instale no PC que roda o backend e no iPhone. O
   `tailscale serve` expõe portas locais com HTTPS válido num domínio
   `*.ts.net`, acessível só pelos seus dispositivos:
   ```bash
   tailscale serve --bg --https=443 http://localhost:8008    # API
   tailscale serve --bg --https=8443 /caminho/para/build/web  # frontend
   ```
   Depois use `--dart-define=API_BASE_URL=https://SEU-PC.SEU-TAILNET.ts.net/api`.
2. **Servir o `build/web` pelo próprio backend** (mesma origem, sem CORS),
   atrás de um proxy com HTTPS.
3. **GitHub Pages / Netlify** para o frontend e o backend exposto com HTTPS
   (mais trabalho e expõe a API na internet).

> Se o frontend e a API estiverem em origens diferentes, adicione a origem do
> frontend em `FRONTEND_ORIGINS` no `.env` do backend (CORS).

### 3. Instalar no iPhone

1. Abra a URL do frontend no **Safari**.
2. Toque em **Compartilhar** → **Adicionar à Tela de Início**.
3. O app abre em tela cheia, com nome e ícone do [manifest](../web/manifest.json).

---

## .ipa via GitHub Actions

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
  **New repository secret** → `API_BASE_URL` = `https://SEU-PC.SEU-TAILNET.ts.net/api`.
  Ou pelo terminal: `gh secret set API_BASE_URL`.

O campo `api_base_url` ao disparar o workflow também funciona, mas o valor
aparece nos logs públicos.

> O `.ipa` é público (artifacts e releases de repositórios públicos podem ser
> baixados por qualquer pessoa) e contém a URL embutida. Com Tailscale isso
> não é um problema: a URL só responde para os seus dispositivos.

> O `Info.plist` libera HTTP **apenas na rede local**
> (`NSAllowsLocalNetworking`), por exemplo `http://192.168.0.10:8008/api`.
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
