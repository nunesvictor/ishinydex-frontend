import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/theme/version_colors.dart';
import 'package:ishinydex/core/widgets/game_icon.dart';
import 'package:ishinydex/core/widgets/menu_chip.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/presentation/hunts_page.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

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
      .go(Routes.hunts(dexId: dexId));
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

/// Abre a folha do chip [chip], marca ou desmarca os [games] e aplica em
/// "Mostrar resultados".
Future<void> _toggleGames(
  WidgetTester tester,
  String chip,
  List<String> games,
) async {
  // Sem filtro, o chip mostra o nome; com jogos, só os ícones (#219).
  final byText = find.widgetWithText(FilterChip, chip);
  await tester.tap(byText.evaluate().isEmpty ? find.byTooltip(chip) : byText);
  await tester.pumpAndSettle();
  for (final game in games) {
    await tester.tap(
      find.descendant(
        of: find.byType(CheckboxListTile),
        matching: find.text(game),
      ),
    );
    await tester.pumpAndSettle();
  }
  await tester.tap(find.textContaining('Mostrar'));
  await tester.pumpAndSettle();
}

/// O chip Jogo, pelo tooltip (com jogos marcados, ele só mostra ícones).
FilterChip _gameChip(WidgetTester tester, String tooltip) =>
    tester.widget<FilterChip>(
      find.ancestor(
        of: find.byTooltip(tooltip),
        matching: find.byType(FilterChip),
      ),
    );

/// A caixa do item [game] da folha Jogo (aberta).
bool? _checked(WidgetTester tester, String game) => tester
    .widget<CheckboxListTile>(
      find.ancestor(
        of: find.text(game),
        matching: find.byType(CheckboxListTile),
      ),
    )
    .value;

