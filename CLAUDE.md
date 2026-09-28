# ishinydex-frontend

Frontend Flutter (web responsiva + iOS) do `../ishinydex-backend`. Foco: PersonalDex (visualizar/depositar).
O usuário está aprendendo Flutter: explique decisões e mantenha `docs/` atualizado quando mudar arquitetura.

## Comandos
- `dart run build_runner build -d` — obrigatório após alterar modelos freezed (arquivos gerados não vão para o git)
- `flutter analyze` e `dart format lib test tool integration_test test_driver` — o CI verifica ambos
- `flutter test --coverage && dart run tool/check_coverage.dart` — gate de 100% de linhas (exclui *.g.dart, *.freezed.dart, main.dart)
- `flutter run -d chrome --dart-define=USE_FAKE_API=true` — demo sem backend
- Backend local: `http://localhost:8008/api` (contrato em `../ishinydex-backend/docs/plans/frontend-api.md`)

## Convenções
- Feature-first: `lib/features/<feature>/{domain,data,presentation}` + `<feature>_providers.dart`
- Riverpod 3 com providers escritos à mão (sem riverpod_generator); `ProviderScope(retry: noRetry)`
- Toda regra da API deve existir também em `lib/fake/fake_backend.dart`
- Testes espelham `lib/` em `test/`; telas testadas em `compactSize` e `expandedSize` (helpers em `test/helpers/`)
- Textos da UI em pt-BR
