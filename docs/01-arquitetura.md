# Arquitetura

## Visão geral

O código é organizado **por feature** (auth, personal_dex, specimens,
settings). Dentro de cada feature, ele se divide em **camadas**:

```
┌──────────────────────────────────────────────────────────────┐
│ presentation/   Telas e widgets (ConsumerWidget)             │
│                 leem providers com ref.watch                 │
├──────────────────────────────────────────────────────────────┤
│ *_providers.dart  Providers Riverpod: cache, estado, ações   │
├──────────────────────────────────────────────────────────────┤
│ domain/         Modelos (freezed) + interfaces de repositório │
│                 (sem Flutter, sem HTTP)                        │
├──────────────────────────────────────────────────────────────┤
│ data/           Implementações HTTP dos repositórios (Dio)    │
│ fake/           Implementação em memória (FakeBackend)        │
└──────────────────────────────────────────────────────────────┘
```

**Regra de dependência:** as camadas de cima conhecem as de baixo, nunca o
contrário. Uma tela nunca chama o Dio diretamente: ela pede dados a um provider,
que usa um **repositório**, que é uma interface. Por isso é possível:

- rodar o app inteiro sem backend (`USE_FAKE_API=true`);
- testar telas sem rede, trocando o repositório por um fake ou mock.

## Mapa das pastas

| Caminho | Responsabilidade |
| --- | --- |
| [lib/main.dart](../lib/main.dart) | Cria o `ProviderScope` e sobe o app |
| [lib/app.dart](../lib/app.dart) | `MaterialApp.router`: tema claro/escuro, idioma pt-BR, rotas |
| [lib/core/config/env.dart](../lib/core/config/env.dart) | Lê `API_BASE_URL` e `USE_FAKE_API` do `--dart-define` |
| [lib/core/network/](../lib/core/network/) | `createDio` + `AuthInterceptor`, `AppFailure` (erros do DRF → mensagens), `Paginated<T>` |
| [lib/core/router/app_router.dart](../lib/core/router/app_router.dart) | Rotas e redirecionamento de login |
| [lib/core/responsive/](../lib/core/responsive/) | `WindowSize` (breakpoints) e `AdaptiveShell` (NavigationBar/Rail) |
| [lib/core/theme/app_theme.dart](../lib/core/theme/app_theme.dart) | Tema Material 3 |
| [lib/core/widgets/](../lib/core/widgets/) | `PokemonSprite` (imagem com fallback), `ProgressBadge`, views de loading/erro/vazio, diálogo de confirmação |
| [lib/features/auth/](../lib/features/auth/) | Login por token, armazenamento seguro do token, `AuthController` |
| [lib/features/personal_dex/](../lib/features/personal_dex/) | Dexes, boxes, slots; depositar/retirar (`SlotActions`) |
| [lib/features/specimens/](../lib/features/specimens/) | Seletor de specimens para depósito e formulário de cadastro |
| [lib/features/settings/](../lib/features/settings/) | Servidor atual e logout |
| [lib/fake/fake_backend.dart](../lib/fake/fake_backend.dart) | Backend em memória que segue as mesmas regras da API real |

## O caminho de um dado: da API até a tela

Exemplo: abrir um dex e ver a primeira box.

```
DexDetailPage.build
  └─ ref.watch(boxesProvider(dexId))                 ← personal_dex_providers.dart
       └─ ref.watch(personalDexRepositoryProvider)   ← escolhe HTTP ou fake pelo Env
            └─ HttpPersonalDexRepository.fetchBoxes  ← data/http_personal_dex_repository.dart
                 └─ dio.get('personal-dexes/1/boxes/')
                      └─ AuthInterceptor adiciona "Authorization: Token ..."
                 └─ BoxSummary.fromJson(...)         ← domain/models.dart (freezed)
  └─ boxes.when(data: ..., loading: ..., error: ...)
       └─ BoxView → ref.watch(slotsProvider((dexId, boxId))) → BoxGrid → SlotTile
```

1. A tela **observa** um provider. Na primeira vez, o provider está carregando
   e a tela mostra `LoadingView`.
2. O provider chama o repositório, que faz a requisição e converte o JSON em
   modelos.
3. Quando o `Future` completa, o provider emite `AsyncData` e a tela é
   reconstruída com os dados.
4. Se der erro, o repositório lança uma `AppFailure`
   ([app_failure.dart](../lib/core/network/app_failure.dart)). O provider
   emite `AsyncError`, a tela mostra `ErrorView` com a mensagem e um botão
   que chama `ref.invalidate(...)`.