void main() {
  for (final size in [compactSize, expandedSize]) {
    final px = '${size.width.toInt()}px';

    testWidgets('chips: Situação · Jogo · Motivos (#251, $px)', (tester) async {
      await _openHunts(tester, size: size);
      expect(
        readingOrder(tester, [
          find.widgetWithText(MenuChip, 'Situação'),
          find.widgetWithText(FilterChip, 'Jogo'),
          // O chip Motivos sempre tem algo marcado: só ícones e o tooltip.
          find.byWidgetPredicate(
            (w) => w is Tooltip && (w.message ?? '').startsWith('Motivos'),
          ),
        ]),
        [0, 1, 2],
      );
    });

    testWidgets('ícones dos jogos e filtro pelos seus saves ($px)', (
      tester,
    ) async {
      await _openHunts(tester, size: size);

      // Só os jogos dos seus saves (#202); exclusivos só na versão deles
      // (Espeon: Scarlet; Vaporeon: Violet, sem save seu).
      expect(_icons(tester, 'Espeon'), ['scarlet']);
      expect(_icons(tester, 'Vaporeon'), isEmpty);
      // Eevee: shiny lock em Scarlet (o catálogo de teste), sem o ícone.
      expect(_icons(tester, 'Eevee'), isEmpty);
      expect(_icons(tester, 'Nihilego'), isEmpty);

      await _toggleGames(tester, 'Jogo', ['Scarlet']);
      expect(find.byTooltip('Jogo: Scarlet'), findsOneWidget);
      // Um jogo só: o chip na cor dele (#203).
      expect(
        _gameChip(tester, 'Jogo: Scarlet').selectedColor,
        versionTone('scarlet', Brightness.light)!.background,
      );
      expect(find.textContaining('para caçar em Scarlet'), findsOneWidget);
      expect(find.text('Espeon'), findsOneWidget);
      expect(find.text('Vaporeon'), findsNothing);

      // Vários: quem dá para caçar em qualquer um (Z-A não tem pokédex no
      // catálogo da fixture, então nada muda na lista).
      await _toggleGames(tester, 'Jogo: Scarlet', ['Legends: Z-A']);
      expect(find.byTooltip('Jogo: Scarlet e Legends: Z-A'), findsOneWidget);
      // Dois: a cor neutra do tema.
      expect(
        _gameChip(tester, 'Jogo: Scarlet e Legends: Z-A').selectedColor,
        isNull,
      );
      expect(
        find.textContaining('para caçar em Scarlet ou Legends: Z-A'),
        findsOneWidget,
      );
      expect(find.text('Espeon'), findsOneWidget);

      // A folha mostra o que está marcado e quantos há em cada jogo.
      await tester.tap(find.byTooltip('Jogo: Scarlet e Legends: Z-A'));
      await tester.pumpAndSettle();
      expect(_checked(tester, 'Todos os jogos'), isFalse);
      expect(_checked(tester, 'Scarlet'), isTrue);
      expect(_checked(tester, 'Legends: Z-A'), isTrue);
      final zaCount = find.descendant(
        of: find.ancestor(
          of: find.text('Legends: Z-A'),
          matching: find.byType(CheckboxListTile),
        ),
        matching: find.text('0'),
      );
      expect(zaCount, findsOneWidget);
      // Fechar sem aplicar não muda nada.
      Navigator.of(tester.element(find.byType(CheckboxListTile).first)).pop();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Jogo: Scarlet e Legends: Z-A'), findsOneWidget);
      // Dois: a cor neutra do tema.
      expect(
        _gameChip(tester, 'Jogo: Scarlet e Legends: Z-A').selectedColor,
        isNull,
      );

      await _toggleGames(tester, 'Jogo: Scarlet e Legends: Z-A', ['Scarlet']);
      expect(find.text('Nada para caçar com estes filtros.'), findsOneWidget);

      await _toggleGames(tester, 'Jogo: Legends: Z-A', ['Todos os jogos']);
      expect(find.widgetWithText(FilterChip, 'Jogo'), findsOneWidget);
      expect(find.text('Vaporeon'), findsOneWidget);
      // Já sem filtro, "Todos os jogos" fica marcado.
      await tester.tap(find.widgetWithText(FilterChip, 'Jogo'));
      await tester.pumpAndSettle();
      expect(_checked(tester, 'Todos os jogos'), isTrue);
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
        .go(Routes.hunts(dexId: 1));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilterChip, 'Jogo'), findsNothing);
    expect(find.byType(GameIcon), findsNothing);
  });

  testWidgets('até 3 ícones sobrepostos, só dos seus saves; "+N" dos seus', (
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
            'legends-arceus',
            'scarlet',
            'violet',
          ],
          owned: {'sword', 'brilliant-diamond', 'scarlet', 'violet'},
        ),
      ),
    );

    final icons = tester.widgetList<GameIcon>(find.byType(GameIcon));
    expect(
      [for (final i in icons) '${i.muted ? '~' : ''}${i.version}'],
      ['sword', 'brilliant-diamond', 'scarlet'],
    );
    // Cada um anda 14 px: os 8 px restantes ficam por baixo do seguinte.
    final lefts = [
      for (final i in icons) tester.getTopLeft(find.byWidget(i)).dx,
    ];
    expect([lefts[1] - lefts[0], lefts[2] - lefts[1]], [14, 14]);
    // Shield e Legends: Arceus (sem save) não contam.
    expect(find.text('+1'), findsOneWidget);
    expect(find.bySemanticsLabel('mais 1 jogo'), findsOneWidget);
  });

  testWidgets('até 3 saves seus: todos aparecem, sem "+N"', (tester) async {
    await pumpWidgetApp(
      tester,
      const Scaffold(
        body: HuntGames(
          versions: ['sword', 'shield', 'scarlet', 'violet'],
          owned: {'scarlet', 'violet'},
        ),
      ),
    );

    expect(find.byType(GameIcon), findsNWidgets(2));
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('nenhum save seu serve: sem ícones', (tester) async {
    await pumpWidgetApp(
      tester,
      const Scaffold(
        body: HuntGames(versions: ['scarlet', 'violet'], owned: {'sword'}),
      ),
    );

    expect(find.byType(GameIcon), findsNothing);
  });

  testWidgets('folha Jogo com muitos saves: busca, gerações e "2 saves"', (
    tester,
  ) async {
    final catalog = Catalog.fromJson(
      catalogJson(),
      spriteBase: Env.defaultSpritesBaseUrl,
    );
    final backend = FakeBackend.fromCatalog(catalog);
    final dexId = backend.addDex(name: 'Caça', isShinyDex: true);
    backend.addBox(dexId: dexId, name: 'Caça 1', formIds: catalog.defaultDex);
    Save save(int id, String version) => Save(
      id: id,
      trainer: Trainer(id: id, name: 'Ash', trainerId: '$id', version: version),
    );
    final versions = [
      'scarlet',
      'scarlet',
      'violet',
      'sword',
      'shield',
      'brilliant-diamond',
      'shining-pearl',
      'sun',
      'moon',
    ];
    await pumpFullApp(
      tester,
      size: compactSize,
      backend: backend,
      overrides: [
        savesProvider.overrideWith(
          (ref) async => [for (final (i, v) in versions.indexed) save(i, v)],
        ),
      ],
    );
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
        .read(routerProvider)
        .go(Routes.hunts(dexId: dexId));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Jogo'));
    await tester.pumpAndSettle();

    // Com 8 jogos ou mais, a busca; por geração, na ordem da série.
    expect(find.widgetWithText(TextField, 'Buscar jogo'), findsOneWidget);
    expect(find.text('2 saves'), findsOneWidget);
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('Geração VII'), lessThan(top('Geração VIII')));
    expect(top('Sun'), lessThan(top('Moon')));

    await tester.enterText(find.byType(TextField).last, 'sun');
    await tester.pumpAndSettle();
    expect(find.text('Sun'), findsOneWidget);
    expect(find.text('Moon'), findsNothing);
    expect(find.text('Todos os jogos'), findsNothing);
    await tester.enterText(find.byType(TextField).last, 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Nenhum jogo com esse nome.'), findsOneWidget);
  });
}
