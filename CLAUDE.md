# ishinydex-frontend

Frontend Flutter (web responsiva + iOS) do iShinyDex. Foco: PersonalDex (visualizar/depositar). Sem servidor desde a v2.0.0: os dados ficam no aparelho (modo local), com sync opcional pelo Dropbox; o `ishinydex-backend` só gera o catálogo (dados de referência).
O usuário está aprendendo Flutter: explique decisões e mantenha `docs/` atualizado quando mudar arquitetura.

## Comandos
- `dart run build_runner build` — obrigatório após alterar modelos freezed (arquivos gerados não vão para o git)
- `flutter analyze` e `dart format lib test tool integration_test test_driver` — o CI verifica ambos
- `flutter test --coverage && dart run tool/check_coverage.dart` — gate de 100% de linhas (exclui *.g.dart, *.freezed.dart, main.dart)
- `flutter run -d chrome` — demonstração (dados de exemplo em memória)
- Modo local: `flutter run -d chrome --dart-define=LOCAL_DATA=true --dart-define=CATALOG_URL=<url do catalog.json>` (ex.: o `catalog/catalog.json` publicado no GitHub Pages, que libera CORS); sync com `--dart-define=DROPBOX_APP_KEY=<app key>`
- Publicação: só pelo repositório principal `ishinydex` (tag `v*` → GitHub Pages, `tool/build_pages.sh`)

## Convenções
- Feature-first: `lib/features/<feature>/{domain,data,presentation}` + `<feature>_providers.dart`
- Riverpod 3 com providers escritos à mão (sem riverpod_generator); `ProviderScope(retry: noRetry)`
- As regras de negócio moram em `lib/fake/fake_backend.dart` (o backend local; o nome é do tempo em que imitava a API do servidor). Os dados do usuário são os `records` dele, salvos pelo `LocalStore` (`features/local`) e sincronizados por `features/sync`
- Testes espelham `lib/` em `test/`; telas testadas em `compactSize` e `expandedSize` (helpers em `test/helpers/`)
- Textos da UI em pt-BR
- Código que só roda no navegador fica em `lib/core/web/browser_web.dart` (export condicional em `browser.dart`, fora da cobertura); o resto é testado na VM

## Fluxo
- Toda mudança nasce de uma issue e entra via PR (`Closes #n`); ver `CONTRIBUTING.md`
- Branch `<número>-<resumo>`; nunca commitar/push direto na `main`
- Abrir o PR e parar: o dono revisa e faz squash merge; publicação só depois do merge
