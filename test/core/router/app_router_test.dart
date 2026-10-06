import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';
import '../../helpers/mocks.dart';

void main() {
  test('rotas', () {
    expect(Routes.home, '/');
    expect(Routes.dex(3), '/dexes/3');
    expect(Routes.dex(3, boxId: 2, slotId: 40), '/dexes/3?box=2&slot=40');
    expect(Routes.specimen(7), '/specimens/7');
  });

  testWidgets('abre direto nos dexes, com a NavigationBar no celular', (
    tester,
  ) async {
    await pumpFullApp(tester, size: compactSize);
    expect(find.text('Shiny Living Dex'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('shell com NavigationRail e troca de aba', (tester) async {
    await pumpFullApp(tester, size: mediumSize);
    expect(find.byType(NavigationRail), findsOneWidget);
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Sobre o iShinyDex'), findsOneWidget);
    await tester.tap(find.text('PersonalDex').first);
    await tester.pumpAndSettle();
    expect(find.text('Shiny Living Dex'), findsOneWidget);
    // Tocar na aba atual volta para a raiz da aba.
    await tester.tap(find.text('Shiny Living Dex'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.byIcon(Icons.catching_pokemon),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Shiny Living Dex'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('falha ao decidir o dex inicial cai na lista', (tester) async {
    final repository = MockPersonalDexRepository();
    var calls = 0;
    when(repository.fetchDexes).thenAnswer((_) async {
      if (calls++ == 0) throw const NetworkFailure();
      return const [PersonalDex(id: 1, name: 'Ok', total: 1, registered: 0)];
    });
    await pumpFullApp(
      tester,
      overrides: [personalDexRepositoryProvider.overrideWithValue(repository)],
    );
    // Um único dex, mas a 1ª chamada (do redirect) falhou: ficou na lista.
    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('Ok'), findsOneWidget);
  });

  testWidgets('rail estendido só em telas largas', (tester) async {
    await pumpFullApp(tester);
    NavigationRail rail() =>
        tester.widget<NavigationRail>(find.byType(NavigationRail));
    // Até 1440px o rail fica compacto: a largura vai para a grade.
    expect(rail().extended, false);
    await setScreenSize(tester, largeSize);
    await tester.pumpAndSettle();
    expect(rail().extended, true);
  });

  testWidgets('dexId inválido mostra erro', (tester) async {
    await pumpFullApp(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    container.read(routerProvider).go('/dexes/abc');
    await tester.pumpAndSettle();
    expect(find.text('Recurso não encontrado.'), findsOneWidget);
  });
}
