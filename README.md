# iShinyDex — Frontend

App Flutter para controlar o **PersonalDex** do [`ishinydex-backend`](../ishinydex-backend):
ver as boxes (no mesmo layout do Pokémon HOME), acompanhar o progresso e
**depositar** specimens nos slots.

- 🌐 **Web responsiva**: desktop (3 painéis), tablet (2 painéis) e celular (swipe entre boxes).
- 🐳 **Deploy local em Docker**: nginx servindo o app e repassando a API; acesso por `http://<ip-do-pc>:8090` no PC e no celular.
- 📱 **iPhone**: pelo navegador; no futuro como **PWA** (HTTPS) ou app nativo via `.ipa` gerado no GitHub Actions.
- ✅ **100% de cobertura de testes** (unitários, de widget e de integração no navegador).

## Início rápido

Pré-requisitos: [Flutter](https://docs.flutter.dev/get-started/install) 3.47+ e um
navegador Chromium (Chrome, Brave, Edge).

```bash
flutter pub get
dart run build_runner build -d       # gera os arquivos *.g.dart e *.freezed.dart

# Sem backend (dados de demonstração em memória, qualquer usuário/senha entra):
flutter run -d chrome --dart-define=USE_FAKE_API=true

# Com o backend rodando (docker compose up no ishinydex-backend):
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
| Gerar código (uma vez) | `dart run build_runner build -d` |
| Gerar código (observando mudanças) | `dart run build_runner watch -d` |
| Analisar (lints) | `flutter analyze` |
| Formatar | `dart format lib test tool integration_test test_driver` |
| Testes | `flutter test` |
| Testes + cobertura | `flutter test --coverage && dart run tool/check_coverage.dart` |
| Teste de integração (web) | veja [docs/03-testes.md](docs/03-testes.md#teste-de-integração-no-navegador) |
| Build web | `flutter build web --dart-define=API_BASE_URL=https://.../api` |
| Deploy local (Docker) | `docker compose up -d --build` → `http://<ip-do-pc>:8090` (veja [docs/06-deploy-local.md](docs/06-deploy-local.md)) |

### Configuração (`--dart-define`)

| Variável | Padrão | Uso |
| --- | --- | --- |
| `API_BASE_URL` | `http://localhost:8008/api` | Endereço da API do backend. Aceita URL relativa (`/api`), resolvida contra o endereço da página. |
| `USE_FAKE_API` | `false` | `true` usa o backend fake em memória ([lib/fake/fake_backend.dart](lib/fake/fake_backend.dart)) |

## Documentação

Leia nesta ordem se você está começando com Flutter:

1. [**Conceitos de Flutter usados no projeto**](docs/02-conceitos-flutter.md): widgets, estado, Riverpod, rotas, freezed, com exemplos tirados do código.
2. [**Arquitetura**](docs/01-arquitetura.md): como as pastas se organizam, o caminho de um dado da API até a tela e como adicionar uma feature.
3. [**Testes**](docs/03-testes.md): tipos de teste, helpers, mocks e o gate de 100% de cobertura.
4. [**iPhone: PWA e .ipa**](docs/04-ios-e-pwa.md): como instalar no iPhone e como o CI gera o `.ipa`.
5. [**API**](docs/05-api.md): endpoints consumidos e como integrar um novo.
6. [**Deploy local**](docs/06-deploy-local.md): Docker + nginx, acesso pela rede, dia a dia e problemas comuns.

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
deploy/nginx/         # configuração do nginx do deploy local
Dockerfile            # build multi-stage (Flutter → nginx)
docker-compose.yml    # deploy local
.github/workflows/    # CI (testes) e iOS (.ipa)
```
