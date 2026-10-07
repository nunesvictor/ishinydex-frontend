import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/widgets/game_icon.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/presentation/hunts_page.dart';

import '../../fixtures/catalog_fixture.dart';
import '../../helpers/helpers.dart';

/// A demonstração com o catálogo da fixture (saves de Scarlet, "Switch", e
/// de Legends: Z-A) e um shiny dex novo, vazio, com o dex padrão: tudo nas
/// caçadas.
Future<void> _openHunts(WidgetTester tester, {required Size size}) async {
  final catalog = Catalog.fromJson(
    catalogJson(),
    spriteBase: Env.defaultSpritesBaseUrl,
  );
  final backend = FakeBackend.fromCatalog(catalog);
  final dexId = backend.addDex(name: 'Caça', isShinyDex: true);
  backend.addBox(dexId: dexId, name: 'Caça 1', formIds: catalog.defaultDex);
  await pumpFullApp(tester, size: size, backend: backend);
  ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
      .read(routerProvider)
      .go(Routes.dex(dexId));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Caçadas'));
  await tester.pumpAndSettle();
}

/// Os ícones de jogo da caçada de [name]: `scarlet` colorido, `~violet` em
/// cinza.
List<String> _icons(WidgetTester tester, String name) => [
  for (final icon in tester.widgetList<GameIcon>(
    find.descendant(
      of: find.ancestor(of: find.text(name), matching: find.byType(ListTile)),
      matching: find.byType(GameIcon),
    ),
  ))
    '${icon.muted ? '~' : ''}${icon.version}',
];

Future<void> _pickGame(WidgetTester tester, String chip, String game) async {
  await tester.tap(find.widgetWithText(FilterChip, chip));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(RadioMenuButton<String?>),
      matching: find.text(game),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [compactSize, expandedSize]) {
    final px = '${size.width.toInt()}px';

    testWidgets('ícones dos jogos e filtro pelos seus saves ($px)', (
      tester,
    ) async {
      await _openHunts(tester, size: size);

      // Colorido: save seu; cinza: jogo sem save seu; exclusivos só na
      // versão deles (Espeon: Scarlet; Vaporeon: Violet, sem save).
      expect(_icons(tester, 'Espeon'), ['scarlet']);
      expect(_icons(tester, 'Vaporeon'), ['~sword', '~shield', '~violet']);
      // Eevee: shiny lock em Scarlet (o catálogo de teste), sem o ícone.
      expect(_icons(tester, 'Eevee'), ['~sword', '~shield', '~violet']);
      expect(_icons(tester, 'Nihilego'), isEmpty);

      await _pickGame(tester, 'Jogo', 'Scarlet');
      expect(find.widgetWithText(FilterChip, 'Scarlet'), findsOneWidget);
      expect(find.text('Espeon'), findsOneWidget);
      expect(find.text('Vaporeon'), findsNothing);

      // Nenhuma pokédex de Z-A no catálogo da fixture.
      await _pickGame(tester, 'Scarlet', 'Legends: Z-A');
      expect(find.text('Nada para caçar com estes filtros.'), findsOneWidget);

      await _pickGame(tester, 'Legends: Z-A', 'Todos os jogos');
      expect(find.widgetWithText(FilterChip, 'Jogo'), findsOneWidget);
      expect(find.text('Vaporeon'), findsOneWidget);
    });
  }

  test('incluir shiny locks devolve o jogo travado', () async {
    final catalog = Catalog.fromJson(
      catalogJson(),
      spriteBase: Env.defaultSpritesBaseUrl,
    );
    final backend = FakeBackend.fromCatalog(catalog);
    final dexId = backend.addDex(name: 'Caça', isShinyDex: true);
    backend.addBox(dexId: dexId, name: 'Caça 1', formIds: const [133]);
    Future<List<String>> versions(HuntQuery query) async =>
        (await backend.fetchHunts(
          dexId,
          query,
          page: 1,
          pageSize: 10,
        )).results.single.versions;

    expect(await versions(const HuntQuery()), isNot(contains('scarlet')));
    expect(
      await versions(const HuntQuery(includeLocked: true)),
      contains('scarlet'),
    );
    expect(
      (await backend.fetchHunts(
        dexId,
        const HuntQuery(version: 'scarlet'),
        page: 1,
        pageSize: 10,
      )).results,
      isEmpty,
    );
  });

  testWidgets('sem o catálogo das pokédex: sem o filtro nem ícones', (
    tester,
  ) async {
    await pumpFullApp(tester, size: compactSize);
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
        .read(routerProvider)
        .go(Routes.dex(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Caçadas'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilterChip, 'Jogo'), findsNothing);
    expect(find.byType(GameIcon), findsNothing);
  });

  testWidgets('até 4 ícones: os seus primeiro, o resto vira "+N"', (
    tester,
  ) async {
    await pumpWidgetApp(
      tester,
      const Scaffold(
        body: HuntGames(
          versions: [
            'sword',
            'shield',
            'brilliant-diamond',
            'shining-pearl',
            'legends-arceus',
            'scarlet',
          ],
          owned: {'scarlet'},
        ),
      ),
    );

    final icons = tester.widgetList<GameIcon>(find.byType(GameIcon));
    expect(
      [for (final i in icons) '${i.muted ? '~' : ''}${i.version}'],
      ['scarlet', '~sword', '~shield', '~brilliant-diamond'],
    );
    expect(find.text('+2'), findsOneWidget);
    expect(find.bySemanticsLabel('mais 2 jogos sem save seu'), findsOneWidget);
  });
}
