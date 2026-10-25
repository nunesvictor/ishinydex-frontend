import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/hunt_filters.dart';

import '../../helpers/helpers.dart';

/// A semente com o Venusaur (forma 3, vazio no shiny dex) sem shiny.
FakeBackend _backend() =>
    FakeBackend.seeded()
      ..addShinyLock(caption: 'Venusaur de teste', formIds: [3]);

Future<void> _go(WidgetTester tester, String location) async {
  ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
      .read(routerProvider)
      .go(location);
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [compactSize, expandedSize]) {
    final px = '${size.width.toInt()}px';

    testWidgets('shiny locked (#341): contagem, atalho e só elas ($px)', (
      tester,
    ) async {
      await pumpFullApp(tester, size: size, backend: _backend());
      // Na lista de dex, a parte que nunca completa.
      expect(find.text('Faltam 19 · 1 shiny locked'), findsOneWidget);

      await _go(tester, Routes.hunts(dexId: 1));
      expect(find.text('18 para caçar'), findsOneWidget);
      expect(find.text('Venusaur'), findsNothing);

      // O atalho liga "Só shiny locked".
      await tester.tap(find.text('1 shiny locked'));
      await tester.pumpAndSettle();
      expect(find.text('1 shiny locked'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'Só shiny locked'), findsOneWidget);
      expect(find.text('Venusaur'), findsOneWidget);
      // Sem shiny, não há o que caçar: o lock no lugar do botão.
      expect(find.text('Lock: Venusaur de teste'), findsOneWidget);
      expect(find.byTooltip('Começar caçada'), findsNothing);

      // Na folha, a opção marcada e a dica dela.
      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      // A seção fica no fim da folha.
      await tester.scrollUntilVisible(
        find.textContaining('o que impede os 100%'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(HuntFiltersPanel),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.ancestor(
                of: find.text('Só shiny locked'),
                matching: find.byType(ChoiceChip),
              ),
            )
            .selected,
        isTrue,
      );
      expect(
        find.text(
          'Só as formas do dex que não têm shiny: o que impede os 100%.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Com shiny locked'));
      await tester.pumpAndSettle();
      expect(find.text('Entram na lista junto com as outras.'), findsOneWidget);
      await tester.tap(find.text('Sem shiny locked'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Formas sem shiny e os jogos em que a forma é travada ficam fora da '
          'lista.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Mostrar resultados'));
      await tester.pumpAndSettle();
      expect(find.text('18 para caçar'), findsOneWidget);
      expect(find.byType(InputChip), findsNothing);
    });
  }

  testWidgets('em inglês', (tester) async {
    await pumpFullApp(
      tester,
      size: compactSize,
      backend: _backend(),
      language: AppLanguage.en,
    );
    expect(find.text('19 missing · 1 shiny locked'), findsOneWidget);
    await _go(tester, Routes.hunts(dexId: 1));
    await tester.tap(find.text('1 shiny locked'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, 'Only shiny locked'), findsOneWidget);
    expect(find.text('Lock: Venusaur de teste'), findsOneWidget);
  });

  testWidgets('tudo o que falta é shiny locked: o vazio, com o atalho', (
    tester,
  ) async {
    final backend = FakeBackend()..addForm(id: 1, name: 'cosmoem');
    final dex = backend.addDex(name: 'Shiny', isShinyDex: true);
    backend
      ..addBox(dexId: dex, name: 'HOME 1', formIds: [1])
      ..addShinyLock(caption: 'Cosmog-Cosmoem', formIds: [1]);
    await pumpFullApp(tester, size: compactSize, backend: backend);
    await _go(tester, Routes.hunts(dexId: dex));
    expect(find.text('Nada para caçar com estes filtros.'), findsOneWidget);
    await tester.tap(find.text('1 shiny locked'));
    await tester.pumpAndSettle();
    expect(find.text('Cosmoem'), findsOneWidget);
    expect(find.text('Lock: Cosmog-Cosmoem'), findsOneWidget);
  });
}
