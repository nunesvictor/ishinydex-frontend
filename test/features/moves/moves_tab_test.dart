import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/moves/domain/moves_data.dart';
import 'package:ishinydex/features/moves/moves_providers.dart';
import 'package:ishinydex/features/moves/presentation/moves_tab.dart';
import 'package:ishinydex/features/moves/presentation/moves_widgets.dart';
import 'package:ishinydex/features/moves/presentation/sticky_section.dart';

import '../../fixtures/catalog_fixture.dart';
import '../../fixtures/moves_fixture.dart';
import '../../helpers/helpers.dart';

final Catalog _catalog = Catalog.fromJson({
  ...catalogJson(),
  'movesFile': 'moves-2026.10.03.json',
}, spriteBase: 'https://sprites/');

/// O estado dos golpes fixo, sem download; conta os "tentar de novo".
class _Fixed extends MovesNotifier {
  _Fixed(this.initial);

  final MovesState initial;
  static int retries = 0;

  @override
  MovesState build() => initial;

  @override
  void retry() => retries++;
}

Future<void> _pump(
  WidgetTester tester,
  MovesState state, {
  int formId = 1,
  String? gameHint,
  Size size = compactSize,
  Locale locale = portuguese,
}) => pumpWidgetApp(
  tester,
  Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: MovesTab(formId: formId, gameHint: gameHint),
    ),
  ),
  size: size,
  locale: locale,
  overrides: [
    fakeBackendProvider.overrideWithValue(FakeBackend.fromCatalog(_catalog)),
    movesProvider.overrideWith(() => _Fixed(state)),
  ],
);

MovesReady get _ready => MovesReady(MovesData.fromJson(movesJson()));

List<String?> _texts(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(find.byType(Text))) t.data,
];

