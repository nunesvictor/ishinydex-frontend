import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/widgets/game_icon.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/moves/domain/moves_data.dart';
import 'package:ishinydex/features/moves/moves_providers.dart';
import 'package:ishinydex/features/moves/presentation/move_page.dart';
import 'package:ishinydex/features/moves/presentation/move_search_page.dart';
import 'package:ishinydex/features/moves/presentation/moves_tab.dart';
import 'package:ishinydex/features/moves/presentation/moves_widgets.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/form_sheet.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/form_picker.dart';

import '../../fixtures/catalog_fixture.dart';
import '../../fixtures/moves_fixture.dart';
import '../../helpers/helpers.dart';

final Catalog _catalog = Catalog.fromJson({
  ...catalogJson(),
  'movesFile': 'moves-2026.10.03.json',
}, spriteBase: 'https://sprites/');

final MovesData _data = MovesData.fromJson(movesJson());

class _Ready extends MovesNotifier {
  @override
  MovesState build() => MovesReady(_data);
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = compactSize,
  Locale locale = portuguese,
}) => pumpWidgetApp(
  tester,
  child,
  size: size,
  locale: locale,
  overrides: [
    fakeBackendProvider.overrideWithValue(FakeBackend.fromCatalog(_catalog)),
    movesProvider.overrideWith(_Ready.new),
  ],
);

/// Um botão que abre a busca, como o menu do PersonalDex.
Widget _opener({String? group, int? formId, String query = ''}) => Scaffold(
  body: Builder(
    builder: (context) => TextButton(
      onPressed: () =>
          openMoveSearch(context, group: group, formId: formId, query: query),
      child: const Text('Abrir'),
    ),
  ),
);

/// Abre o menu do [chip], marca ou desmarca cada opção e fecha o menu.
Future<void> _check(
  WidgetTester tester,
  String chip,
  List<String> options,
) async {
  await tester.tap(find.byKey(ValueKey(chip)));
  await tester.pumpAndSettle();
  for (final option in options) {
    await tester.tap(find.widgetWithText(CheckboxMenuButton, option));
    await tester.pumpAndSettle();
  }
  // Tocar no chip de novo fecha o menu.
  await tester.tap(find.byKey(ValueKey(chip)));
  await tester.pumpAndSettle();
}

/// "Adicionar forma…" no menu de quem aprende, buscando por [name].
Future<void> _addForm(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const ValueKey('filter-learner')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('learner-add')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, name);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
}

