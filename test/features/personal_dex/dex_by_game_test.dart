import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/catalog_providers.dart';
import 'package:ishinydex/features/catalog/data/catalog_loader.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/new_dex_page.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/dex_recipe_picker.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

import '../../fixtures/catalog_fixture.dart';
import '../../helpers/helpers.dart';

/// O catálogo de teste com regionais e alternativas no padrão (como no
/// `dex_recipe_test`) e, no Scarlet/Violet, uma ilha (já toda na de
/// Paldea) e uma lista extra misturada (com e sem número), para a ordem.
Map<String, dynamic> _json() {
  final json = catalogJson();
  return {
    ...json,
    'defaultDex': [1, 2, 3, 133, 134, 10600, 196, 150, 172, 10500, 793],
    'formEvolutions': {
      'evolutions': [
        [133, 134],
        [133, 196],
      ],
      'withoutEvolution': [10600],
    },
    'pokedexes': [
      ...json['pokedexes'] as List,
      {
        'name': 'paldea-island',
        'label': 'Ilha',
        'labels': {'en': 'Island', 'pt-BR': 'Ilha'},
        'versionGroups': ['scarlet-violet'],
        'dlc': null,
        'entries': [
          ['espeon', 3],
          ['eevee', 1],
        ],
      },
      {
        'name': 'sv-other',
        'label': 'Outros encontros',
        'versionGroups': ['scarlet-violet'],
        'dlc': null,
        'entries': [
          ['nihilego', null],
          ['mewtwo', null],
          ['bulbasaur', null],
        ],
      },
    ],
  };
}

Catalog _catalog() =>
    Catalog.fromJson(_json(), spriteBase: Env.defaultSpritesBaseUrl);