void main() {
  for (final size in [compactSize, expandedSize]) {
    testWidgets('as seções por modo, no jogo mais recente '
        '(${size.width.toInt()}px)', (tester) async {
      await _pump(tester, _ready, size: size);

      expect(find.text('Scarlet / Violet'), findsOneWidget);
      // Os cabeçalhos com a contagem, na ordem: nível, TM, ovo, tutor, outros.
      final texts = _texts(tester);
      expect(
        [
          for (final t in texts)
            if (const [
              'Por nível',
              'Por TM',
              'Por ovo',
              'Por tutor',
              'Outros',
            ].contains(t))
              t,
        ],
        // Cada cabeçalho aparece duas vezes: o lugar e o visível.
        [
          for (final h in [
            'Por nível',
            'Por TM',
            'Por ovo',
            'Por tutor',
            'Outros',
          ]) ...[h, h],
        ],
      );
      // Por nível: pelo nível; por TM: pelo número, com três dígitos na 9ª
      // geração.
      expect(find.text('Nv. 1'), findsNWidgets(2));
      expect(find.text('Nv. 3'), findsOneWidget);
      expect(find.text('TM001'), findsOneWidget);
      expect(find.text('TM071'), findsOneWidget);
      expect(texts.indexOf('TM001'), lessThan(texts.indexOf('TM071')));
      // O modo raro, ao lado do tipo.
      expect(find.text('Treino'), findsOneWidget);
      // Poder / precisão / PP; sem poder, o traço.
      expect(find.text('—'), findsNWidgets(2));
      expect(find.byType(MoveCategoryIcon), findsNWidgets(8));
      // Mesmo nível: pelo nome (Leech Seed antes do Tackle).
      expect(texts.indexOf('Leech Seed'), lessThan(texts.indexOf('Tackle')));
    });
  }

  testWidgets('o jogo do espécime; a TM com dois dígitos e o valor antigo', (
    tester,
  ) async {
    await _pump(tester, _ready, gameHint: 'y');

    expect(find.text('X / Y'), findsOneWidget);
    expect(find.text('TM86'), findsOneWidget);
    // O Tackle no X/Y: o poder de antes do Sun/Moon.
    expect(find.text('50'), findsOneWidget);
    // Jogo do espécime sem golpes da forma: o mais recente.
    await _pump(tester, _ready, gameHint: 'red');
    expect(find.text('Scarlet / Violet'), findsOneWidget);
  });

  testWidgets('trocar o jogo pela lista, agrupada por geração', (tester) async {
    await _pump(tester, _ready);

    await tester.tap(find.byKey(const ValueKey('moves-game')));
    await tester.pumpAndSettle();
    expect(find.text('GERAÇÃO IX'), findsOneWidget);
    expect(find.text('GERAÇÃO VI'), findsOneWidget);
    // Fora do catálogo, pelo nome do grupo, sem geração.
    expect(find.text('Champions'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    await tester.tap(find.text('X / Y'));
    await tester.pumpAndSettle();
    expect(find.text('TM86'), findsOneWidget);

    // Fechar sem escolher mantém o jogo.
    await tester.tap(find.byKey(const ValueKey('moves-game')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('TM86'), findsOneWidget);
  });

  testWidgets('buscar filtra todas as seções e some com as vazias', (
    tester,
  ) async {
    await _pump(tester, _ready);

    await tester.enterText(find.byType(TextField), 'tack');
    await tester.pump();
    // O Tackle por nível e por TM (cada cabeçalho tem o lugar e o visível).
    expect(find.text('1 de 3 golpes'), findsNWidgets(2));
    expect(find.text('1 de 2 golpes'), findsNWidgets(2));
    expect(find.text('Por ovo'), findsNothing);
    expect(find.text('Vine Whip'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('Nenhum golpe com “zzz”'), findsOneWidget);

    await tester.tap(find.byTooltip('Limpar'));
    await tester.pump();
    expect(find.text('Vine Whip'), findsNWidgets(1));
    expect(find.text('3 golpes'), findsNWidgets(2));
    expect(find.text('2 golpes'), findsNWidgets(2));
  });

  testWidgets('em inglês', (tester) async {
    await _pump(tester, _ready, locale: english);

    expect(find.text('Search move'), findsOneWidget);
    expect(find.text('Level up'), findsNWidgets(2));
    expect(find.text('Lv. 1'), findsNWidgets(2));
    expect(find.text('Training'), findsOneWidget);
    expect(find.text('1 move'), findsNWidgets(6));
  });

  testWidgets('forma sem golpes próprios: os da forma padrão da espécie', (
    tester,
  ) async {
    // O Venusaur Mega (10033) não tem golpes no pacote: os do Venusaur.
    await _pump(tester, _ready, formId: 10033);
    expect(find.text('TM'), findsOneWidget);
    expect(find.text('Vine Whip'), findsOneWidget);

    // O Mewtwo não tem golpes nenhum.
    await _pump(tester, _ready, formId: 150);
    expect(find.text('Esta forma não tem golpes no catálogo'), findsOneWidget);
  });

  group('carregando', () {
    testWidgets('baixando, com o total: a barra e os MB', (tester) async {
      await _pump(
        tester,
        const MovesDownloading(received: 1258291, total: 5452595),
      );
      expect(find.text('Baixando os golpes…'), findsOneWidget);
      expect(find.text('1,2 de 5,2 MB'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(0.23, 0.01));
    });

    testWidgets('sem o total: a barra indeterminada e o recebido', (
      tester,
    ) async {
      await _pump(tester, const MovesDownloading(received: 524288));
      expect(find.text('0,5 MB'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        isNull,
      );
    });

    testWidgets('preparando', (tester) async {
      await _pump(tester, const MovesPreparing());
      expect(find.text('Preparando os golpes…'), findsOneWidget);
    });

    testWidgets('sem internet e erro: a mensagem e o tentar de novo', (
      tester,
    ) async {
      await _pump(tester, const MovesFailed(offline: true));
      expect(
        find.text('Os golpes precisam de internet na primeira vez'),
        findsOneWidget,
      );
      _Fixed.retries = 0;
      await tester.tap(find.text('Tentar novamente'));
      expect(_Fixed.retries, 1);
    });

    testWidgets('outro erro', (tester) async {
      await _pump(tester, const MovesFailed(offline: false));
      expect(find.text('Não foi possível baixar os golpes'), findsOneWidget);
    });

    testWidgets('sem o arquivo dos golpes', (tester) async {
      await _pump(tester, const MovesUnavailable());
      expect(
        find.text('Os golpes não estão disponíveis neste catálogo'),
        findsOneWidget,
      );
    });
  });

  testWidgets('o ícone da categoria: a imagem, e o nome se ela falhar', (
    tester,
  ) async {
    await pumpWidgetApp(
      tester,
      const Row(
        children: [
          MoveCategoryIcon('physical'),
          MoveCategoryIcon('special'),
          MoveCategoryIcon('status'),
        ],
      ),
    );
    expect(find.byTooltip('Físico'), findsOneWidget);
    expect(find.byTooltip('Especial'), findsOneWidget);
    expect(find.byTooltip('Status'), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image).first);
    final fallback = image.errorBuilder!(
      tester.element(find.byType(Image).first),
      Exception(),
      null,
    );
    expect((fallback as Text).data, 'Físico');
  });

  test('o nome dos modos raros e a geração como número', () {
    for (final (method, text) in [
      ('light-ball-egg', 'Ovo com Light Ball'),
      ('form-change', 'Troca de forma'),
      ('zygarde-cube', 'Zygarde Cube'),
      ('stadium-surfing-pikachu', 'Pokémon Stadium (Surfing Pikachu)'),
      ('train', 'Treino'),
      ('xd-purification', 'Purificação (XD)'),
      ('new-method', 'New Method'),
    ]) {
      expect(moveMethodLabel(ptText, method), text);
    }
    expect(generationRank('generation-ix'), 9);
    expect(generationRank('generation-i'), 1);
    expect(generationRank(null), isNull);
    expect(generationRank('generation-x'), isNull);
  });

  testWidgets('o cabeçalho fica preso enquanto a seção rola', (tester) async {
    await setScreenSize(tester, const Size(400, 300));
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: controller,
            child: Column(
              children: [
                const SizedBox(height: 100),
                StickySection(
                  header: const SizedBox(height: 40, child: Text('Seção')),
                  children: [
                    for (var i = 0; i < 10; i++)
                      SizedBox(height: 50, child: Text('linha $i')),
                  ],
                ),
                const SizedBox(height: 600),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    double top() => tester
        .widget<Positioned>(
          find.ancestor(
            of: find.byKey(const ValueKey('sticky-header')),
            matching: find.byType(Positioned),
          ),
        )
        .top!;
    double elevation() => tester
        .widget<Material>(find.byKey(const ValueKey('sticky-header')))
        .elevation;
    expect((top(), elevation()), (0, 0));

    // A seção subiu 150 além do topo: o cabeçalho desce 150, com sombra.
    controller.jumpTo(250);
    await tester.pump();
    expect((top(), elevation()), (150, 2));

    // No fim da seção, ele para (500 de linhas - 40 do cabeçalho... + 40).
    controller.jumpTo(800);
    await tester.pump();
    expect(top(), 500);
  });
}
