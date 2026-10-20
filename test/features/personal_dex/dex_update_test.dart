import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/catalog_providers.dart';
import 'package:ishinydex/features/catalog/data/catalog_loader.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/dex_menu.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/dex_update.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/catalog_fixture.dart';
import '../../helpers/helpers.dart';
import '../../helpers/mocks.dart';

/// O padrão de antes: o do catálogo de teste (9 formas).
final _before = Catalog.fromJson(
  catalogJson(),
  spriteBase: Env.defaultSpritesBaseUrl,
);

/// O padrão de hoje: entra o Pichu "teal" (depois do Pichu) e sai o Mewtwo.
final _after = Catalog.fromJson({
  ...catalogJson(),
  'defaultDex': [1, 2, 3, 133, 134, 196, 172, 10500, 793],
}, spriteBase: Env.defaultSpritesBaseUrl);

/// Um dex criado com o padrão de antes, com espécimes no Mewtwo (que sai) e
/// no Pichu, já no catálogo de hoje. [maxBoxes] limita o HOME.
Future<({FakeBackend backend, int dexId, int mewtwo, int pichu})> _setUp({
  bool forceNewBox = false,
  int maxBoxes = 300,
  bool withRecipe = true,
}) async {
  final old = FakeBackend.local(_before);
  final dex = await old.createDex(
    name: 'Shiny',
    isShinyDex: false,
    forceNewBox: forceNewBox,
  );
  final slots = [
    for (final box in await old.fetchBoxes(dex.id))
      ...await old.fetchSlots(dexId: dex.id, boxId: box.id),
  ];
  Future<int> deposit(int formId) async {
    final specimen = await old.create(SpecimenDraft(form: formId));
    final slot = slots.firstWhere((s) => s.form?.id == formId);
    await old.deposit(slotId: slot.id, specimenId: specimen.id);
    return specimen.id;
  }

  final mewtwo = await deposit(150);
  final pichu = await deposit(172);
  final records = old.records;
  final backend = FakeBackend.local(
    _after,
    records: withRecipe
        ? records
        : {
            ...records,
            'dexes': [
              for (final d in records['dexes']!) {...d}..remove('recipe'),
            ],
          },
  )..maxBoxes = maxBoxes;
  return (backend: backend, dexId: dex.id, mewtwo: mewtwo, pichu: pichu);
}

Future<List<int?>> _forms(FakeBackend backend, int dexId) async => [
  for (final box in await backend.fetchBoxes(dexId))
    for (final slot in await backend.fetchSlots(dexId: dexId, boxId: box.id))
      slot.form?.id,
];

