import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/utils/origin_mark.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/shiny_locks/domain/models.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

import '../fixtures/catalog_fixture.dart';

void main() {
  final catalog = Catalog.fromJson(
    catalogJson(),
    spriteBase: Env.defaultSpritesBaseUrl,
  );

  test('aparelho novo: vazio, com os shiny locks padrão', () async {
    final backend = FakeBackend.local(catalog);
    expect(await backend.fetchDexes(), isEmpty);
    expect(await backend.fetchTrainers(), isEmpty);
    expect(
      (await backend.fetchShinyLocks()).single.caption,
      'Mewtwo de evento',
    );
  });

  test('locks padrão: o mesmo id em todo aparelho (#357)', () async {
    final one = await FakeBackend.local(catalog).fetchShinyLocks();
    final two = await FakeBackend.local(catalog).fetchShinyLocks();
    expect([for (final l in one) l.id], [for (final l in two) l.id]);
    expect(one.single.id, FakeBackend.catalogLockId('Mewtwo de evento'));
  });

  test('catalogLockId: fixo, positivo e exato no JS', () {
    // O id não pode mudar entre versões: aparelhos com o app antigo e o
    // novo precisam chegar ao mesmo número.
    expect(FakeBackend.catalogLockId('Calyrex'), 3205413972734430);
    for (final caption in ['', 'a', 'Calyrex', 'Cosmog-Cosmoem' * 20]) {
      final id = FakeBackend.catalogLockId(caption);
      expect(id, inInclusiveRange(1, 9007199254740991));
    }
    expect(
      FakeBackend.catalogLockId('Calyrex'),
      isNot(FakeBackend.catalogLockId('Calyrex Ice')),
    );
  });

  test(
    'dex novo do zero: cria as boxes, com o dex padrão do catálogo',
    () async {
      final backend = FakeBackend.local(catalog);
      final preview = await backend.previewNewDex(
        recipe: const DexRecipe(),
        forceNewBox: false,
      );
      expect((preview.forms, preview.boxesToCreate), (9, 1));
      // Box nova por geração (no fixture: I, II, I, II).
      expect(
        (await backend.previewNewDex(
          recipe: const DexRecipe(),
          forceNewBox: true,
        )).boxesNeeded,
        4,
      );

      final dex = await backend.createDex(
        name: 'Shiny',
        isShinyDex: true,
        forceNewBox: false,
      );
      final box = (await backend.fetchBoxes(dex.id)).single;
      final slots = await backend.fetchSlots(dexId: dex.id, boxId: box.id);
      expect(
        [for (final s in slots) s.form?.id].whereType<int>(),
        catalog.defaultDex,
      );
      // Ids aleatórios: nada de 1, 2, 3...
      final ids = {dex.id, box.id, for (final s in slots) s.id};
      expect(ids, hasLength(slots.length + 2));
      expect(ids.contains(1) && ids.contains(2), false);
    },
  );

  test('registros: ida e volta sem perder nada', () async {
    final backend = FakeBackend.local(catalog);
    final dex = await backend.createDex(
      name: 'Shiny',
      isShinyDex: true,
      forceNewBox: true,
    );
    final trainer = await backend.createTrainer(
      name: 'Ash',
      trainerId: '123456',
      version: 'scarlet',
    );
    final save = await backend.createSave(
      trainerId: trainer.id,
      label: 'Switch',
    );
    final specimen = await backend.create(
      SpecimenDraft(
        form: 1,
        nickname: 'Saur',
        isShiny: true,
        nature: 'modest',
        pokeball: 'poke-ball',
        capturedAt: DateTime(2026, 9, 2),
        ot: trainer.id,
        observation: 'Safári',
      ),
    );
    final slot = (await backend.fetchSlotsByForms(
      dexId: dex.id,
      formIds: [1],
    )).single;
    await backend.deposit(slotId: slot.id, specimenId: specimen.id);
    await backend.transfer([specimen.id], saveId: save.id);
    await backend.createShinyLock(
      ShinyLockDraft(caption: 'Pichu', forms: [catalog.formRef(172)]),
    );
    await backend.updateDex(dex.id, name: 'Shiny Dex', isShinyDex: true);

    final restored = FakeBackend.local(catalog, records: backend.records);

    expect(restored.records, backend.records);
    expect(await restored.fetchDexes(), await backend.fetchDexes());
    final again = await restored.fetchSpecimen(specimen.id);
    expect(again, await backend.fetchSpecimen(specimen.id));
    expect(
      (again.originMark, again.slot, again.location?.label),
      ('paldea', slot.id, 'Switch'),
    );
    expect(
      (await restored.fetchShinyLocks()).map((l) => l.caption),
      containsAll(['Mewtwo de evento', 'Pichu']),
    );
  });

  test('formas fora do catálogo: somem da tela, mas voltam nos registros', () {
    final records = {
      'boxes': [
        {'id': 10, 'name': 'HOME 1', 'position': 1},
      ],
      'specimens': [
        {
          'id': 20,
          'form': 99999,
          'nickname': null,
          'ability': null,
          'language': null,
          'gender': null,
          'nature': null,
          'isAlpha': false,
          'isShiny': true,
          'isFromGo': false,
          'capturedAt': null,
          'pokeball': null,
          'observation': null,
          'ot': null,
          'location': null,
          'locationSince': null,
        },
      ],
      'slots': [
        {
          'id': 30,
          'box': 10,
          'row': 0,
          'col': 0,
          'dex': null,
          'form': 99999,
          'specimen': 20,
        },
      ],
      'shinyLocks': [
        {
          'id': 40,
          'caption': 'Fakemon',
          'description': null,
          'lockType': 'unobtainable',
          'active': true,
          'forms': [99999],
        },
      ],
    };
    final backend = FakeBackend.local(catalog, records: records);

    expect(backend.records['specimens'], records['specimens']);
    expect(backend.records['slots'], records['slots']);
    expect(backend.records['shinyLocks'], records['shinyLocks']);
  });

  test(
    'sem ids aleatórios: o próximo é o maior + 1, mesmo após excluir',
    () async {
      final backend = FakeBackend()
        ..addDex(name: 'A')
        ..addDex(name: 'B');
      await backend.deleteDex(1);
      expect(backend.addDex(name: 'C'), 3);
    },
  );

  group('GO como jogo (#360)', () {
    Map<String, dynamic> trainer(int id, String? version) => {
      'id': id,
      'name': 'Victor',
      'trainerId': '993505',
      'version': version,
    };
    Map<String, dynamic> specimen(int id, int? ot, {bool go = true}) => {
      'id': id,
      'ot': ot,
      'isFromGo': go,
    };

    test('migra o "veio do GO" de antes para o GO como jogo', () {
      final records = {
        'trainers': [
          trainer(10, null), // só GO: vira do GO
          trainer(11, null), // GO e um presente do HOME: ganha um gêmeo
          trainer(1, 'lets-go-pikachu'), // GO Park
          trainer(2, 'scarlet'),
          trainer(3, goVersion), // já é do GO
        ],
        'specimens': [
          specimen(100, 10),
          specimen(101, 11),
          specimen(102, 11, go: false), // a Magearna
          specimen(103, 1),
          specimen(104, 2),
          specimen(105, null),
          specimen(106, 3),
          specimen(107, 2, go: false),
        ],
      };
      final migrated = migrateGoRecords(records);
      final trainers = {for (final t in migrated['trainers']!) t['id']: t};
      final specimens = {for (final s in migrated['specimens']!) s['id']: s};
      final twin = FakeBackend.stableId('go-twin:11');

      expect(trainers[10]!['version'], goVersion);
      expect(trainers[11]!['version'], isNull);
      expect(trainers[twin], {
        'id': twin,
        'name': 'Victor',
        'trainerId': '993505',
        'version': goVersion,
      });
      expect(specimens[100]!['ot'], 10);
      expect(specimens[101]!['ot'], twin);
      expect(specimens[102]!['ot'], 11);
      for (final id in [103, 104, 105]) {
        expect(specimens[id]!['markChoice'], 'go', reason: '$id');
      }
      expect(specimens[106]!['markChoice'], isNull);
      expect(specimens[107]!.containsKey('markChoice'), isFalse);
      // O original não muda (a migração trabalha numa cópia).
      expect(records['trainers']!.first['version'], isNull);

      // De novo: nada a fazer, o mesmo resultado.
      expect(migrateGoRecords(migrated), same(migrated));
      // Em outro aparelho, o mesmo gêmeo.
      expect({
        for (final t in migrateGoRecords(records)['trainers']!) t['id'],
      }, trainers.keys.toSet());
    });

    test('a marca: a do jogo do OT, a escolhida sem jogo, o GO Park', () async {
      final backend = FakeBackend.local(catalog);
      final scarlet = (await backend.createTrainer(
        name: 'Ash',
        trainerId: '1',
        version: 'scarlet',
      )).id;
      final noGame = (await backend.createTrainer(
        name: 'HOME',
        trainerId: '2',
      )).id;
      Future<Specimen> make(int? ot, String? choice) => backend.create(
        SpecimenDraft(form: 1, ability: '', ot: ot, markChoice: choice),
      );
      final fromGame = await make(scarlet, 'hisui');
      expect((fromGame.originMark, fromGame.isFromGo), ('paldea', false));
      final gift = await make(noGame, 'hisui');
      expect((gift.originMark, gift.markChoice), ('hisui', 'hisui'));
      final none = await make(noGame, null);
      expect(none.originMark, isNull);
      final go = await make(scarlet, 'go');
      expect((go.originMark, go.isFromGo), ('go', true));
    });

    test('OT do GO dá a marca do GO, com ou sem catálogo', () async {
      expect(catalog.originMarkOf(goVersion), 'go');
      for (final backend in [
        FakeBackend.local(catalog),
        FakeBackend.seeded(),
      ]) {
        final ot = (await backend.createTrainer(
          name: 'Victor',
          trainerId: '993505',
          version: goVersion,
        )).id;
        final specimen = await backend.create(
          SpecimenDraft(form: 1, ability: '', ot: ot),
        );
        expect((specimen.originMark, specimen.isFromGo), ('go', true));
      }
    });
  });

  group('alfa pela marca de origem (#362)', () {
    // O fixture com o Legends: Arceus, em que o Bulbasaur (1) pode ser alfa.
    final json = catalogJson();
    json['versionGroups'] = [
      ...json['versionGroups'] as List,
      {
        'name': 'legends-arceus',
        'generation': 'generation-viii',
        'order': 30,
        'versions': ['legends-arceus'],
        'originMark': 'hisui',
      },
    ];
    json['versions'] = [
      ...json['versions'] as List,
      {
        'name': 'legends-arceus',
        'versionGroup': 'legends-arceus',
        'receivesFromHome': true,
      },
    ];
    json['alphaForms'] = [
      {
        'versionGroup': 'legends-arceus',
        'forms': [1],
      },
    ];
    final withAlphas = Catalog.fromJson(
      json,
      spriteBase: Env.defaultSpritesBaseUrl,
    );

    test('Catalog.canBeAlpha: a marca do jogo e a forma', () {
      expect(withAlphas.canBeAlpha(1, 'hisui'), isTrue);
      expect(withAlphas.canBeAlpha(1, 'paldea'), isFalse);
      expect(withAlphas.canBeAlpha(2, 'hisui'), isFalse);
      expect(withAlphas.canBeAlpha(1, null), isFalse);
    });

    test('criar, editar e o lote', () async {
      final backend = FakeBackend.local(withAlphas);
      Future<int> trainer(String version) async => (await backend.createTrainer(
        name: 'Ash',
        trainerId: version,
        version: version,
      )).id;
      final pla = await trainer('legends-arceus');
      final scarlet = await trainer('scarlet');
      final alpha = await backend.create(
        SpecimenDraft(form: 1, ability: '', ot: pla, isAlpha: true),
      );
      expect((alpha.isAlpha, alpha.originMark), (true, 'hisui'));
      expect(
        backend.create(
          SpecimenDraft(form: 1, ability: '', ot: scarlet, isAlpha: true),
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.errorsFor('is_alpha'),
            'is_alpha',
            [const Problem.alphaNotAllowed()],
          ),
        ),
      );
      // Trocar o OT de um alfa para um jogo sem alfa: recusado.
      expect(
        backend.update(
          alpha.id,
          SpecimenDraft.fromSpecimen(alpha).copyWith(ot: scarlet),
        ),
        throwsA(isA<ValidationFailure>()),
      );
      // O lote só marca alfa quem pode ser.
      final plain = await backend.create(
        SpecimenDraft(form: 1, ability: '', ot: scarlet),
      );
      final other = await backend.create(
        SpecimenDraft(form: 1, ability: '', ot: pla),
      );
      await backend.bulkUpdate(
        ids: [plain.id, other.id],
        changes: const SpecimenChanges(isAlpha: SetTo(true)),
      );
      expect((await backend.fetchSpecimen(plain.id)).isAlpha, isFalse);
      expect((await backend.fetchSpecimen(other.id)).isAlpha, isTrue);
    });

    test('alphaAllowedProvider: com o catálogo, a regra; sem, livre', () {
      final withCatalog = ProviderContainer(
        overrides: [
          fakeBackendProvider.overrideWithValue(FakeBackend.local(withAlphas)),
        ],
      );
      addTearDown(withCatalog.dispose);
      expect(withCatalog.read(alphaAllowedProvider)(1, 'hisui'), isTrue);
      expect(withCatalog.read(alphaAllowedProvider)(1, 'paldea'), isFalse);
      final seeded = ProviderContainer(
        overrides: [fakeBackendProvider.overrideWithValue(FakeBackend())],
      );
      addTearDown(seeded.dispose);
      expect(seeded.read(alphaAllowedProvider)(1, 'paldea'), isTrue);
    });
  });
}
