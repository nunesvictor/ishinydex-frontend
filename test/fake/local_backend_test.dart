import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/shiny_locks/domain/models.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';

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

  test(
    'dex novo do zero: cria as boxes, com o dex padrão do catálogo',
    () async {
      final backend = FakeBackend.local(catalog);
      final preview = await backend.previewNewDex(forceNewBox: false);
      expect((preview.forms, preview.boxesToCreate), (9, 1));
      // Box nova por geração (no fixture: I, II, I, II).
      expect((await backend.previewNewDex(forceNewBox: true)).boxesNeeded, 4);

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
}
