import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/personal_dex/data/last_dex_storage.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/hunts_page.dart';
import 'package:ishinydex/features/personal_dex/presentation/new_dex_page.dart';
import 'package:ishinydex/features/specimens/presentation/saves_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/catalog_fixture.dart';
import '../../helpers/helpers.dart';
import '../../helpers/mocks.dart';

// Caçadas sem PersonalDex (#246): a aba própria na navegação, o Faltam com e
// sem shiny dex e a folha sem save.

/// Um aparelho novo: só o catálogo, sem dex, OT nem save.
FakeBackend _newDevice() => FakeBackend.local(
  Catalog.fromJson(catalogJson(), spriteBase: Env.defaultSpritesBaseUrl),
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _go(WidgetTester tester, String location) async {
  ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
      .read(routerProvider)
      .go(location);
  await tester.pumpAndSettle();
}

/// O destino "Caçadas" da barra (ou do rail).
Finder _huntsDestination(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is NavigationBar || w is NavigationRail),
  matching: find.text(label),
);

String _location(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
        .read(routerProvider)
        .state
        .uri
        .toString();

void main() {
  for (final size in [compactSize, expandedSize]) {
    final px = '${size.width.toInt()}px';

    testWidgets('aparelho novo: caçar sem dex nem save ($px)', (tester) async {
      final backend = _newDevice();
      await pumpFullApp(tester, size: size, backend: backend);

      // O PersonalDex vazio aponta para a aba Caçadas.
      expect(
        find.text('Só quer acompanhar caçadas? Elas ficam na aba Caçadas.'),
        findsOneWidget,
      );
      await _tap(tester, _huntsDestination('Caçadas'));

      // Faltam sem shiny dex: o convite.
      expect(find.text('O que falta caçar?'), findsOneWidget);
      expect(find.text('Criar shiny dex'), findsOneWidget);
      // Sem shiny dex, a aba fica sem número (#277).
      expect(find.text('Faltam'), findsOneWidget);
      // Criar e desistir: continua no convite.
      await _tap(tester, find.text('Criar shiny dex'));
      expect(find.byType(NewDexPage), findsOneWidget);
      await _tap(tester, find.byIcon(Icons.close));
      expect(find.text('O que falta caçar?'), findsOneWidget);

      // Ativas vazia: a dica sem dex.
      await _tap(tester, find.text('Ativas (0)'));
      expect(
        find.textContaining('Vale qualquer forma, com ou sem dex.'),
        findsOneWidget,
      );

      // Começar uma caçada: sem save, a dica e a caçada sai do mesmo jeito.
      await _tap(tester, find.text('Começar caçada'));
      await tester.enterText(find.byType(TextField).last, 'ivysaur');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const ValueKey('form-2')));
      expect(
        find.textContaining('Sem um save, a caçada conta encontros'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('field-hunt-save')), findsNothing);
      await _tap(tester, find.text('Começar'));
      expect((await backend.fetchShinyHunts()).single.form, 2);
      expect(find.text('Ativas (1)'), findsOneWidget);
    });
  }

  testWidgets('folha sem save: "Adicionar save" leva a Meus saves', (
    tester,
  ) async {
    await pumpFullApp(tester, backend: _newDevice());
    await _go(tester, Routes.hunts(active: true));
    await _tap(tester, find.text('Começar caçada'));
    await tester.enterText(find.byType(TextField).last, 'ivysaur');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const ValueKey('form-2')));
    await _tap(tester, find.text('Adicionar save'));
    expect(find.byType(SavesPage), findsOneWidget);
  });

  testWidgets('criar o shiny dex pelo convite abre o Faltam nele', (
    tester,
  ) async {
    await pumpFullApp(tester, backend: _newDevice());
    await _go(tester, Routes.hunts());
    await _tap(tester, find.text('Criar shiny dex'));
    await tester.enterText(find.byType(TextField).first, 'Caça');
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Shiny dex'));
    await _tap(tester, find.text('Criar PersonalDex'));
    expect(find.byType(HuntsPage), findsOneWidget);
    expect(find.text('O que falta caçar?'), findsNothing);
    expect(find.textContaining('para caçar'), findsOneWidget);
  });

  testWidgets('dois shiny dex: o seletor troca e lembra o escolhido', (
    tester,
  ) async {
    final backend = FakeBackend.seeded();
    final second = backend.addDex(name: 'Segundo', isShinyDex: true);
    final storage = InMemoryLastDexStorage();
    await pumpFullApp(tester, backend: backend, lastDex: storage);
    await _go(tester, Routes.hunts());

    // Sem escolha: o primeiro shiny dex.
    expect(find.text('Shiny Living Dex'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('hunts-dex-picker')));
    await _tap(tester, find.text('Segundo').last);
    expect(_location(tester), Routes.hunts(dexId: second));
    expect(await storage.readHunts(), second);
    // Um dex vazio: nada para caçar.
    expect(find.text('Nada para caçar com estes filtros.'), findsOneWidget);

    // Voltando à aba sem dex na URL, fica o lembrado.
    await _go(tester, Routes.hunts());
    expect(find.text('Segundo'), findsOneWidget);
  });

  testWidgets('um shiny dex só: sem seletor', (tester) async {
    await pumpFullApp(tester);
    await _go(tester, Routes.hunts());
    expect(find.byKey(const ValueKey('hunts-dex-picker')), findsNothing);
    expect(find.textContaining('para caçar'), findsOneWidget);
  });

  testWidgets('rotas antigas redirecionam para a aba Caçadas', (tester) async {
    await pumpFullApp(tester);
    await _go(tester, '/dexes/1/hunts');
    expect(_location(tester), Routes.hunts(dexId: 1));
    await _go(tester, '/dexes/1/hunts?tab=active');
    expect(_location(tester), Routes.hunts(dexId: 1, active: true));
    expect(find.textContaining('Comece por um item de Faltam'), findsOneWidget);
  });

  testWidgets('item do Faltam abre o dex dentro da aba; voltar retorna', (
    tester,
  ) async {
    // No tamanho padrão (PC), o slot abre no painel lateral, sem folha.
    await pumpFullApp(tester);
    await _go(tester, Routes.hunts());
    await _tap(tester, find.text('Venusaur'));
    expect(_location(tester), startsWith('/hunts/dex/1?'));
    await _tap(tester, find.byType(BackButton));
    expect(_location(tester), Routes.hunts());
  });

  testWidgets('erro na lista de dex: "Tentar novamente" no Faltam', (
    tester,
  ) async {
    final repository = MockPersonalDexRepository();
    var calls = 0;
    when(repository.fetchDexes).thenAnswer((_) async {
      if (calls++ == 0) throw const NotFoundFailure();
      return const [];
    });
    await pumpWidgetApp(
      tester,
      const HuntsPage(),
      overrides: [
        personalDexRepositoryProvider.overrideWithValue(repository),
        lastDexStorageProvider.overrideWithValue(InMemoryLastDexStorage()),
      ],
    );
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Tentar novamente'));
    expect(find.text('O que falta caçar?'), findsOneWidget);
  });

  testWidgets('em inglês: a aba, o convite e a dica sem save', (tester) async {
    await pumpFullApp(tester, backend: _newDevice(), language: AppLanguage.en);
    expect(
      find.text('Just want to track hunts? They live in the Hunts tab.'),
      findsOneWidget,
    );
    await _tap(tester, _huntsDestination('Hunts'));
    expect(find.text("What's left to hunt?"), findsOneWidget);
    expect(find.text('Create shiny dex'), findsOneWidget);
    expect(find.text("Hunts in Active don't depend on it."), findsOneWidget);
    await _tap(tester, find.text('Active (0)'));
    expect(find.textContaining('with or without a dex'), findsOneWidget);
    await _tap(tester, find.text('Start hunt'));
    await tester.enterText(find.byType(TextField).last, 'ivysaur');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const ValueKey('form-2')));
    expect(find.textContaining('Without a save'), findsOneWidget);
    expect(find.text('Add save'), findsOneWidget);
  });
}