void main() {
  setUpAll(() => registerFallbackValue(DexUpdateMode.inOrder));

  group('FakeBackend (#308)', () {
    test('a prévia: o que entra, o que sai e o que cada jeito faz', () async {
      final s = await _setUp(withRecipe: false);
      final preview = (await s.backend.previewDexUpdate(s.dexId))!;
      expect([for (final f in preview.added) f.id], [10500]);
      expect([for (final f in preview.removed) f.id], [150]);
      expect(preview.signature, '+10500-150');
      // Dex de antes do #34: o padrão.
      expect(preview.recipe, const DexRecipe());
      expect((preview.boxesBefore, preview.boxesAfter), (1, 1));
      expect(preview.changedBoxes, ['HOME 1']);
      // Sem o Mewtwo, o Pichu sobe um slot; o Mewtwo sai do dex.
      expect(preview.movedSpecimens, 1);
      expect(preview.removedWithSpecimen, 1);
      expect(preview.atEndBoxes.single.forms, 1);
      expect(preview.atEndBoxes.single.isNew, isTrue);
      expect(preview.inOrderFits && preview.atEndFits, isTrue);

      // Mantendo o Mewtwo, ele não sai, e o Pichu "teal" empurra o Nihilego.
      final keeping = (await s.backend.previewDexUpdate(
        s.dexId,
        dropRemoved: false,
      ))!;
      expect(keeping.movedSpecimens, 0);
    });

    test('na ordem: o esquema de hoje, com os espécimes junto', () async {
      final s = await _setUp();
      final dex = await s.backend.applyDexUpdate(
        s.dexId,
        mode: DexUpdateMode.inOrder,
        dropRemoved: true,
      );
      expect((await _forms(s.backend, s.dexId)).whereType<int>(), [
        1, 2, 3, 133, 134, 196, 172, 10500, 793, //
      ]);
      expect(dex.recipe, const DexRecipe());
      // O Mewtwo voltou ao inventário, disponível; o Pichu, no slot dele.
      expect((await s.backend.fetchSpecimen(s.mewtwo)).isDeposited, isFalse);
      expect((await s.backend.fetchSpecimen(s.pichu)).isDeposited, isTrue);
      expect(await s.backend.previewDexUpdate(s.dexId), isNull);
    });

    test('na ordem, mantendo as que saíram: no lugar de antes', () async {
      final s = await _setUp();
      await s.backend.applyDexUpdate(
        s.dexId,
        mode: DexUpdateMode.inOrder,
        dropRemoved: false,
      );
      expect((await _forms(s.backend, s.dexId)).whereType<int>(), [
        1, 2, 3, 133, 134, 196, 150, 172, 10500, 793, //
      ]);
      expect((await s.backend.fetchSpecimen(s.mewtwo)).isDeposited, isTrue);
      // O Mewtwo ficou por escolha: o aviso não volta por ele.
      expect((await s.backend.fetchDex(s.dexId)).updateIgnored, '+-150');
    });

    test('na ordem com nova box por geração: as seções abrem boxes', () async {
      final s = await _setUp(forceNewBox: true);
      final preview = (await s.backend.previewDexUpdate(s.dexId))!;
      // Antes: I, II, I, II (4 boxes); hoje, sem o Mewtwo: I, II.
      expect((preview.boxesBefore, preview.boxesAfter), (4, 2));
      expect(preview.changedBoxes, ['HOME 2', 'HOME 3', 'HOME 4']);
      // O Pichu sobe da HOME 4 para a HOME 2.
      expect(preview.movedSpecimens, 1);
      final kept = (await s.backend.previewDexUpdate(
        s.dexId,
        dropRemoved: false,
      ))!;
      expect(kept.boxesAfter, 4);
      await s.backend.applyDexUpdate(
        s.dexId,
        mode: DexUpdateMode.inOrder,
        dropRemoved: true,
      );
      expect(await s.backend.fetchBoxes(s.dexId), hasLength(2));
      expect((await s.backend.fetchSpecimen(s.pichu)).isDeposited, isTrue);
    });

    test('no fim: nada do que existe muda; as novas numa box nova', () async {
      final s = await _setUp();
      final first = (await s.backend.fetchBoxes(s.dexId)).single;
      Future<List<int?>> inBox(BoxSummary box) async => [
        for (final slot in await s.backend.fetchSlots(
          dexId: s.dexId,
          boxId: box.id,
        ))
          slot.form?.id,
      ];
      final before = await inBox(first);
      await s.backend.applyDexUpdate(
        s.dexId,
        mode: DexUpdateMode.atEnd,
        dropRemoved: false,
      );
      final boxes = await s.backend.fetchBoxes(s.dexId);
      expect(boxes, hasLength(2));
      expect(await inBox(boxes.first), before);
      expect((await inBox(boxes.last)).whereType<int>(), [10500]);
      expect((await s.backend.fetchSpecimen(s.mewtwo)).isDeposited, isTrue);
    });

    test('no fim, tirando as que saíram: o slot fica vazio', () async {
      final s = await _setUp();
      await s.backend.applyDexUpdate(
        s.dexId,
        mode: DexUpdateMode.atEnd,
        dropRemoved: true,
      );
      final forms = await _forms(s.backend, s.dexId);
      expect(forms, isNot(contains(150)));
      expect(forms, contains(10500));
      expect((await s.backend.fetchSpecimen(s.mewtwo)).isDeposited, isFalse);
    });

    test('sem espaço no HOME: a prévia avisa e aplicar falha', () async {
      final s = await _setUp(maxBoxes: 1);
      final preview = (await s.backend.previewDexUpdate(s.dexId))!;
      expect(preview.atEndFits, isFalse);
      expect(
        () => s.backend.applyDexUpdate(
          s.dexId,
          mode: DexUpdateMode.atEnd,
          dropRemoved: true,
        ),
        throwsA(isA<ValidationFailure>()),
      );
      final tight = await _setUp(forceNewBox: true, maxBoxes: 4);
      final kept = (await tight.backend.previewDexUpdate(
        tight.dexId,
        dropRemoved: false,
      ))!;
      expect(kept.inOrderFits, isTrue);
      // Mantendo tudo e com o Pichu "teal", o II do fim passa de uma box?
      // Não: cabe; com 3 boxes no HOME, não.
      tight.backend.maxBoxes = 3;
      expect(
        () => tight.backend.applyDexUpdate(
          tight.dexId,
          mode: DexUpdateMode.inOrder,
          dropRemoved: false,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('dex por jogo, mantendo a que saiu: na pokédex dela', () async {
      const sv = DexRecipe(
        versionGroup: 'scarlet-violet',
        pokedexes: ['paldea', 'kitakami'],
      );
      final old = FakeBackend.local(_before);
      final dex = await old.createDex(
        name: 'Paldea',
        isShinyDex: false,
        forceNewBox: true,
        recipe: sv,
      );
      // Hoje, o Espeon sai do padrão.
      final now = FakeBackend.local(
        Catalog.fromJson({
          ...catalogJson(),
          'defaultDex': [1, 2, 3, 133, 134, 150, 172, 793],
        }, spriteBase: Env.defaultSpritesBaseUrl),
        records: old.records,
      );
      final kept = (await now.previewDexUpdate(dex.id, dropRemoved: false))!;
      expect([for (final f in kept.removed) f.id], [196]);
      // Paldea e Kitakami continuam em boxes separadas.
      expect(kept.boxesAfter, 2);
      await now.applyDexUpdate(
        dex.id,
        mode: DexUpdateMode.inOrder,
        dropRemoved: false,
      );
      expect((await _forms(now, dex.id)).whereType<int>(), [
        133,
        134,
        196,
        172,
      ]);
    });

    test('box nova no fim pula o nome já usado', () async {
      final s = await _setUp();
      // Uma box ocupada depois do dex, já com o nome da próxima.
      s.backend.addBox(dexId: 99, name: 'HOME 3', formIds: const [1]);
      final preview = (await s.backend.previewDexUpdate(s.dexId))!;
      expect(preview.atEndBoxes.single.name, 'HOME 4');
    });

    test('"Agora não" e "Não atualizar" ficam no dex e no arquivo', () async {
      final s = await _setUp();
      final later = await s.backend.snoozeDexUpdate(
        s.dexId,
        signature: '+10500-150',
        ignore: false,
      );
      expect((later.updateLater, later.updateIgnored), ('+10500-150', null));
      final ignored = await s.backend.snoozeDexUpdate(
        s.dexId,
        signature: '+10500-150',
        ignore: true,
      );
      expect(
        (ignored.updateLater, ignored.updateIgnored),
        (null, '+10500-150'),
      );
      final restored = FakeBackend.local(_after, records: s.backend.records);
      expect((await restored.fetchDex(s.dexId)).updateIgnored, '+10500-150');
      // Atualizar limpa as decisões.
      final updated = await s.backend.applyDexUpdate(
        s.dexId,
        mode: DexUpdateMode.atEnd,
        dropRemoved: true,
      );
      expect(updated.updateIgnored, isNull);
    });

    test('sem mudança, sem catálogo ou dex que não existe', () async {
      final backend = FakeBackend.local(_after);
      final dex = await backend.createDex(
        name: 'Hoje',
        isShinyDex: false,
        forceNewBox: false,
      );
      expect(await backend.previewDexUpdate(dex.id), isNull);
      expect(
        (await backend.applyDexUpdate(
          dex.id,
          mode: DexUpdateMode.inOrder,
          dropRemoved: true,
        )).total,
        9,
      );
      final seeded = FakeBackend.seeded();
      final first = (await seeded.fetchDexes()).first;
      expect(await seeded.previewDexUpdate(first.id), isNull);
      expect(
        () => backend.previewDexUpdate(999),
        throwsA(isA<NotFoundFailure>()),
      );
      expect(
        () => backend.snoozeDexUpdate(999, signature: '', ignore: true),
        throwsA(isA<NotFoundFailure>()),
      );
    });
  });

  group('aviso, menu e folha', () {
    Future<FakeBackend> pump(WidgetTester tester, {int maxBoxes = 300}) async {
      final s = await _setUp(maxBoxes: maxBoxes);
      await pumpWidgetApp(
        tester,
        Consumer(
          builder: (context, ref, _) {
            final dex = ref.watch(dexProvider(s.dexId)).value;
            if (dex == null) return const SizedBox.shrink();
            return Scaffold(
              appBar: AppBar(
                actions: [
                  DexMenu(
                    dex: dex,
                    onShowProgress: () {},
                    onAutoDeposit: () {},
                  ),
                ],
              ),
              body: Column(children: [DexUpdateBanner(dex: dex)]),
            );
          },
        ),
        size: const Size(400, 900),
        overrides: [
          personalDexRepositoryProvider.overrideWithValue(s.backend),
          specimenRepositoryProvider.overrideWithValue(s.backend),
          catalogLoadProvider.overrideWithValue(
            CatalogLoad(catalog: _after, elapsed: Duration.zero),
          ),
        ],
      );
      await tester.pumpAndSettle();
      return s.backend;
    }

    Future<void> tapIn(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Mais opções'));
      await tester.pumpAndSettle();
    }

    testWidgets('"Agora não" leva o aviso para o menu; atualizar no fim', (
      tester,
    ) async {
      final backend = await pump(tester);
      expect(find.text('O padrão mudou'), findsOneWidget);
      expect(
        find.text(
          'Desde que este dex foi criado, entrou 1 forma e saiu 1 forma. '
          'Nada muda até você atualizar.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Agora não'));
      await tester.pumpAndSettle();
      expect(find.text('O padrão mudou'), findsNothing);

      await openMenu(tester);
      await tester.tap(find.text('Atualizar o dex (+1 −1)'));
      await tester.pumpAndSettle();
      expect(find.text('Atualizar “Shiny”'), findsOneWidget);
      expect(
        find.text('Criado como Nacional · Living Form Lite · o padrão'),
        findsOneWidget,
      );
      expect(find.text('+1 forma'), findsOneWidget);
      expect(find.text('−1 forma'), findsOneWidget);
      expect(find.textContaining('Pichu'), findsOneWidget);
      expect(find.text('Mewtwo'), findsOneWidget);
      expect(
        find.textContaining('O espécime de 1 delas volta ao inventário'),
        findsOneWidget,
      );
      expect(
        find.text('Muda no HOME: HOME 1. O dex passa de 1 para 1 boxes.'),
        findsOneWidget,
      );

      // Manter as que saíram recarrega a prévia.
      await tapIn(tester, find.text('Tirar do dex as formas que saíram'));
      await tapIn(tester, find.byKey(const ValueKey('dex-update-atEnd')));
      expect(
        find.text('Nada do que existe muda de lugar: HOME 2 (1).'),
        findsOneWidget,
      );
      await tapIn(tester, find.text('Acrescentar no fim'));
      expect(find.text('Dex atualizado.'), findsOneWidget);
      // O Mewtwo ficou por escolha: a mudança que sobra não avisa mais.
      expect((await backend.fetchDexes()).first.updateIgnored, '+-150');
      await openMenu(tester);
      expect(find.textContaining('Atualizar o dex'), findsNothing);
    });

    testWidgets('"Não atualizar" tira o aviso e o menu', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Ver e atualizar'));
      await tester.pumpAndSettle();
      await tapIn(tester, find.byKey(const ValueKey('dex-update-skip')));
      await tapIn(tester, find.text('Manter como está'));
      expect(find.text('O padrão mudou'), findsNothing);
      expect(find.text('Dex atualizado.'), findsNothing);
      await openMenu(tester);
      expect(find.textContaining('Atualizar o dex'), findsNothing);
    });

    testWidgets('na ordem: atualiza; sem espaço, não deixa', (tester) async {
      await pump(tester, maxBoxes: 1);
      await tester.tap(find.text('Ver e atualizar'));
      await tester.pumpAndSettle();
      // Na ordem cabe (a mesma box); no fim, não.
      await tapIn(tester, find.byKey(const ValueKey('dex-update-atEnd')));
      expect(
        find.text('Não há boxes suficientes no HOME para isso.'),
        findsOneWidget,
      );
      FilledButton button() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Acrescentar no fim'),
      );
      expect(button().onPressed, isNull);
      await tapIn(tester, find.byKey(const ValueKey('dex-update-inOrder')));
      await tapIn(tester, find.text('Atualizar na ordem'));
      expect(find.text('Dex atualizado.'), findsOneWidget);
    });

    testWidgets('falhas: adiar e atualizar mostram a mensagem', (tester) async {
      final repository = MockPersonalDexRepository();
      const dex = PersonalDex(id: 7, name: 'Shiny', total: 9, registered: 2);
      const preview = DexUpdatePreview(
        added: [],
        removed: [
          FormRef(
            id: 150,
            name: 'mewtwo',
            pokeapiId: 150,
            spriteUrl: 'x',
            shinySpriteUrl: 'x',
          ),
        ],
        signature: '+-150',
        recipe: DexRecipe(
          versionGroup: 'scarlet-violet',
          pokedexes: ['paldea'],
        ),
        boxesBefore: 1,
        boxesAfter: 1,
        changedBoxes: [],
        movedSpecimens: 2,
        inOrderFits: true,
        atEndBoxes: [],
        atEndFits: true,
      );
      when(
        () => repository.previewDexUpdate(
          7,
          dropRemoved: any(named: 'dropRemoved'),
        ),
      ).thenAnswer((_) async => preview);
      when(
        () => repository.snoozeDexUpdate(
          7,
          signature: any(named: 'signature'),
          ignore: any(named: 'ignore'),
        ),
      ).thenThrow(const NotFoundFailure());
      when(
        () => repository.applyDexUpdate(
          7,
          mode: any(named: 'mode'),
          dropRemoved: any(named: 'dropRemoved'),
        ),
      ).thenThrow(const NotFoundFailure());
      await pumpWidgetApp(
        tester,
        const Scaffold(
          body: Column(children: [DexUpdateBanner(dex: dex)]),
        ),
        overrides: [
          personalDexRepositoryProvider.overrideWithValue(repository),
          catalogLoadProvider.overrideWithValue(
            CatalogLoad(catalog: _after, elapsed: Duration.zero),
          ),
        ],
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Desde que este dex foi criado, saiu 1 forma. '
          'Nada muda até você atualizar.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Agora não'));
      await tester.pumpAndSettle();
      expect(find.text('Não encontrado.'), findsOneWidget);

      await tester.tap(find.text('Ver e atualizar'));
      await tester.pumpAndSettle();
      expect(
        find.text('Criado como Scarlet / Violet · Living Form Lite · o padrão'),
        findsOneWidget,
      );
      expect(find.text('2 espécimes mudam de lugar.'), findsOneWidget);
      expect(
        find.text('Nenhuma forma nova; só saem as que saíram.'),
        findsOneWidget,
      );
      await tapIn(tester, find.text('Atualizar na ordem'));
      expect(find.text('Não encontrado.'), findsOneWidget);
      expect(find.text('Atualizar “Shiny”'), findsOneWidget);
    });

    for (final locale in [portuguese, const Locale('en')]) {
      testWidgets(
        'pior caso: 320 px e texto em 130% (${locale.languageCode})',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final s = await _setUp(forceNewBox: true);
          await pumpWidgetApp(
            tester,
            Consumer(
              builder: (context, ref, _) {
                final dex = ref.watch(dexProvider(s.dexId)).value;
                if (dex == null) return const SizedBox.shrink();
                return Scaffold(
                  body: ListView(
                    children: [
                      DexUpdateBanner(dex: dex),
                      DexUpdateSheet(dex: dex),
                    ],
                  ),
                );
              },
            ),
            size: const Size(320, 3000),
            locale: locale,
            overrides: [
              personalDexRepositoryProvider.overrideWithValue(s.backend),
              catalogLoadProvider.overrideWithValue(
                CatalogLoad(catalog: _after, elapsed: Duration.zero),
              ),
            ],
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const ValueKey('dex-update-atEnd')),
            findsOneWidget,
          );
        },
      );
    }

    testWidgets('a lista longa de formas termina em "e mais"', (tester) async {
      final repository = MockPersonalDexRepository();
      const dex = PersonalDex(id: 7, name: 'Shiny', total: 9, registered: 2);
      final preview = DexUpdatePreview(
        added: [
          for (var i = 0; i < 15; i++)
            FormRef(
              id: i,
              name: 'alcremie-$i',
              pokeapiId: 869,
              spriteUrl: 'x',
              shinySpriteUrl: 'x',
            ),
        ],
        removed: const [],
        signature: '+',
        recipe: const DexRecipe(),
        boxesBefore: 45,
        boxesAfter: 47,
        changedBoxes: const ['HOME 39', 'HOME 47'],
        movedSpecimens: 1,
        inOrderFits: true,
        atEndBoxes: const [DexUpdateBox(name: 'HOME 46', forms: 15)],
        atEndFits: true,
      );
      when(
        () => repository.previewDexUpdate(
          7,
          dropRemoved: any(named: 'dropRemoved'),
        ),
      ).thenAnswer((_) async => preview);
      await pumpWidgetApp(
        tester,
        const Scaffold(body: DexUpdateSheet(dex: dex)),
        size: const Size(400, 1400),
        overrides: [
          personalDexRepositoryProvider.overrideWithValue(repository),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('e mais 3'), findsOneWidget);
      expect(find.text('1 espécime muda de lugar.'), findsOneWidget);
      expect(
        find.text(
          'Muda no HOME: da HOME 39 à HOME 47. O dex passa de 45 para 47 boxes.',
        ),
        findsOneWidget,
      );
      // Sem catálogo, a base é o Nacional.
      expect(
        find.text('Criado como Nacional · Living Form Lite · o padrão'),
        findsOneWidget,
      );
    });
  });
}
