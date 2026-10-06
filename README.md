# iShinyDex — Frontend

O app do iShinyDex, em Flutter: o **PersonalDex** no mesmo layout de boxes
do Pokémon HOME, o progresso de cada dex e o **depósito** de espécimes nos
slots.

> **Quer usar o app?** Ele roda no navegador e se instala no iPhone, no iPad
> e no PC, sem servidor. O guia está no repositório principal,
> [**ishinydex**](https://github.com/nunesvictor/ishinydex). Aqui fica o
> código do app e o desenvolvimento dele.

- 🌐 **Web responsiva**: desktop (3 painéis), tablet (2 painéis) e celular (swipe entre boxes).
- 💾 **Sem servidor**: os dados ficam no aparelho (modo local); exportar e importar em Ajustes.
- ☁️ **Sync opcional com o Dropbox**: os mesmos dados no PC, no iPhone e no iPad.
- 📴 **Funciona offline** (service worker próprio) e se instala como PWA.
- ✅ **100% de cobertura de testes** (unitários, de widget e de integração no navegador).

## Início rápido

Pré-requisitos: [Flutter](https://docs.flutter.dev/get-started/install) 3.47+ e um
navegador Chromium (Chrome, Brave, Edge).

```bash
flutter pub get
dart run build_runner build  # gera os arquivos *.g.dart e *.freezed.dart

# Demonstração (dados de exemplo em memória, somem ao recarregar):
flutter run -d chrome

# Modo local (dados no navegador), com o catálogo publicado:
flutter run -d chrome --dart-define=LOCAL_DATA=true \
  --dart-define=CATALOG_URL=https://<usuário>.github.io/ishinydex/catalog/catalog.json
```

> **Por que o `build_runner`?** Os modelos usam geração de código (`freezed` e
> `json_serializable`). Os arquivos gerados não vão para o git; você precisa
> rodar o comando depois de clonar e sempre que alterar um modelo. Veja
> [docs/02-conceitos-flutter.md](docs/02-conceitos-flutter.md#6-modelos-imutáveis-com-freezed).

## Comandos do dia a dia

| O que | Comando |
| --- | --- |
| Rodar no navegador | `flutter run -d chrome` |
| Gerar código (uma vez) | `dart run build_runner build` |
| Gerar código (observando mudanças) | `dart run build_runner watch` |
| Analisar (lints) | `flutter analyze` |
| Formatar | `dart format lib test tool integration_test test_driver` |
| Testes | `flutter test` |
| Testes + cobertura | `flutter test --coverage && dart run tool/check_coverage.dart` |
| Teste de integração (web) | veja [docs/03-testes.md](docs/03-testes.md#teste-de-integração-no-navegador) |
| Publicar | pelo repositório principal: tag `v*` → GitHub Pages |

### Configuração (`--dart-define`)

| Variável | Padrão | Uso |
| --- | --- | --- |
| `LOCAL_DATA` | `false` | Modo local: os dados ficam no aparelho (`shared_preferences`). Exige `CATALOG_URL`. Sem ele, a demonstração. |
| `CATALOG_URL` | (vazio) | O `catalog.json` (gerado pelo [ishinydex-backend](https://github.com/nunesvictor/ishinydex-backend)): formas, opções e versões. Relativo à página. Na demonstração é opcional (sem ele, um seed fixo). |
| `DROPBOX_APP_KEY` | (vazio) | App key do seu app do Dropbox: liga a sincronização no modo local. Sem ela, o build sai sem sync. |
| `SPRITES_BASE_URL` | raw do PokeAPI/sprites | Base dos caminhos de sprite do catálogo |
| `APP_VERSION` | `dev` | Versão mostrada em Ajustes → Sobre (a tag, no build) |

## Documentação

Leia nesta ordem se você está começando com Flutter:

1. [**Conceitos de Flutter usados no projeto**](docs/02-conceitos-flutter.md): widgets, estado, Riverpod, rotas, freezed, com exemplos tirados do código.
2. [**Arquitetura**](docs/01-arquitetura.md): como as pastas se organizam e como adicionar uma feature.
3. [**Testes**](docs/03-testes.md): tipos de teste, helpers, mocks e o gate de 100% de cobertura.
4. [**iPhone e iPad**](docs/04-ios-e-pwa.md): instalar como app da Tela de Início e o `.ipa`.

> Os guias ainda descrevem partes do modo servidor (login, API), que saiu na
> v2.0.0. A revisão está em
> [ishinydex#49](https://github.com/nunesvictor/ishinydex/issues/49).

## Estrutura resumida

```
lib/
  main.dart           # ponto de entrada: carrega o catálogo e os dados do aparelho
  app.dart            # MaterialApp: tema, idioma, rotas
  core/               # peças compartilhadas (tema, rotas, responsividade, widgets, navegador)
  features/
    catalog/          # catálogo (dados de referência) e a carga dele
    local/            # dados no aparelho: arquivo, exportar/importar, mescla
    sync/             # sincronização com o Dropbox
    personal_dex/     # dexes, boxes, slots (visualizar/depositar/editar/libertar)
    specimens/        # escolher e cadastrar espécimes
    shiny_locks/      # formas sem shiny
    settings/         # ajustes e "Sobre"
  fake/               # o backend local: as regras de negócio, em memória
test/                 # espelha lib/
integration_test/     # fluxo completo no navegador
tool/                 # scripts (verificação de cobertura)
web/                  # index.html, service worker, bootstrap versionado
.github/workflows/    # CI (testes, build web) e iOS (.ipa)
```
