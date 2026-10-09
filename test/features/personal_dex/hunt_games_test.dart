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

/// Abre o menu do chip [chip], marca ou desmarca os [games] (o menu fica
/// aberto) e fecha em "Pronto".
Future<void> _toggleGames(
  WidgetTester tester,
  String chip,
  List<String> games,
) async {
  await tester.tap(find.widgetWithText(FilterChip, chip));
  await tester.pumpAndSettle();
  for (final game in games) {
    await tester.tap(
      find.descendant(
        of: find.byType(CheckboxMenuButton),
        matching: find.text(game),
      ),
    );
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Pronto'));
  await tester.pumpAndSettle();
}

/// A caixa do item [game] do menu Jogo (aberto).
bool? _checked(WidgetTester tester, String game) => tester
    .widget<CheckboxMenuButton>(
      find.ancestor(
        of: find.text(game),
        matching: find.byType(CheckboxMenuButton),
      ),
    )
    .value;

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

      await _toggleGames(tester, 'Jogo', ['Scarlet']);
      expect(find.widgetWithText(FilterChip, 'Scarlet'), findsOneWidget);
      expect(find.textContaining('para caçar em Scarlet'), findsOneWidget);
      expect(find.text('Espeon'), findsOneWidget);
      expect(find.text('Vaporeon'), findsNothing);

      // Vários: quem dá para caçar em qualquer um (Z-A não tem pokédex no
      // catálogo da fixture, então nada muda na lista).
      await _toggleGames(tester, 'Scarlet', ['Legends: Z-A']);
      expect(find.widgetWithText(FilterChip, 'Scarlet +1'), findsOneWidget);
      expect(
        find.textContaining('para caçar em Scarlet ou Legends: Z-A'),
        findsOneWidget,
      );
      expect(find.text('Espeon'), findsOneWidget);

      // O menu mostra o que está marcado e quantos há em cada jogo.
      await tester.tap(find.widgetWithText(FilterChip, 'Scarlet +1'));
      await tester.pumpAndSettle();
      expect(_checked(tester, 'Todos os jogos'), isFalse);
      expect(_checked(tester, 'Scarlet'), isTrue);
      expect(_checked(tester, 'Legends: Z-A'), isTrue);
      final zaCount = find.descendant(
        of: find.ancestor(
          of: find.text('Legends: Z-A'),
          matching: find.byType(CheckboxMenuButton),
        ),
        matching: find.text('0'),
      );
      expect(zaCount, findsOneWidget);
      await tester.tap(find.text('Pronto'));
      await tester.pumpAndSettle();

      await _toggleGames(tester, 'Scarlet +1', ['Scarlet']);
      expect(find.text('Nada para caçar com estes filtros.'), findsOneWidget);

      await _toggleGames(tester, 'Legends: Z-A', ['Todos os jogos']);
      expect(find.widgetWithText(FilterChip, 'Jogo'), findsOneWidget);
      expect(find.text('Vaporeon'), findsOneWidget);
      // Já sem filtro, "Todos os jogos" fica marcado e desabilitado.
      await tester.tap(find.widgetWithText(FilterChip, 'Jogo'));
      await tester.pumpAndSettle();
      expect(_checked(tester, 'Todos os jogos'), isTrue);
      expect(
        tester
            .widget<CheckboxMenuButton>(
              find.ancestor(
                of: find.text('Todos os jogos'),
                matching: find.byType(CheckboxMenuButton),
              ),
            )
            .onChanged,
        isNull,
      );
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
        const HuntQuery(versions: ['scarlet']),
        page: 1,
        pageSize: 10,
      )).results,
      isEmpty,
    );
    // Vários jogos: basta um deles.
    expect(
      (await backend.fetchHunts(
        dexId,
        const HuntQuery(versions: ['scarlet', 'sword']),
        page: 1,
        pageSize: 10,
      )).results,
      hasLength(1),
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