## O fluxo de depósito

```
SlotTile (toque) ─► DexDetailPage guarda _selectedSlotId
                    └─ SlotDetailPanel ("Depositar")
                         └─ showDepositFlow()                 ← specimens/presentation/deposit_flow.dart
                              ├─ compacto: bottom sheet / demais: Dialog
                              └─ DepositPicker
                                   ├─ ref.watch(availableSpecimensProvider(formId))
                                   │    → GET /specimens/?form_id=&available=true
                                   ├─ sortForDeposit(): shiny primeiro em dex shiny
                                   ├─ shininess diferente do dex? → confirmação
                                   ├─ "Cadastrar novo" → SpecimenFormPage → POST /specimens/
                                   └─ SlotActions.deposit()   ← personal_dex_providers.dart
                                        → POST /slots/{id}/deposit/
                                        → invalida slots, boxes, dex e lista
                                        → telas atualizam sozinhas
```

Regras de negócio que vêm do backend e que o app trata:

- **Forma diferente** ou **specimen já depositado em outro slot**: a API
  responde 400 com `{"specimen_id": [...]}`. O `DepositPicker` mostra a
  mensagem e recarrega a lista.
- **Slot sem forma**: 400 com `{"non_field_errors": [...]}`. O app nem oferece
  o botão, porque slots livres não são clicáveis.
- **Depositar em slot ocupado** substitui o specimen anterior, que volta a
  ficar disponível. O seletor avisa antes ("será substituído").
- **Token inválido/expirado**: 401 faz o `AuthInterceptor` chamar
  `AuthController.expire()`, e o router leva de volta ao login.

## Autenticação

- [`AuthController`](../lib/features/auth/auth_providers.dart) é um
  `AsyncNotifier<String?>`: o valor é o token, ou `null` se deslogado.
- O token é salvo com `flutter_secure_storage`
  ([token_storage.dart](../lib/features/auth/data/token_storage.dart)). Na
  web, ele usa WebCrypto + localStorage, o que exige HTTPS ou `localhost`.
- O `dioProvider` lê o token do `AuthController` a cada requisição.

## Como adicionar uma feature (receita)

Exemplo: uma tela que lista **todos os specimens**.

1. **Modelo** (se precisar de um novo): em `features/<feature>/domain/models.dart`,
   crie a classe `@freezed` com `fromJson` e rode
   `dart run build_runner build -d`.
2. **Repositório**: adicione o método na interface
   (`specimens/domain/specimen_repository.dart`) e implemente em:
   - `HttpSpecimenRepository` (chamada Dio dentro de `guardRequest`);
   - `FakeBackend` (mesma regra, em memória).

   O compilador acusa as implementações que faltam.
3. **Provider**: em `specimens/specimen_providers.dart`, crie um
   `FutureProvider.autoDispose` que chama o método.
4. **Tela**: crie um `ConsumerWidget` em `presentation/`, use
   `ref.watch(...).when(...)` com `LoadingView`/`ErrorView`/`EmptyView`.
5. **Rota**: registre em `app_router.dart`. Para virar uma aba, adicione um
   `StatefulShellBranch` e um item em `shellDestinations`
   ([adaptive_shell.dart](../lib/core/responsive/adaptive_shell.dart)).
6. **Testes**: teste do repositório HTTP com `http_mock_adapter`, teste do
   `FakeBackend` e teste de widget da tela em tamanho compacto e expandido.
   Rode `flutter test --coverage && dart run tool/check_coverage.dart`.
   Veja [03-testes.md](03-testes.md).

## Decisões e por quês

| Decisão | Motivo |
| --- | --- |
| Modelos freezed servem de domínio e de DTO | App pessoal e pequeno: uma camada de DTO separada só duplicaria código. Se a API divergir do domínio, dá para separar depois. |
| Providers escritos à mão (sem `riverpod_generator`) | Menos código gerado e mais explícito para quem está aprendendo. |
| `Image.network` em vez de pacote de cache | O navegador já faz cache HTTP. `webHtmlElementStrategy.fallback` usa `<img>` se o CORS falhar. |
| Retry automático do Riverpod desligado | Erros de validação não devem ser repetidos; as telas têm "Tentar novamente". |
| Arquivos gerados fora do git | Diffs limpos. O CI e o README mandam rodar o `build_runner`. |
