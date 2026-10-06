# Testes

> **Desatualizado em parte:** desde a v2.0.0 o app não tem servidor (sem
> login, sem API; os dados ficam no aparelho, com sync opcional pelo
> Dropbox). Trechos sobre login, token, API, Docker e nginx descrevem o
> modelo antigo. A revisão está em
> [ishinydex#49](https://github.com/nunesvictor/ishinydex/issues/49).

O projeto exige **100% de cobertura de linhas** em `lib/`, sem contar arquivos
gerados e o `main.dart`. O CI falha se a cobertura cair ou se algum arquivo de
`lib/` não for importado por nenhum teste.

```bash
flutter test                                              # roda tudo
flutter test test/features/personal_dex                   # só uma pasta
flutter test --plain-name "editar espécime pelo formulário" # só um teste pelo nome
flutter test --coverage && dart run tool/check_coverage.dart
```

O [`tool/check_coverage.dart`](../tool/check_coverage.dart) lê
`coverage/lcov.info` e imprime as linhas não cobertas de cada arquivo:

```
Cobertura: 99.84% (1256/1258 linhas)
  lib/features/specimens/presentation/deposit_flow.dart: 142, 143
```

## Os três tipos de teste

| Tipo | Função | Roda em | Exemplo |
| --- | --- | --- | --- |
| **Unitário** | `test(...)` | Dart VM, milissegundos | [app_failure_test.dart](../test/core/network/app_failure_test.dart) |
| **Widget** | `testWidgets(...)` | Ambiente de teste do Flutter, sem navegador | [dex_detail_page_test.dart](../test/features/personal_dex/dex_detail_page_test.dart) |
| **Integração** | `testWidgets` + `IntegrationTestWidgetsFlutterBinding` | Navegador real | [integration_test/app_test.dart](../integration_test/app_test.dart) |

A estrutura de `test/` espelha `lib/`: o teste de
`lib/core/network/app_failure.dart` fica em
`test/core/network/app_failure_test.dart`.

### Testes unitários

Testam uma função ou classe isolada:

```dart
test('prettifyName', () {
  expect(prettifyName('mr-mime-galar'), 'Mr Mime Galar');
});
```

Para providers, crie um `ProviderContainer` com o helper `createContainer`,
que já descarta o container no fim do teste:

```dart
final container = createContainer(overrides: [
  envProvider.overrideWithValue(fakeEnv),
  fakeBackendProvider.overrideWithValue(FakeBackend.seeded()),
]);
final dex = await container.read(dexProvider(1).future);
```

### Testes de widget

Montam widgets num ambiente simulado e interagem como um usuário:

```dart
testWidgets('depositar pelo diálogo', (tester) async {
  await pumpFullApp(tester);                         // app inteiro, dados fake, tela desktop
  await tester.tap(find.text('Shiny Living Dex'));
  await tester.pumpAndSettle();                      // espera animações e Futures
  await tester.tap(find.byKey(const ValueKey('slot-3')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Depositar'));
  await tester.pumpAndSettle();
  expect(find.byType(Dialog), findsOneWidget);
});
```

O essencial da API:

- `tester.pumpWidget(w)`: monta o widget.
- `tester.pump()`: avança um frame. `tester.pumpAndSettle()` avança até não
  haver mais animações pendentes.
- `find.text`, `find.byType`, `find.byKey`, `find.byTooltip`,
  `find.widgetWithText(TextButton, 'Sair')`: localizam widgets.
- `tester.tap`, `tester.enterText`, `tester.fling` (arrastar/swipe),
  `tester.scrollUntilVisible`: interações.
- `expect(finder, findsOneWidget / findsNothing / findsNWidgets(n))`: verificações.

> Em testes de widget, **toda requisição de imagem responde 400**. Por isso o
> `PokemonSprite` sempre cai no ícone de placeholder, e é esperado ver o aviso
> *"At least one test in this suite creates an HttpClient"*.

## Helpers (`test/helpers/`)

| Helper | Uso |
| --- | --- |
| `pumpFullApp(tester, size:, token:, backend:, overrides:)` | App completo (rotas, shell, login) sobre um `FakeBackend`. `token: null` começa deslogado. |
| `pumpWidgetApp(tester, widget, overrides:, size:, platform:)` | Um widget isolado com tema, pt-BR e Riverpod. `platform: TargetPlatform.iOS` testa a variante Cupertino. |
| `compactSize`, `mediumSize`, `expandedSize` | Tamanhos de tela para testar os três layouts |
| `setScreenSize(tester, size)` | Muda o tamanho no meio do teste (ex.: girar/redimensionar) |
| `createContainer(overrides:)` | `ProviderContainer` para testes unitários de providers |
| `MockPersonalDexRepository`, `MockSpecimenRepository` | Mocks do [mocktail](https://pub.dev/packages/mocktail) |
| [test/fixtures/api_fixtures.dart](../test/fixtures/api_fixtures.dart) | JSON **reais** da API, para garantir que o parsing bate com o backend |

## Fakes ou mocks?

- **`FakeBackend`** (preferido): implementação completa em memória, com as
  mesmas regras da API. Use quando quiser testar fluxos
  (depositar → contagem muda).
- **Mocks (mocktail)**: use quando precisar forçar uma situação difícil de
  reproduzir, como um erro de rede na primeira chamada e sucesso na segunda:

```dart
final repository = MockPersonalDexRepository();
var calls = 0;
when(repository.fetchDexes).thenAnswer((_) async {
  if (calls++ == 0) throw const NetworkFailure();
  return const [PersonalDex(id: 1, name: 'Ok', total: 1, registered: 0)];
});
await pumpFullApp(tester, overrides: [
  personalDexRepositoryProvider.overrideWithValue(repository),
]);
```

- **`http_mock_adapter`**: para testar os repositórios HTTP, simula respostas
  do servidor para uma URL/método/corpo específicos. Veja
  [http_personal_dex_repository_test.dart](../test/features/personal_dex/http_personal_dex_repository_test.dart).

## Teste de integração no navegador

Roda o app compilado para web num Chrome real, controlado pelo **chromedriver**.

```bash
# 1. Baixe o chromedriver da MESMA versão major do seu navegador:
#    https://googlechromelabs.github.io/chrome-for-testing/
chromedriver --port=4444 &

# 2. Rode o teste
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart \
  -d web-server --browser-name=chrome --headless
```

> **Usando Brave em vez de Chrome?** O chromedriver procura um executável
> chamado `google-chrome` no `PATH`. Crie um link numa pasta sua e inicie o
> chromedriver com ela no `PATH`:
>
> ```bash
> mkdir -p ~/.local/chromebin
> ln -sf "$(readlink -f "$(which brave-browser)")" ~/.local/chromebin/google-chrome
> PATH=~/.local/chromebin:$PATH chromedriver --port=4444 &
> ```
>
> O Brave 1.96 usa Chromium 154, então use o chromedriver 154.

No CI, o runner do Ubuntu já traz Chrome e chromedriver compatíveis (job
`integration-web` em [ci.yml](../.github/workflows/ci.yml)).

## Checklist ao criar código novo

1. Escreva o teste junto com o código. O gate não deixa passar arquivo sem teste.
2. Teste telas em **compact** e **expanded** se o layout muda.
3. Cubra os estados **loading**, **erro (com retry)**, **vazio** e **dados**.
4. Rode `flutter analyze` e `dart format`. O CI verifica os dois.
