# Conceitos de Flutter usados no projeto

> **Desatualizado em parte:** desde a v2.0.0 o app não tem servidor (sem
> login, sem API; os dados ficam no aparelho, com sync opcional pelo
> Dropbox). Trechos sobre login, token, API, Docker e nginx descrevem o
> modelo antigo. A revisão está em
> [ishinydex#49](https://github.com/nunesvictor/ishinydex/issues/49).

Este guia explica, com exemplos do próprio código, os conceitos que você
precisa para ler e modificar o app. Não é um curso completo de Flutter. Para
cada tema há um link para a documentação oficial.

- [1. Tudo é widget](#1-tudo-é-widget)
- [2. Layout: Row, Column, Expanded e amigos](#2-layout-row-column-expanded-e-amigos)
- [3. Responsividade](#3-responsividade)
- [4. Código assíncrono: Future, async e await](#4-código-assíncrono-future-async-e-await)
- [5. Estado com Riverpod](#5-estado-com-riverpod)
- [6. Modelos imutáveis com freezed](#6-modelos-imutáveis-com-freezed)
- [7. Navegação com go_router](#7-navegação-com-go_router)
- [8. HTTP com Dio](#8-http-com-dio)
- [9. Material e Cupertino](#9-material-e-cupertino)
- [10. Dart: recursos modernos que aparecem no código](#10-dart-recursos-modernos-que-aparecem-no-código)

---

## 1. Tudo é widget

Em Flutter, a interface é uma **árvore de widgets**. Um widget é uma descrição
imutável de um pedaço da tela: um texto, um botão, um espaçamento, uma tela
inteira. O método `build` devolve essa descrição, e o Flutter decide o que
redesenhar.

Há dois tipos básicos:

| Tipo | Quando usar | Exemplo no projeto |
| --- | --- | --- |
| `StatelessWidget` | Só depende dos parâmetros recebidos | [`ProgressBadge`](../lib/core/widgets/progress_badge.dart), [`SlotTile`](../lib/features/personal_dex/presentation/widgets/slot_tile.dart) |
| `StatefulWidget` | Guarda estado local que muda com o tempo (seleção, texto digitado) | [`DexDetailPage`](../lib/features/personal_dex/presentation/dex_detail_page.dart) guarda a box e o slot selecionados |

```dart
// lib/core/widgets/progress_badge.dart (simplificado)
class ProgressBadge extends StatelessWidget {
  const ProgressBadge({required this.registered, required this.total, super.key});

  final int registered;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      LinearProgressIndicator(value: registered / total),
      Text('$registered/$total'),
    ]);
  }
}
```

Em um `StatefulWidget`, o estado mora numa classe `State` separada. Para mudar o
estado, chame `setState`, que avisa o Flutter para rodar `build` de novo:

```dart
// lib/features/personal_dex/presentation/dex_detail_page.dart
void _selectBox(int index) => setState(() {
  _boxIndex = index;
  _selectedSlotId = null;
});
```

**`BuildContext`** é a "posição" do widget na árvore. Ele serve para buscar
coisas herdadas de cima, como o tema (`Theme.of(context)`), o tamanho da tela
(`MediaQuery.sizeOf(context)`) e o navegador (`Navigator.of(context)`).

**`const`**: widgets criados com `const` são reaproveitados pelo Flutter sem
reconstrução. O lint do projeto pede `const` sempre que possível.

**`key`**: identifica um widget entre reconstruções. Aqui usamos `ValueKey`
principalmente para os testes encontrarem elementos, por exemplo
`ValueKey('slot-3')` em [`SlotTile`](../lib/features/personal_dex/presentation/widgets/slot_tile.dart).

📚 [Introdução a widgets](https://docs.flutter.dev/ui/widgets-intro)

## 2. Layout: Row, Column, Expanded e amigos

| Widget | O que faz |
| --- | --- |
| `Row` / `Column` | Coloca filhos lado a lado / um embaixo do outro |
| `Expanded` | Faz um filho de `Row`/`Column` ocupar o espaço que sobra |
| `SizedBox` | Tamanho fixo, ou espaçamento vazio (`SizedBox(height: 8)`) |
| `Padding` | Espaço interno |
| `Center` | Centraliza |
| `Stack` + `Positioned` | Sobrepõe widgets (sprite + pokébola no canto do slot) |
| `ListView` / `GridView` | Listas e grades roláveis, que constroem só o que está visível |
| `LayoutBuilder` | Dá acesso ao espaço disponível para decidir o layout |
| `ConstrainedBox` | Limita tamanho (ex.: formulário com largura máxima de 560) |

O grid de uma box ([`BoxGrid`](../lib/features/personal_dex/presentation/widgets/box_grid.dart))
usa `LayoutBuilder` para calcular o tamanho de cada célula, de modo que as 6×5
células caibam no espaço disponível, seja um celular ou um monitor grande:

```dart
LayoutBuilder(builder: (context, constraints) {
  final cell = min(
    (constraints.maxWidth - gaps) / 6,
    (constraints.maxHeight - gaps) / 5,
  );
  // ... Column de 5 Rows com 6 SizedBox.square(dimension: cell)
});
```

📚 [Layouts no Flutter](https://docs.flutter.dev/ui/layout)

## 3. Responsividade

O app usa as três classes de largura do Material 3, definidas em
[`breakpoints.dart`](../lib/core/responsive/breakpoints.dart):

| Classe | Largura | Navegação | Página do dex |
| --- | --- | --- | --- |
| `compact` | < 600 | `NavigationBar` embaixo | Swipe entre boxes (`PageView`); detalhe em *bottom sheet* |
| `medium` | 600–1023 | `NavigationRail` à esquerda | Grade + painel de detalhe |
| `expanded` | 1024–1439 | `NavigationRail` compacto | Grade + detalhe; lista de boxes recolhível (começa oculta) |
| `large` | ≥ 1440 | `NavigationRail` estendido | Lista de boxes + grade + detalhe (lista recolhível, começa aberta) |

A célula da box cresce até 200px (`maxCellSize` em `box_grid.dart`), com
folga interna proporcional. Os selos ✨ e 💢 ficam juntos no canto superior
esquerdo: lado a lado a partir de 64px de célula, empilhados abaixo disso, e
só o ✨ em células menores que 40px.

Os widgets só perguntam `WindowSize.of(context)` e escolhem o layout:

```dart
final size = WindowSize.of(context);
if (size.isCompact) return _buildCompact(boxes, index);
```

Como `WindowSize.of` depende do `MediaQuery`, ao redimensionar a janela o
Flutter reconstrói tudo com o layout novo automaticamente.

**Largura × plataforma.** A largura decide o *layout*; já o *modo de
interação* (teclado físico e mouse × toque) depende da plataforma. Por isso
os selects do formulário usam `isDesktopPlatform(Theme.of(context).platform)`,
também em `breakpoints.dart`: uma janela estreita no desktop continua tendo
teclado. Na web, `Theme.of(context).platform` vem do sistema do navegador,
então o Safari do iPhone conta como iOS. Nos testes, `pumpWidgetApp(...,
platform: TargetPlatform.linux)` simula o desktop.

📚 [Apps adaptativos e responsivos](https://docs.flutter.dev/ui/adaptive-responsive)

## 4. Código assíncrono: Future, async e await

Chamadas de rede demoram, então retornam um **`Future<T>`**, uma promessa de um
valor `T` no futuro. Com `async`/`await` você escreve código assíncrono como se
fosse sequencial:

```dart
// lib/features/personal_dex/data/http_personal_dex_repository.dart
Future<PersonalDex> fetchDex(int dexId) => guardRequest(() async {
  final response = await _dio.get<Map<String, dynamic>>('personal-dexes/$dexId/');
  return PersonalDex.fromJson(response.data!);
});
```

Erros de um `Future` são capturados com `try/catch` quando você usa `await`.
O projeto converte todo erro HTTP numa [`AppFailure`](../lib/core/network/app_failure.dart)
com mensagem em português. É ela que as telas mostram.

📚 [Programação assíncrona em Dart](https://dart.dev/libraries/async/async-await)

## 5. Estado com Riverpod

Estado local (qual slot está selecionado) fica no `State` do widget. Já o
estado **compartilhado ou vindo da API** (lista de dexes, token de login) fica
em **providers** do [Riverpod](https://riverpod.dev).

Pense num provider como uma "variável global inteligente":

- ela é criada sob demanda, na primeira leitura;
- ela é cacheada;
- quem a observa é reconstruído quando ela muda;
- ela pode ser substituída nos testes (*override*).

### 5.1 Tipos de provider usados

| Provider | Para quê | Exemplo |
| --- | --- | --- |
| `Provider<T>` | Um objeto que não muda sozinho (serviços, repositórios) | `personalDexRepositoryProvider` |
| `FutureProvider<T>` | Resultado de uma chamada assíncrona | `dexListProvider` |
| `.family` | Provider com parâmetro (um cache por parâmetro) | `slotsProvider((dexId: 1, boxId: 2))` |
| `.autoDispose` | Descarta o cache quando nenhuma tela usa mais | todas as listagens |
| `AsyncNotifierProvider` | Estado assíncrono com métodos que o alteram | `authControllerProvider` (login/logout) |

```dart
// lib/features/personal_dex/personal_dex_providers.dart
final dexListProvider = FutureProvider.autoDispose<List<PersonalDex>>(
  (ref) => ref.watch(personalDexRepositoryProvider).fetchDexes(),
);
```

### 5.2 Lendo providers na tela

Troque `StatelessWidget` por `ConsumerWidget` (ou `StatefulWidget` por
`ConsumerStatefulWidget`) para ganhar um `ref`:

```dart
// lib/features/personal_dex/presentation/dex_list_page.dart
class DexListPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dexes = ref.watch(dexListProvider);   // AsyncValue<List<PersonalDex>>
    return dexes.when(
      data: (items) => /* grade de cards */,
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(dexListProvider),
      ),
    );
  }
}
```

- **`ref.watch(p)`**: lê e **observa**. Quando `p` mudar, o widget é reconstruído. Use dentro do `build`.
- **`ref.read(p)`**: lê uma vez, sem observar. Use em callbacks (`onPressed`).
- **`ref.invalidate(p)`**: joga o cache fora. Quem observa o provider busca de novo.
- **`AsyncValue`**: o valor de um provider assíncrono. É `AsyncLoading`, `AsyncData` ou `AsyncError`, e `.when(...)` trata os três casos.

### 5.3 Atualizando a tela depois de uma ação

Depois de depositar, várias contagens mudam (slot, box, dex, lista). A classe
[`SlotActions`](../lib/features/personal_dex/personal_dex_providers.dart)
chama a API e em seguida **invalida** os providers afetados. Como as telas os
observam com `watch`, elas se atualizam sozinhas:

```dart
// (simplificado)
Future<Slot> deposit(Slot slot, {required int specimenId}) async {
  final updated = await _repository.deposit(slotId: slot.id, specimenId: specimenId);
  _ref
    ..invalidate(slotsProvider((dexId: dexId, boxId: slot.box.id)))
    ..invalidate(boxesProvider(dexId))
    ..invalidate(dexProvider(dexId))
    ..invalidate(dexListProvider);
  return updated;
}
```

### 5.4 O `ProviderScope`

Todo app Riverpod tem um `ProviderScope` na raiz ([main.dart](../lib/main.dart)),
que guarda os valores dos providers. Nos testes, criamos um `ProviderScope` com
`overrides` para trocar o repositório real por um fake. Veja
[03-testes.md](03-testes.md).

O projeto desliga o *retry* automático do Riverpod 3 (`retry: noRetry`), porque
as telas já oferecem o botão "Tentar novamente".

### 5.5 Lista paginada com uma família de providers

O inventário ([specimens_page.dart](../lib/features/specimens/presentation/specimens_page.dart))
mostra centenas de espécimes, e a API entrega 20 por página. Em vez de um
controlador que junta páginas numa lista, cada página é um provider:

```dart
typedef SpecimenPageKey = ({SpecimenQuery query, int page});

final specimenPageProvider = FutureProvider.autoDispose
    .family<Paginated<Specimen>, SpecimenPageKey>(...);
```

- A lista lê a **página 1** só para saber o total (`count`) e cria um
  `ListView.builder` com esse número de itens.
- O item `i` observa a página `i ~/ 20 + 1`. Como o `ListView.builder` só
  constrói os itens visíveis, **cada página é pedida quando aparece na tela**:
  rolagem infinita sem estado extra.
- Enquanto a página carrega, o item mostra um placeholder. Se ela falha, só o
  primeiro item da página mostra o erro com "Tentar novamente".
- Com `autoDispose`, as páginas que saem da tela são descartadas.
- Para recarregar tudo, `ref.invalidate(specimenPageProvider)` invalida
  **todas** as páginas da família de uma vez.

**A chave precisa ter igualdade por valor.** O parâmetro de `family`
identifica o provider: a mesma consulta precisa cair no **mesmo** provider,
senão cada rebuild pediria a página de novo. `SpecimenPageKey` é um *record*,
e records comparam campo a campo. Mas essa comparação usa o `==` de cada
campo, e o `==` de `List` em Dart é **identidade**: `['a'] == ['a']` é
`false`. Por isso o `SpecimenQuery` começou como record (só tinha texto,
enum e booleanos) e virou uma **classe freezed** quando ganhou listas
(pokébolas, tipos, gerações...): o freezed gera um `==` que compara listas
pelo conteúdo. O teste "igualdade por valor, inclusive das listas" em
`models_test.dart` protege essa regra.

**Debounce.** A busca espera 350 ms sem digitação antes de mudar o filtro
(`Timer` cancelado a cada tecla). Sem isso, digitar "pidgeotto" dispararia
nove requisições.

**Filtros mobile first.** A barra do inventário tem altura fixa no celular:
busca + botão **Filtros** (com `Badge` contando os grupos ativos) numa
linha; filtros rápidos numa linha rolável (`SingleChildScrollView`
horizontal, em vez de `Wrap`, que quebraria em várias linhas); e os filtros
avançados ativos como `InputChip`s removíveis, numa linha que só existe
quando há algum. Os filtros avançados ficam numa folha
([specimen_filters.dart](../lib/features/specimens/presentation/widgets/specimen_filters.dart)):
*bottom sheet* no compacto, `Dialog` nos demais (mesmo padrão do
`showDepositFlow`). Dentro dela, conjuntos pequenos (tipo, geração, gênero)
são chips; conjuntos grandes (39 pokébolas, 25 naturezas, OTs, idiomas) e a
ordem são uma linha compacta que abre um seletor, para a folha não virar um
paredão de chips.

A folha edita um **rascunho** (`_draft`) e só devolve a consulta ao tocar
em "Mostrar resultados": fechar a folha descarta as mudanças, e a lista não
recarrega a cada toque num chip.

A data de captura usa `showDateRangePicker` com
`DatePickerEntryMode.calendarOnly`: a digitação do Material segue o formato
do locale (`dd/mm`), mas o app mostra datas no formato escolhido nos Ajustes
(padrão `mm/dd`, como no HOME). Só com toques não há formato para confundir.

📚 [Documentação do Riverpod](https://riverpod.dev/docs/introduction/getting_started)

## 6. Modelos imutáveis com freezed

Os dados da API viram classes Dart **imutáveis**: você não altera um objeto,
cria uma cópia modificada com `copyWith`. Escrever `==`, `hashCode`,
`copyWith`, `toString` e `fromJson` à mão para cada classe seria muito código
repetitivo, então usamos **geração de código**:

```dart
// lib/features/personal_dex/domain/models.dart
part 'models.freezed.dart';   // gerado pelo freezed
part 'models.g.dart';         // gerado pelo json_serializable

@freezed
abstract class PersonalDex with _$PersonalDex {
  const factory PersonalDex({
    required int id,
    required String name,
    required int total,
    required int registered,
    @Default(false) bool isShinyDex,
  }) = _PersonalDex;

  const PersonalDex._();   // permite adicionar getters próprios

  factory PersonalDex.fromJson(Map<String, dynamic> json) => _$PersonalDexFromJson(json);

  int get missing => total - registered;
}
```

- `@freezed` gera `copyWith`, igualdade por valor e `toString`.
- `fromJson` converte o JSON da API. O [`build.yaml`](../build.yaml) configura
  `field_rename: snake`, então `isShinyDex` no Dart corresponde a `is_shiny_dex`
  no JSON.
- `@Default(false)` define o valor quando o campo não vem no JSON.

**Sempre que alterar um modelo**, rode `dart run build_runner build`, ou
deixe `dart run build_runner watch` rodando. Se aparecer erro como
`_$PersonalDex isn't defined`, é só isso que falta.

📚 [freezed](https://pub.dev/packages/freezed) · [json_serializable](https://pub.dev/packages/json_serializable)

## 7. Navegação com go_router

As rotas são URLs, o que na web significa que o botão voltar do navegador e os
links diretos funcionam. Elas ficam em [`app_router.dart`](../lib/core/router/app_router.dart):

| URL | Tela |
| --- | --- |
| `/splash` | Carregando o token salvo |
| `/login` | [`LoginPage`](../lib/features/auth/presentation/login_page.dart) |
| `/dexes` | [`DexListPage`](../lib/features/personal_dex/presentation/dex_list_page.dart) |
| `/dexes/:dexId?box=&slot=` | [`DexDetailPage`](../lib/features/personal_dex/presentation/dex_detail_page.dart) (`box`/`slot` opcionais: abre naquela box com o slot selecionado) |
| `/specimens` | [`SpecimensPage`](../lib/features/specimens/presentation/specimens_page.dart) (inventário) |
| `/specimens/:specimenId` | [`SpecimenDetailPage`](../lib/features/specimens/presentation/specimen_detail.dart) (detalhe no compacto) |
| `/settings` | [`SettingsPage`](../lib/features/settings/presentation/settings_page.dart) |

Conceitos:

- **`context.go('/dexes/1')`** navega para uma URL.
- **`StatefulShellRoute.indexedStack`** mantém a "casca" com a barra de
  navegação ([`AdaptiveShell`](../lib/core/responsive/adaptive_shell.dart)) e
  preserva o estado de cada aba ao alternar entre elas.
- **`redirect`** é chamado a cada navegação e decide se o usuário pode estar
  ali. A função pura [`authRedirect`](../lib/core/router/app_router.dart)
  implementa as regras: sem token vai para `/login`; com token, sai do
  `/login`.
- O `redirect` pode devolver um `String?` **ou** um `Future<String?>`
  (`FutureOr`). O app só usa o `Future` ao entrar (saindo do login/splash):
  `homeLocation` consulta a API para decidir qual dex abrir. Nas demais
  navegações ele continua síncrono; se fosse sempre `async`, o splash nem
  chegaria a ser desenhado enquanto o token é lido.
- **`ValueKey(dexId)`** na `DexDetailPage`: ao ir de `/dexes/1` para
  `/dexes/2`, a chave diferente faz o Flutter criar um `State` novo (box e
  seleção zeradas) em vez de reaproveitar o do dex anterior.
- **`refreshListenable`** faz o router reavaliar o `redirect` quando o estado
  de login muda. Por isso, ao fazer logout (ou quando a API responde 401), o
  app volta sozinho para o login.

Para diálogos e *bottom sheets* usamos o `Navigator` "clássico"
(`showDialog`, `showModalBottomSheet`, `Navigator.of(context).push/pop`).
Eles são temporários e não precisam de URL.

📚 [go_router](https://pub.dev/documentation/go_router/latest/)

## 8. HTTP com Dio

O [Dio](https://pub.dev/packages/dio) é o cliente HTTP. Ele é configurado uma
vez em [`api_client.dart`](../lib/core/network/api_client.dart) com um
**interceptor**, um código que roda em toda requisição:

- antes de enviar, adiciona `Authorization: Token <token>`;
- se a resposta for **401**, chama `onUnauthorized`, que faz logout.

Os **repositórios** (`HttpPersonalDexRepository`, `HttpSpecimenRepository`)
são as únicas classes que conhecem URLs e JSON. As telas só conhecem a
**interface** (`PersonalDexRepository`). Por isso dá para trocar a API real
pelo [`FakeBackend`](../lib/fake/fake_backend.dart) com uma flag, sem mexer
em nenhuma tela.

## 9. Material e Cupertino

- **Material** é a biblioteca de componentes do Google (usada no app todo).
- **Cupertino** é a biblioteca com visual de iOS.

Para ter a **mesma aparência na web e no iPhone**, a base é Material 3 com o
tema de [`app_theme.dart`](../lib/core/theme/app_theme.dart). Onde a
experiência iOS é claramente melhor, usamos variantes **adaptativas**, que
viram Cupertino no iOS:

| Onde | Adaptativo |
| --- | --- |
| Transição entre telas | `CupertinoPageTransitionsBuilder` no iOS (deslizar da borda para voltar) |
| Diálogos de confirmação | `AlertDialog.adaptive` + `CupertinoDialogAction` ([confirm_dialog.dart](../lib/core/widgets/confirm_dialog.dart)) |
| Switches | `SwitchListTile.adaptive` |
| Carregamento | `CircularProgressIndicator.adaptive` |

### Campos de texto: um padrão só

Todo campo segue um de dois estilos, para o app não misturar campos com e
sem cantos arredondados:

- **Formulários** (cadastro, filtros, diálogos, login, selects): contorno
  com cantos de 12. Ele vem do tema (`inputDecorationTheme` em
  [`app_theme.dart`](../lib/core/theme/app_theme.dart)): o `border` do tema
  vale para todos os `TextField`, `TextFormField` e `DropdownMenu`, e os
  estados de foco e erro herdam o formato, só trocando a cor. Nenhuma tela
  precisa repetir a borda.
- **Buscas**: uma pílula preenchida, o
  [`SearchField`](../lib/core/widgets/search_field.dart), com a lupa e o "x"
  de limpar. A forma diferente avisa que ali é busca, não cadastro.

### Filtros sem rolagem de lado: chips com menu

No inventário e nas caçadas, um grupo de opções (Situação, Motivos) ocupa
**um chip só**, com ▾, que abre um menu: o
[`MenuChip`](../lib/core/widgets/menu_chip.dart), feito sobre o `MenuAnchor`
do Material 3. O `MenuAnchor` desenha o menu numa camada por cima da tela,
ancorado no chip, e o `builder` recebe o `MenuController` usado para abrir e
fechar. Os itens são `RadioMenuButton` (uma opção) ou `CheckboxMenuButton`
(várias; `closeOnActivate: false` deixa o menu aberto para marcar mais de
uma).

Os liga/desliga (shiny e alfa) viram, no celular, chips **só com o
ícone**: o nome fica no `tooltip`, que também é o que o leitor de tela fala.
Com espaço, voltam a ter ícone e texto. A linha usa `Wrap`: se mesmo assim
faltar largura, ela quebra em vez de rolar de lado.

### Selects: `DropdownMenu`

Os campos de escolha do cadastro de specimen usam o
[`ChoiceSelect`](../lib/features/specimens/presentation/widgets/choice_select.dart),
feito sobre o `DropdownMenu` do Material 3, e não sobre o antigo
`DropdownButtonFormField`. O `DropdownMenu` tem um `TextField` por dentro, o
que permite:

- **Digitar para filtrar** (`enableFilter`) e destacar a primeira opção que
  casa (`searchCallback`); Enter escolhe a opção destacada. O
  `filterCallback` usa `foldForSearch` (em `format.dart`) para ignorar
  acentos: "poke" encontra "Poké Ball".
- **Ícones** por item (`DropdownMenuEntry.leadingIcon`) e no campo
  (`leadingIcon`), usados para o sprite das pokébolas, como o select2 do
  admin.

No mobile, `requestFocusOnTap: false` deixa o campo só para toque: o teclado
virtual não abre e não cobre a lista.

### Teclado no iPhone e animações implícitas

**Foco e teclado no Safari do iOS.** O Safari só abre o teclado quando o foco
nasce de um toque do usuário no próprio campo. Um `TextField(autofocus: true)`
dentro de um diálogo recebe o foco um frame depois do toque no botão que abriu
o diálogo; o cursor pisca, mas o teclado não aparece. Por isso a busca do dex
fica **sempre na tela**, numa pílula "Buscar"
([`SlotSearchPill`](../lib/features/personal_dex/presentation/widgets/slot_search.dart))
logo abaixo da grade, que é o próprio campo: o toque é nele, e o teclado abre.
Quando um campo precisa de teclado imediato no iPhone, ele deve estar na tela
antes do toque.

**Animações implícitas.** Widgets `Animated*` (`AnimatedPositioned`,
`AnimatedContainer`, `AnimatedAlign`, `AnimatedOpacity`, `AnimatedSwitcher`)
animam sozinhos quando um valor muda num `setState`: basta passar o valor
novo e a `duration`, sem `AnimationController`. Na busca do dex:

- `AnimatedPositioned` leva a pílula de baixo da grade até o topo, onde ela
  vira a barra de busca. O widget do campo só muda de posição e nunca é
  recriado, então o foco (e o teclado) continuam durante a animação;
- `AnimatedContainer` anima o fundo, a borda e a sombra da pílula junto com a
  altura;
- `AnimatedAlign(heightFactor: 0 ou 1)` dentro de um `ClipRect` recolhe a
  AppBar (por isso ela fica no corpo, e não em `Scaffold.appBar`, que exige
  altura fixa);
- `AnimatedSwitcher` faz o "Cancelar" e o painel de resultados aparecerem e
  sumirem com fade.

### Desenho próprio: `CustomPainter`

O hexágono dos status base
([base_stats_chart.dart](../lib/features/personal_dex/presentation/widgets/base_stats_chart.dart))
não usa biblioteca de gráficos. Um `CustomPaint` recebe um `CustomPainter`,
cujo `paint(canvas, size)` desenha direto no `Canvas`: cada vértice é
calculado com seno e cosseno (ângulos de 60° a partir do topo), os polígonos
saem de um `Path` e os rótulos de um `TextPainter`. O `shouldRepaint` diz ao
Flutter quando redesenhar; aqui é sempre, porque o desenho é barato. Para o
leitor de tela, o desenho fica dentro de um `Semantics` com os valores em
texto. Com um espécime registrado, a natureza dele pinta o stat aumentado de
vermelho (↑) e o diminuído de azul (↓), como nos jogos; os nomes dos stats
vêm das opções de natureza da API (`increased`/`decreased`).

### Imagens do próprio app: assets

Sprites de Pokémon e pokébolas vêm do backend (`Image.network`, dentro do
`PokemonSprite`). Já os ícones das **marcas de origem** vão junto com o app:
são **assets**.

1. Os arquivos ficam numa pasta do projeto (`assets/origin_marks/`).
2. O `pubspec.yaml` declara a pasta em `flutter: assets:`. Só o que está
   declarado entra no bundle (web, iOS...). Uma pasta declarada inclui os
   arquivos dela, mas não as subpastas.
3. Na tela, `Image.asset('assets/origin_marks/paldea.png')` carrega pelo
   caminho.

Shiny, alfa e "veio do GO" também usam imagens do HOME no lugar dos
emojis: `ShinyIcon`, `AlphaIcon` e `GoIcon`
([mark_icons.dart](../lib/core/widgets/mark_icons.dart)). As três estendem
um `MarkIcon` com `Image.asset` e `errorBuilder`: se a imagem não carregar,
aparece o emoji de reserva (✨, 💢, 📱).

As marcas de origem são **glifos brancos** com fundo transparente. O
`OriginMarkIcon` ([origin_mark_chip.dart](../lib/core/widgets/origin_mark_chip.dart))
passa `color` + `colorBlendMode: BlendMode.srcIn`: a imagem vira uma
"máscara", e o Flutter pinta os pixels visíveis com a cor do `IconTheme` (a
mesma dos ícones do chip). Por isso o mesmo PNG funciona no tema claro e no
escuro.

## 10. Dart: recursos modernos que aparecem no código

| Recurso | Exemplo | Significado |
| --- | --- | --- |
| Null safety | `String?`, `slot!.id`, `a ?? b` | `?` pode ser nulo; `!` afirma que não é; `??` dá um valor padrão |
| Records | `({int dexId, int boxId})` | Tupla com nomes; usada como chave do `slotsProvider` |
| Pattern matching | `switch ((a, b, c)) { (AsyncData(), ...) => ... }` | Decide conforme o formato dos valores ([specimen_form_page.dart](../lib/features/specimens/presentation/specimen_form_page.dart)) |
| Collection `if`/`for` | `[if (x) Widget(), for (final d in list) Tile(d)]` | Monta listas de widgets condicionalmente |
| Cascade `..` | `ref..invalidate(a)..invalidate(b)` | Várias chamadas no mesmo objeto |
| `sealed class` | `sealed class AppFailure`, `sealed class FieldEdit<T>` | Hierarquia fechada: o compilador conhece todos os subtipos (ver abaixo) |
| Tear-off | `Provider(SlotActions.new)` | Passa o construtor como função |

**Sealed class na prática: "manter" × "remover".** Na edição em lote, cada
campo pode ficar como está, receber um valor ou ser apagado. Um `String?`
não distingue "não mexer" de "apagar" (os dois seriam `null`). Por isso
existe [`FieldEdit<T>`](../lib/features/specimens/domain/models.dart), com
dois subtipos: `Keep()` e `SetTo(value)`, em que `SetTo(null)` apaga. Como a
classe é `sealed`, um `switch` sem `default` é verificado por completo: se um
dia surgir um terceiro caso, o compilador aponta cada `switch` que precisa
tratá-lo.

```dart
String pokeball(FieldEdit<String> edit) => switch (edit) {
  Keep() => 'Manter',
  SetTo(value: null) => 'Remover',
  SetTo(:final String value) => labelDe(value),
};
```

📚 [Tour da linguagem Dart](https://dart.dev/language)

## 11. Modo local: dados no aparelho

Com `LOCAL_DATA=true`, o app não usa servidor. O `FakeBackend`, que já
seguia todas as regras da API para a demonstração e os testes, vira o
backend de verdade (`FakeBackend.local`), alimentado pelo catálogo.

- **Persistência por comparação.** Cada uso do backend chama `onAccess`,
  que agenda (`SaveScheduler`, 500 ms depois do último uso) uma gravação.
  O `LocalStore` tira um retrato canônico dos registros (`records`: só ids e
  valores, nada derivado) e compara com o último salvo: registro novo ou
  alterado ganha `updatedAt`; registro sumido vira marca em `deleted`.
  Nenhuma regra do app precisa saber que existe persistência, e o sync terá
  a data de cada registro para juntar dois aparelhos.
- **Ids aleatórios de 53 bits.** Dois aparelhos sem rede não podem gerar o
  mesmo id. 53 bits é o maior inteiro exato de um `double`, que é o que um
  `int` vira no navegador. Atenção: lá, os operadores de bits do JavaScript
  trabalham com 32 bits (`1 << 32` dá `0`); por isso o código usa
  constantes.
- **`WidgetsFlutterBinding.ensureInitialized()`** no `main`: plugins como o
  `shared_preferences` falam com a plataforma por canais, que só existem
  depois do binding. Fora do `runApp`, é preciso pedir antes.
