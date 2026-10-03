# iShinyDex — Frontend

App Flutter para controlar o **PersonalDex** do [`ishinydex-backend`](../ishinydex-backend):
ver as boxes (no mesmo layout do Pokémon HOME), acompanhar o progresso e
**depositar** specimens nos slots.

- 🌐 **Web responsiva**: desktop (3 painéis), tablet (2 painéis) e celular (swipe entre boxes).
- 🐳 **Imagem Docker**: nginx servindo o app e repassando a API, usada pelo repositório principal; acesso por `http://<ip-do-pc>:8090` no PC e no celular.
- 📱 **iPhone**: atalho do Safari na Tela de Início (abre em tela cheia, por HTTP na rede local); app nativo via `.ipa` gerado no GitHub Actions como alternativa.
- ✅ **100% de cobertura de testes** (unitários, de widget e de integração no navegador).

> **Este repositório não é para deploy.** Para instalar e rodar o iShinyDex
> (backend + frontend), clone o repositório principal
> [**ishinydex**](https://github.com/nunesvictor/ishinydex), que traz este
> código como submodule e sobe tudo com um comando:
>
> ```bash
> git clone --recurse-submodules https://github.com/nunesvictor/ishinydex.git
> cd ishinydex && cp .env.example .env   # troque os change-me
> docker compose up -d --build           # app em http://<ip-do-pc>:8090
> ```
>
> O `Dockerfile` e o `deploy/nginx/` daqui são usados por esse compose. Aqui
> fica o código do frontend e o desenvolvimento dele (`flutter run`).

## Início rápido

Pré-requisitos: [Flutter](https://docs.flutter.dev/get-started/install) 3.47+ e um
navegador Chromium (Chrome, Brave, Edge).

```bash
flutter pub get
dart run build_runner build  # gera os arquivos *.g.dart e *.freezed.dart

# Sem backend (dados de demonstração em memória, qualquer usuário/senha entra):
flutter run -d chrome --dart-define=USE_FAKE_API=true

# Com o backend de desenvolvimento rodando (docker compose up no ishinydex-backend, :8008):
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8008/api
```

> **Por que o `build_runner`?** Os modelos usam geração de código (`freezed` e
> `json_serializable`). Os arquivos gerados não vão para o git; você precisa
> rodar o comando depois de clonar e sempre que alterar um modelo. Veja
> [docs/02-conceitos-flutter.md](docs/02-conceitos-flutter.md#6-modelos-imutáveis-com-freezed).

## Comandos do dia a dia

| O que | Comando |
| --- | --- |
| Rodar no navegador | `flutter run -d chrome --dart-define=USE_FAKE_API=true` |
| Gerar código (uma vez) | `dart run build_runner build` |
| Gerar código (observando mudanças) | `dart run build_runner watch` |
| Analisar (lints) | `flutter analyze` |
| Formatar | `dart format lib test tool integration_test test_driver` |
| Testes | `flutter test` |
| Testes + cobertura | `flutter test --coverage && dart run tool/check_coverage.dart` |
| Teste de integração (web) | veja [docs/03-testes.md](docs/03-testes.md#teste-de-integração-no-navegador) |
| Build web | `flutter build web --dart-define=API_BASE_URL=https://.../api` |
| Imagem Docker / deploy | pelo repositório principal (veja [docs/06-deploy-local.md](docs/06-deploy-local.md)) |

### Configuração (`--dart-define`)

| Variável | Padrão | Uso |
| --- | --- | --- |
| `API_BASE_URL` | `http://localhost:8008/api` | Endereço da API do backend. Aceita URL relativa (`/api`), resolvida contra o endereço da página. |
| `USE_FAKE_API` | `false` | `true` usa o backend fake em memória ([lib/fake/fake_backend.dart](lib/fake/fake_backend.dart)) |
| `CATALOG_URL` | (vazio) | Com `USE_FAKE_API`, o `catalog.json` (pacote do backend) que a demonstração passa a usar: formas, opções e versões reais. Relativo à página, como a API. |
| `SPRITES_BASE_URL` | raw do PokeAPI/sprites | Base dos caminhos de sprite do catálogo |
| `APP_VERSION` | `dev` | Versão mostrada em Ajustes → Sobre (a tag, no build) |

## Documentação

Leia nesta ordem se você está começando com Flutter:

1. [**Conceitos de Flutter usados no projeto**](docs/02-conceitos-flutter.md): widgets, estado, Riverpod, rotas, freezed, com exemplos tirados do código.
2. [**Arquitetura**](docs/01-arquitetura.md): como as pastas se organizam, o caminho de um dado da API até a tela e como adicionar uma feature.
3. [**Testes**](docs/03-testes.md): tipos de teste, helpers, mocks e o gate de 100% de cobertura.
4. [**iPhone: atalho do Safari e .ipa**](docs/04-ios-e-pwa.md): como instalar no iPhone, o que funciona sem HTTPS e como o CI gera o `.ipa`.
5. [**API**](docs/05-api.md): endpoints consumidos e como integrar um novo.
6. [**Imagem Docker e deploy**](docs/06-deploy-local.md): como a imagem funciona (build, nginx, cache), acesso pela rede e problemas comuns.

## Estrutura resumida

```
lib/
  main.dart           # ponto de entrada
  app.dart            # MaterialApp: tema, idioma, rotas
  core/               # peças compartilhadas (rede, tema, rotas, responsividade, widgets)
  features/
    auth/             # login por token
    personal_dex/     # dexes, boxes, slots (visualizar/depositar/editar/libertar)
    specimens/        # escolher e cadastrar specimens
    settings/         # ajustes e logout
  fake/               # backend em memória (testes e demo)
test/                 # espelha lib/
integration_test/     # fluxo completo no navegador
tool/                 # scripts (verificação de cobertura)
deploy/nginx/         # configuração do nginx da imagem
Dockerfile            # build multi-stage (Flutter → nginx), usado pelo repositório principal
.github/workflows/    # CI (testes) e iOS (.ipa)
```