void main() {
  final catalog = _catalog();

  group('Catalog: o dex por jogo (#34)', () {
    test('os jogos com pokédex, as versões e o grupo da versão', () {
      expect(catalog.dexGames, [
        'sword-shield',
        'brilliant-diamond-shining-pearl',
        'scarlet-violet',
      ]);
      expect(catalog.gameVersions('scarlet-violet'), ['scarlet', 'violet']);
      expect(catalog.gameVersions('nenhum'), isEmpty);
      expect(catalog.groupOf('shield'), 'sword-shield');
      // Paldea (3) + Kitakami (1) + a lista extra (Bulbasaur, Mewtwo e
      // Nihilego; o Espeon já está em Paldea).
      expect(catalog.gameSpecies('scarlet-violet'), 7);
    });

    test('as pokédex do jogo: principal e DLC marcadas; ilha e extra não', () {
      final choices = {
        for (final c in catalog.gamePokedexes('scarlet-violet')) c.name: c,
      };
      expect(choices['paldea']!.selectedByDefault, isTrue);
      expect(choices['kitakami']!.selectedByDefault, isTrue);
      expect(choices['kitakami']!.dlc, 'the-teal-mask');
      expect(choices['paldea-island']!.selectedByDefault, isFalse);
      expect(choices['paldea-island']!.coveredBy, 'Paldea');
      expect(choices['sv-other']!.extra, isTrue);
      expect(choices['sv-other']!.selectedByDefault, isFalse);
      expect(choices['sv-other']!.species, 3);
    });

    test('as seções: uma por pokédex, com as formas do jogo', () {
      const sv = DexRecipe(
        versionGroup: 'scarlet-violet',
        pokedexes: ['paldea', 'kitakami'],
      );
      // O Vaporeon de Galar não está no Scarlet/Violet (gameForms).
      expect(catalog.dexSections(sv), [
        [133, 134, 196],
        [172, 10500],
      ]);
      // A espécie que já entrou numa pokédex anterior não se repete, e a
      // pokédex sem espécie nova não vira seção.
      expect(
        catalog.dexSections(
          sv.copyWith(pokedexes: ['paldea', 'paldea-island', 'kitakami']),
        ),
        [
          [133, 134, 196],
          [172, 10500],
        ],
      );
      // Sem as pré-evoluções, sai o Eevee; sem as alternativas, o Pichu
      // "teal".
      expect(
        catalog.dexForms(
          sv.copyWith(preEvolutions: false, alternateForms: false),
        ),
        [134, 196, 172],
      );
    });

    test('no Sword/Shield, a regional fica mesmo sem as alternativas', () {
      const swsh = DexRecipe(
        versionGroup: 'sword-shield',
        pokedexes: ['galar', 'dynamax-adventure'],
        alternateForms: false,
      );
      expect(catalog.dexSections(swsh), [
        [133, 134, 10600],
        [150],
      ]);
    });

    test('o nome do jogo pelas versões; sem versões, pelo grupo', () {
      expect(gameLabel(catalog, 'sword-shield'), 'Sword / Shield');
      expect(gameLabel(catalog, 'the-teal-mask'), 'The Teal Mask');
    });

    test('a lista extra, na ordem dela', () {
      expect(
        catalog.dexForms(
          const DexRecipe(
            versionGroup: 'scarlet-violet',
            pokedexes: ['sv-other'],
          ),
        ),
        [793, 150, 1],
      );
    });

    test('pokédex misturada: as numeradas antes, pelo número', () {
      final json = _json();
      final mixed = Catalog.fromJson({
        ...json,
        'pokedexes': [
          {
            'name': 'mixed',
            'label': 'Mista',
            'versionGroups': ['scarlet-violet'],
            'dlc': null,
            'entries': [
              ['nihilego', null],
              ['espeon', 3],
              ['mewtwo', null],
              ['bulbasaur', 1],
              ['eevee', 3],
            ],
          },
        ],
      }, spriteBase: Env.defaultSpritesBaseUrl);
      expect(
        mixed.dexForms(
          const DexRecipe(
            versionGroup: 'scarlet-violet',
            pokedexes: ['mixed'],
            alternateForms: false,
          ),
        ),
        [1, 196, 133, 793, 150],
      );
    });
  });

  test('FakeBackend: nova box por pokédex', () async {
    final backend = FakeBackend.local(catalog);
    const sv = DexRecipe(
      versionGroup: 'scarlet-violet',
      pokedexes: ['paldea', 'kitakami'],
    );
    expect(
      (await backend.previewNewDex(recipe: sv, forceNewBox: false)).boxesNeeded,
      1,
    );
    final preview = await backend.previewNewDex(recipe: sv, forceNewBox: true);
    expect((preview.forms, preview.boxesNeeded), (5, 2));
    final dex = await backend.createDex(
      name: 'Paldea',
      isShinyDex: false,
      forceNewBox: true,
      recipe: sv,
    );
    final boxes = await backend.fetchBoxes(dex.id);
    final kitakami = await backend.fetchSlots(
      dexId: dex.id,
      boxId: boxes[1].id,
    );
    expect([for (final s in kitakami) s.form?.id].whereType<int>(), [
      172,
      10500,
    ]);
    expect((await backend.fetchDex(dex.id)).recipe, sv);
  });

  group('NewDexPage, por jogo', () {
    Future<FakeBackend> pump(
      WidgetTester tester, {
      Size size = const Size(600, 2400),
      String? saveVersion = 'shield',
    }) async {
      final backend = FakeBackend.local(catalog);
      if (saveVersion != null) {
        final trainer = await backend.createTrainer(
          name: 'Victor',
          trainerId: '123456',
          version: saveVersion,
        );
        await backend.createSave(trainerId: trainer.id, label: 'Switch');
      }
      await pumpWidgetApp(
        tester,
        const NewDexPage(),
        size: size,
        overrides: [
          personalDexRepositoryProvider.overrideWithValue(backend),
          specimenRepositoryProvider.overrideWithValue(backend),
          catalogLoadProvider.overrideWithValue(
            CatalogLoad(catalog: catalog, elapsed: Duration.zero),
          ),
        ],
      );
      await tester.pumpAndSettle();
      return backend;
    }

    bool checked(WidgetTester tester, String name) => tester
        .widget<CheckboxListTile>(find.byKey(ValueKey('dex-pokedex-$name')))
        .value!;

    testWidgets('escolhe o jogo dos saves, as pokédex e cria o dex', (
      tester,
    ) async {
      final backend = await pump(tester);
      expect(
        find.text('Ordem nacional, geração após geração.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Por jogo'));
      await tester.pumpAndSettle();

      // O jogo do save (Shield) já vem escolhido, com a principal marcada e
      // a lista extra não.
      expect(find.text('Sword / Shield'), findsOneWidget);
      expect(checked(tester, 'galar'), isTrue);
      expect(checked(tester, 'dynamax-adventure'), isFalse);
      expect(find.text('Pokédex principal'), findsOneWidget);
      expect(find.text('Lista extra, sem número'), findsOneWidget);
      // Sem a chave das regionais, com a explicação no lugar.
      expect(find.text('Formas regionais'), findsNothing);
      expect(
        find.textContaining('formas que existem neste jogo'),
        findsOneWidget,
      );
      expect(find.text('Nova box por pokédex'), findsOneWidget);
      expect(find.text('Ordem regional: Galar.'), findsOneWidget);

      // Os jogos: os dos saves primeiro.
      await tester.tap(find.text('Sword / Shield'));
      await tester.pumpAndSettle();
      expect(find.text('Seus saves'), findsOneWidget);
      expect(find.text('Outros jogos'), findsOneWidget);
      expect(find.text('1 save · 3 espécies'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Seus saves')).dy,
        lessThan(tester.getTopLeft(find.text('Outros jogos')).dy),
      );
      await tester.tap(find.byKey(const ValueKey('dex-game-scarlet-violet')));
      await tester.pumpAndSettle();
      expect(find.text('Scarlet / Violet'), findsOneWidget);
      expect(checked(tester, 'paldea'), isTrue);
      expect(checked(tester, 'kitakami'), isTrue);
      expect(checked(tester, 'paldea-island'), isFalse);
      expect(find.text('Já está na de Paldea'), findsOneWidget);
      expect(find.text('DLC The Teal Mask'), findsOneWidget);
      expect(
        find.text('Ordem regional: Paldea, depois Kitakami.'),
        findsOneWidget,
      );
      expect(
        find.text(
          '5 formas em 1 boxes, a partir da HOME 1 (cria 1 box nova no fim).',
        ),
        findsNothing,
      );

      // Marcar fora da ordem mantém a ordem do jogo.
      await tester.tap(find.byKey(const ValueKey('dex-pokedex-sv-other')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dex-pokedex-kitakami')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dex-pokedex-kitakami')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Ordem regional: Paldea, depois Kitakami, depois Outros encontros.',
        ),
        findsOneWidget,
      );

      // Um atalho no dex por jogo continua no jogo.
      await tester.tap(find.text('Final Form'));
      await tester.pumpAndSettle();
      expect(find.text('Scarlet / Violet'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Paldea');
      await tester.tap(find.text('Criar PersonalDex'));
      await tester.pumpAndSettle();
      final dex = (await backend.fetchDexes()).single;
      expect(
        dex.recipe,
        DexRecipe.of(DexPreset.finalForm).copyWith(
          versionGroup: 'scarlet-violet',
          pokedexes: ['paldea', 'kitakami', 'sv-other'],
        ),
      );
    });

    testWidgets('sem pokédex marcada não deixa criar; voltar ao Nacional', (
      tester,
    ) async {
      await pump(tester, saveVersion: null);
      await tester.tap(find.text('Por jogo'));
      await tester.pumpAndSettle();
      // Sem saves, o jogo mais recente do HOME, e o menu sem "Seus saves".
      expect(find.text('Scarlet / Violet'), findsOneWidget);
      await tester.tap(find.text('Scarlet / Violet'));
      await tester.pumpAndSettle();
      expect(find.text('Seus saves'), findsNothing);
      expect(find.text('Outros jogos'), findsNothing);
      expect(find.text('3 espécies'), findsOneWidget);
      // Fecha o menu tocando de novo no campo.
      await tester.tap(find.byType(InputDecorator).first);
      await tester.pumpAndSettle();

      expect(find.byType(MenuItemButton), findsNothing);
      await tester.tap(find.byKey(const ValueKey('dex-pokedex-paldea')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dex-pokedex-kitakami')));
      await tester.pumpAndSettle();
      expect(checked(tester, 'paldea'), isFalse);
      expect(checked(tester, 'kitakami'), isFalse);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Criar PersonalDex'),
      );
      expect(button.onPressed, isNull);

      await tester.tap(find.text('Nacional'));
      await tester.pumpAndSettle();
      expect(find.text('Formas regionais'), findsOneWidget);
      expect(find.text('Nova box a cada geração'), findsOneWidget);
      expect(find.byKey(const ValueKey('dex-pokedex-paldea')), findsNothing);
    });

    for (final (locale, byGame) in [
      (portuguese, 'Por jogo'),
      (const Locale('en'), 'By game'),
    ]) {
      testWidgets(
        'pior caso: 320 px e texto em 130% (${locale.languageCode})',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final backend = FakeBackend.local(catalog);
          await pumpWidgetApp(
            tester,
            const NewDexPage(),
            size: const Size(320, 3000),
            locale: locale,
            overrides: [
              personalDexRepositoryProvider.overrideWithValue(backend),
              specimenRepositoryProvider.overrideWithValue(backend),
              catalogLoadProvider.overrideWithValue(
                CatalogLoad(catalog: catalog, elapsed: Duration.zero),
              ),
            ],
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(byGame));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(find.byType(InputDecorator).first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final item in find.byType(MenuItemButton).evaluate()) {
            final rect = tester.getRect(find.byWidget(item.widget));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(320));
          }
        },
      );
    }
  });
}