void main() {
  group('MovesData: quem aprende', () {
    test('os golpes do jogo e quem aprende cada um', () {
      expect(
        [for (final m in _data.movesIn('scarlet-violet')) m.name],
        ['leech-seed', 'petal-dance', 'seed-bomb', 'tackle', 'vine-whip'],
      );
      final vine = _data.moves[4];
      final learners = _data.learnersOf(vine, 'scarlet-violet');
      expect(learners.keys, {1, 3});
      expect(learners[3]!.single.method, 'machine');
      expect(_data.learnersOf(vine, 'x-y'), isEmpty);
    });

    test('como aprende, em poucas palavras', () {
      final tackle = _data.learnersOf(_data.moves[3], 'scarlet-violet')[1]!;
      expect(learnHow(ptText, tackle, 'generation-ix'), 'Nv. 1 · TM001');
      final petal = _data.learnersOf(_data.moves[1], 'scarlet-violet')[1]!;
      expect(learnHow(ptText, petal, 'generation-ix'), 'Por tutor · Treino');
      final leech = _data.learnersOf(_data.moves[0], 'scarlet-violet')[1]!;
      expect(learnHow(enText, leech, 'generation-ix'), 'Lv. 1 · Egg');
      final vine = _data.learnersOf(_data.moves[4], 'scarlet-violet')[3]!;
      expect(learnHow(ptText, vine, 'generation-ix'), 'TM');
    });

    test('o Pokémon de cada forma, para a lista de quem aprende', () {
      expect(_catalog.formOfPokemon(1)?.name, 'bulbasaur');
      expect(_catalog.formOfPokemon(999), isNull);
    });

    test('o alvo, pelo nome da PokéAPI', () {
      for (final (target, text) in [
        ('selected-pokemon', 'Um Pokémon escolhido'),
        ('all-opponents', 'Todos os oponentes'),
        ('user', 'O próprio Pokémon'),
        ('ally', 'Um aliado'),
        ('users-field', 'O lado de quem usa'),
        ('user-or-ally', 'O próprio ou um aliado'),
        ('opponents-field', 'O lado dos oponentes'),
        ('random-opponent', 'Um oponente ao acaso'),
        ('all-other-pokemon', 'Todos os outros Pokémon'),
        ('selected-pokemon-me-first', 'Um Pokémon escolhido (Me First)'),
        ('all-allies', 'Todos os aliados'),
        ('entire-field', 'O campo inteiro'),
        ('user-and-allies', 'O próprio e os aliados'),
        ('all-pokemon', 'Todos os Pokémon'),
        ('specific-move', 'Depende do golpe'),
        ('fainting-pokemon', 'Um aliado desmaiado'),
        ('new-target', 'New Target'),
      ]) {
        expect(moveTargetLabel(ptText, target), text);
      }
    });
  });

  group('a busca', () {
    for (final size in [compactSize, expandedSize]) {
      testWidgets('vazia: o jogo mais recente e todos os golpes dele '
          '(${size.width.toInt()}px)', (tester) async {
        await _pump(tester, _opener(), size: size);
        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();

        expect(find.text('Buscar golpes'), findsOneWidget);
        // O jogo pelos ícones das versões, com o nome no tooltip.
        expect(find.byTooltip('Jogo: Scarlet / Violet'), findsOneWidget);
        expect(
          [
            for (final icon in tester.widgetList<GameIcon>(
              find.byType(GameIcon),
            ))
              icon.version,
          ],
          ['scarlet', 'violet'],
        );
        // Sem nada marcado, cada chip com o nome.
        for (final name in ['Tipo', 'Categoria', 'Alvo', 'Quem aprende']) {
          expect(find.text(name), findsOneWidget);
        }
        expect(find.text('5 golpes'), findsOneWidget);
        expect(find.text('Tackle'), findsOneWidget);
      });
    }

    testWidgets('pela aba Golpes: o jogo, a forma e o texto', (tester) async {
      await _pump(tester, _opener(group: 'x-y', formId: 1, query: 'tack'));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Jogo: X / Y'), findsOneWidget);
      expect(find.text('1 golpe · Bulbasaur aprende'), findsOneWidget);
      expect(find.byTooltip('Quem aprende: Bulbasaur'), findsOneWidget);
      // Com uma forma, como ela aprende, ao lado do tipo.
      expect(find.text('Nv. 1'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);

      // Desmarcar a forma no menu: todos os do jogo com o texto.
      await tester.tap(find.byKey(const ValueKey('filter-learner')));
      await tester.pumpAndSettle();
      expect(find.text('Golpes que todas aprendem'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('learner-form-1')).first);
      await tester.pumpAndSettle();
      expect(find.text('1 golpe'), findsOneWidget);
      expect(find.text('Nv. 1'), findsNothing);

      // Limpar o texto.
      await tester.tap(find.byTooltip('Limpar'));
      await tester.pumpAndSettle();
      expect(find.text('2 golpes'), findsOneWidget);
    });

    testWidgets('uma forma fora do catálogo não filtra', (tester) async {
      await _pump(tester, _opener(formId: 9999));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.text('5 golpes'), findsOneWidget);
    });

    testWidgets('tipo, categoria e alvo: vários valores, com OU', (
      tester,
    ) async {
      await _pump(tester, _opener());
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      // O menu fica aberto enquanto se marca.
      await _check(tester, 'filter-type', ['Grass', 'Normal']);
      expect(find.text('5 golpes'), findsOneWidget);
      expect(find.byTooltip('Tipo: Grass ou Normal'), findsOneWidget);
      await _check(tester, 'filter-type', ['Normal']);
      expect(find.text('4 golpes'), findsOneWidget);
      expect(find.byTooltip('Tipo: Grass'), findsOneWidget);
      // Com algo marcado, a face mostra os ícones, não o nome.
      expect(find.text('Tipo'), findsNothing);

      await _check(tester, 'filter-category', ['Físico', 'Especial']);
      expect(find.text('3 golpes'), findsOneWidget);
      expect(find.byTooltip('Categoria: Físico ou Especial'), findsOneWidget);

      // Os alvos, sem ícone: o nome do primeiro e "+N".
      await _check(tester, 'filter-target', ['Um Pokémon escolhido']);
      expect(find.text('1 golpe'), findsOneWidget);
      expect(find.text('Seed Bomb'), findsOneWidget);
      await _check(tester, 'filter-target', ['Um oponente ao acaso']);
      expect(find.text('2 golpes'), findsOneWidget);
      expect(find.text('Um Pokémon escolhido +1'), findsOneWidget);
      expect(
        find.byTooltip('Alvo: Um Pokémon escolhido ou Um oponente ao acaso'),
        findsOneWidget,
      );

      // Desmarcar tudo volta ao começo.
      await _check(tester, 'filter-type', ['Grass']);
      await _check(tester, 'filter-category', ['Físico', 'Especial']);
      await _check(tester, 'filter-target', [
        'Um Pokémon escolhido',
        'Um oponente ao acaso',
      ]);
      expect(find.text('5 golpes'), findsOneWidget);
      expect(find.text('Alvo'), findsOneWidget);

      // Sem resultado.
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('Nenhum golpe com “zzz”'), findsOneWidget);
    });

    testWidgets('o jogo: um só, e o nome quando não tem ícone', (tester) async {
      await _pump(tester, _opener());
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('filter-game')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('X / Y'));
      await tester.pumpAndSettle();
      expect(find.text('2 golpes'), findsOneWidget);
      expect(find.byTooltip('Jogo: X / Y'), findsOneWidget);

      // Fechar a lista sem escolher mantém.
      await tester.tap(find.byKey(const ValueKey('filter-game')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Jogo: X / Y'), findsOneWidget);

      // Um grupo fora do catálogo, sem as versões: o nome.
      await tester.tap(find.byKey(const ValueKey('filter-game')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Champions'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('filter-game')),
          matching: find.text('Champions'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('quem aprende: várias formas, com E', (tester) async {
      await _pump(tester, _opener());
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await _addForm(tester, 'venusaur');
      expect(find.text('1 golpe · Venusaur aprende'), findsOneWidget);
      expect(find.text('TM'), findsOneWidget);

      // A segunda: só o que as duas aprendem, com o modo de cada uma.
      await _addForm(tester, 'bulbasaur');
      expect(
        find.text('1 golpe · Venusaur e Bulbasaur aprendem'),
        findsOneWidget,
      );
      expect(find.text('Vine Whip'), findsOneWidget);
      expect(find.text('TM'), findsOneWidget);
      expect(find.text('Nv. 3'), findsOneWidget);

      // A mesma forma de novo não muda nada; fechar o seletor também não.
      await _addForm(tester, 'bulbasaur');
      expect(
        find.text('1 golpe · Venusaur e Bulbasaur aprendem'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('filter-learner')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('learner-add')));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(FormPicker))).pop();
      await tester.pumpAndSettle();
      expect(
        find.text('1 golpe · Venusaur e Bulbasaur aprendem'),
        findsOneWidget,
      );

      // Desmarcar o Venusaur: o que o Bulbasaur aprende.
      await tester.tap(find.byKey(const ValueKey('filter-learner')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('learner-form-3')).first);
      await tester.pumpAndSettle();
      expect(find.text('5 golpes · Bulbasaur aprende'), findsOneWidget);
    });

    testWidgets('forma sem golpes no jogo: nenhum resultado', (tester) async {
      await _pump(tester, _opener(group: 'x-y', formId: 150));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.text('0 golpes · Mewtwo aprende'), findsOneWidget);
    });

    testWidgets('em inglês', (tester) async {
      await _pump(tester, _opener(), locale: english);
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Search moves'), findsOneWidget);
      expect(find.text('Who learns'), findsOneWidget);
      expect(find.text('5 moves'), findsOneWidget);
      await _addForm(tester, 'venusaur');
      await _addForm(tester, 'bulbasaur');
      expect(
        find.text('1 move · learned by Venusaur and Bulbasaur'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('filter-learner')));
      await tester.pumpAndSettle();
      expect(find.text('Moves all of them learn'), findsOneWidget);
      expect(find.text('Add form…'), findsOneWidget);
    });
  });

  group('o golpe', () {
    for (final size in [compactSize, expandedSize]) {
      testWidgets('dados do jogo, alvo, efeito e quem aprende '
          '(${size.width.toInt()}px)', (tester) async {
        await _pump(tester, _opener(), size: size);
        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tackle'));
        await tester.pumpAndSettle();

        expect(find.byType(MovePage), findsOneWidget);
        expect(find.text('Físico'), findsOneWidget);
        expect(find.text('Poder'), findsOneWidget);
        expect(find.text('40'), findsOneWidget);
        expect(find.text('Um Pokémon escolhido'), findsOneWidget);
        expect(find.text('Hits.'), findsOneWidget);
        expect(
          find.text('Quem aprende em Scarlet / Violet · 1'),
          findsOneWidget,
        );
        expect(find.text('Nv. 1 · TM001'), findsOneWidget);

        // Tocar na forma abre a ficha.
        await tester.tap(find.byKey(const ValueKey('learner-1')));
        await tester.pumpAndSettle();
        expect(find.byType(FormSheet), findsOneWidget);
      });
    }

    testWidgets('sem poder nem efeito: o traço e sem efeito', (tester) async {
      await _pump(
        tester,
        MovePage(move: _data.moves[1], group: 'scarlet-violet'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Especial'), findsOneWidget);
      expect(find.text('Efeito'), findsNothing);
      await _pump(tester, MovePage(move: _data.moves[0], group: 'x-y'));
      await tester.pumpAndSettle();
      expect(find.text('—'), findsOneWidget);
      expect(find.text('Quem aprende em X / Y · 0'), findsOneWidget);
      // Sem alvo: sem a linha.
      await _pump(tester, MovePage(move: _data.moves[4], group: 'x-y'));
      await tester.pumpAndSettle();
      expect(find.text('Alvo'), findsNothing);
    });
  });

  group('a aba Golpes', () {
    testWidgets('"Filtros" abre a busca com o jogo, a forma e o texto', (
      tester,
    ) async {
      await _pump(
        tester,
        const Scaffold(body: SingleChildScrollView(child: MovesTab(formId: 1))),
      );
      await tester.enterText(find.byType(TextField), 'seed');
      await tester.pump();
      await tester.tap(find.text('Filtros'));
      await tester.pumpAndSettle();

      final page = tester.widget<MoveSearchPage>(find.byType(MoveSearchPage));
      expect(
        (page.group, page.formId, page.query),
        ('scarlet-violet', 1, 'seed'),
      );
      expect(find.text('2 golpes · Bulbasaur aprende'), findsOneWidget);
    });

    testWidgets('tocar num golpe abre o golpe, no jogo da aba', (tester) async {
      await _pump(
        tester,
        const Scaffold(body: SingleChildScrollView(child: MovesTab(formId: 1))),
      );
      await tester.tap(find.text('Vine Whip'));
      await tester.pumpAndSettle();
      final page = tester.widget<MovePage>(find.byType(MovePage));
      expect((page.move.name, page.group), ('vine-whip', 'scarlet-violet'));
    });
  });
}
