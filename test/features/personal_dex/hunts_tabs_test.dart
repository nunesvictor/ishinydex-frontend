import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/personal_dex/data/last_dex_storage.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/hunts_page.dart';
import 'package:ishinydex/features/shiny_hunts/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/presentation/hunt_card.dart';
import 'package:ishinydex/features/shiny_hunts/presentation/hunt_lists.dart';

import '../../helpers/helpers.dart';

// As abas das Caçadas: Ativas primeiro e a aba inicial (#279), deslizar e o
// seletor com selos (#272).

/// O backend de exemplo, com [active] caçadas em andamento e [paused]
/// pausadas.
Future<FakeBackend> _backend({int active = 0, int paused = 0}) async {
  final backend = FakeBackend.seeded();
  for (var i = 0; i < active + paused; i++) {
    await backend.saveShinyHunt(
      ShinyHunt(id: 0, form: i + 1, paused: i >= active),
    );
  }
  return backend;
}

Future<void> _pump(
  WidgetTester tester,
  FakeBackend backend, {
  HuntsTab? initialTab,
  Size size = compactSize,
  Locale locale = portuguese,
  double textScale = 1,
  bool reduceMotion = false,
}) async {
  await pumpWidgetApp(
    tester,
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduceMotion,
        ),
        child: HuntsPage(dexId: 1, initialTab: initialTab),
      ),
    ),
    size: size,
    locale: locale,
    hunts: backend,
    overrides: [
      fakeBackendProvider.overrideWithValue(backend),
      lastDexStorageProvider.overrideWithValue(InMemoryLastDexStorage()),
    ],
  );
  await tester.pumpAndSettle();
}

/// A aba marcada no seletor.
int _selected(WidgetTester tester) =>
    tester.widget<TabBar>(find.byType(TabBar)).controller!.index;

/// Os ids das caçadas na ordem dos cartões.
List<int> _cards(WidgetTester tester) => [
  for (final card in tester.widgetList<HuntCard>(find.byType(HuntCard)))
    card.hunt.id,
];

void main() {
  for (final size in [compactSize, expandedSize]) {
    final px = '${size.width.toInt()}px';

    testWidgets('ordem: Ativas, Faltam, Pausadas ($px)', (tester) async {
      await _pump(tester, await _backend(paused: 1), size: size);
      final x = [
        for (final label in ['Ativas', 'Faltam', 'Pausadas'])
          tester.getCenter(find.text(label)).dx,
      ];
      expect(x, orderedEquals([...x]..sort()));
      expect(huntsTab('Ativas', '0'), findsOne);
      expect(huntsTab('Pausadas', '1'), findsOne);
      // Sem caçada em andamento, abre em Faltam.
      expect(_selected(tester), HuntsTab.missing.index);
      expect(find.byType(StartHuntButton), findsNothing);
      expect(find.textContaining('para caçar'), findsOne);
    });
  }

  testWidgets('com caçada em andamento, abre em Ativas', (tester) async {
    await _pump(tester, await _backend(active: 1));
    expect(_selected(tester), HuntsTab.active.index);
    expect(find.byType(HuntCards), findsOne);
    expect(find.byType(StartHuntButton), findsOne);
  });

  testWidgets('o atalho escolhe a aba, mesmo sem caçada', (tester) async {
    await _pump(tester, await _backend(), initialTab: HuntsTab.active);
    expect(_selected(tester), HuntsTab.active.index);
    expect(find.textContaining('Nenhuma caçada em andamento'), findsOne);
  });

  testWidgets('deslizar troca a aba e guarda a busca do Faltam', (
    tester,
  ) async {
    await _pump(tester, await _backend(active: 1));
    // Para a esquerda: a próxima aba.
    await tester.fling(find.byType(TabBarView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(_selected(tester), HuntsTab.missing.index);
    expect(find.byType(StartHuntButton), findsNothing);
    await tester.enterText(find.byType(TextField), 'bulba');
    await tester.pumpAndSettle();

    // Para a direita: volta a Ativas, e o Faltam guarda o que foi digitado.
    await tester.fling(find.byType(TabBarView), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(_selected(tester), HuntsTab.active.index);
    expect(find.byType(StartHuntButton), findsOne);
    await tester.tap(find.text('Faltam'));
    await tester.pumpAndSettle();
    expect(find.text('bulba'), findsOne);
  });

  testWidgets('retomar leva a Ativas, com o cartão no topo e destacado', (
    tester,
  ) async {
    final backend = await _backend(active: 2, paused: 1);
    final paused = (await backend.fetchShinyHunts()).last;
    await _pump(tester, backend);
    await tester.tap(find.text('Pausadas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retomar'));
    // O destaque aparece e some em 2 s.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_selected(tester), HuntsTab.active.index);
    expect(_cards(tester).first, paused.id);
    expect(find.byKey(const ValueKey('hunt-resumed-highlight')), findsOne);
    await tester.pumpAndSettle();
    expect(huntsTab('Ativas', '3'), findsOne);
    expect(huntsTab('Pausadas', '0'), findsOne);
  });

  testWidgets('reduzir movimento: tocar na aba troca sem animação', (
    tester,
  ) async {
    await _pump(tester, await _backend(), reduceMotion: true);
    await tester.tap(find.text('Ativas'));
    await tester.pump();
    // Num quadro só, a aba já está no lugar.
    expect(_selected(tester), HuntsTab.active.index);
    final empty = find.textContaining('Nenhuma caçada em andamento');
    expect(tester.getRect(empty).left, greaterThanOrEqualTo(0));
  });

  group('seletor', () {
    /// A borda direita da aba [label].
    double right(WidgetTester tester, String label) => tester
        .getRect(
          find.ancestor(of: find.text(label), matching: find.byType(Tab)),
        )
        .right;

    testWidgets('as abas ocupam a largura, com o selo no número', (
      tester,
    ) async {
      await _pump(
        tester,
        await _backend(active: 1),
        // Nos testes, a fonte (Ahem) é bem mais larga que a do app.
        size: const Size(600, 800),
        locale: english,
      );
      expect(huntsTab('Active', '1'), findsOne);
      expect(right(tester, 'Paused'), closeTo(600, 3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('com texto a 130%, a fileira rola em vez de cortar', (
      tester,
    ) async {
      await _pump(
        tester,
        await _backend(active: 1, paused: 12),
        size: const Size(375, 800),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
      expect(right(tester, 'Pausadas'), greaterThan(375));
      await tester.drag(find.byType(TabBar), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(right(tester, 'Pausadas'), lessThanOrEqualTo(375));
      expect(huntsTab('Pausadas', '12'), findsOne);
    });
  });
}
