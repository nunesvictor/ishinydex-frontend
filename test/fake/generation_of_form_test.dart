import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';

import '../fixtures/catalog_fixture.dart';

/// A geração de uma forma é a da estreia dela (#343), pelo grupo de versões
/// no catálogo: o Vaporeon de Galar da fixture é do Sword/Shield (geração
/// VIII), embora o Vaporeon seja da I. Antes, a geração saía do número
/// nacional da espécie; foi a correção do `pokeapiId` acima de 10000
/// (#324), que caía sempre na geração IX.
void main() {
  /// O catálogo da fixture; [galarGroup] troca o grupo do Vaporeon de Galar.
  FakeBackend backendWith({String? galarGroup}) {
    final json = catalogJson();
    if (galarGroup != null) {
      for (final form in json['forms'] as List) {
        if ((form as Map)['id'] == 10600) form['versionGroup'] = galarGroup;
      }
    }
    return FakeBackend.fromCatalog(
      Catalog.fromJson(json, spriteBase: Env.defaultSpritesBaseUrl),
    );
  }

  group('com o catálogo', () {
    late FakeBackend backend;
    late int dexId;

    setUp(() {
      backend = backendWith();
      dexId = backend.addDex(name: 'Caça', isShinyDex: true);
      backend
        ..addBox(dexId: dexId, name: 'Caça 1', formIds: [134, 10600])
        ..addSpecimen(formId: 10600);
    });

    test('as Caçadas filtram a forma pela geração da estreia', () async {
      Future<List<String>> names(List<String> generations) async => [
        for (final hunt in (await backend.fetchHunts(
          dexId,
          HuntQuery(generations: generations),
          page: 1,
          pageSize: 50,
        )).results)
          hunt.slot.form!.name,
      ];

      expect(await names(['generation-i']), ['vaporeon']);
      expect(await names(['generation-viii']), ['vaporeon-galar']);
      expect(await names(['generation-ix']), isEmpty);
    });

    test('o inventário filtra a forma pela geração da estreia', () async {
      Future<Set<String?>> forms(String generation) async => {
        for (final specimen in (await backend.fetchSpecimens(
          SpecimenQuery(generations: [generation]),
          page: 1,
          pageSize: 100,
        )).results)
          specimen.formName,
      };

      expect(await forms('generation-i'), isNot(contains('vaporeon-galar')));
      expect(await forms('generation-viii'), contains('vaporeon-galar'));
    });

    test('o progresso conta a forma na geração dela; sem uma espécie da '
        'geração, a box é a da primeira forma', () async {
      final generations = await backend.fetchGenerations(dexId);
      final box = (await backend.fetchBoxes(dexId)).single.id;
      expect(generations.map((g) => (g.generation, g.total, g.firstBox.id)), [
        ('generation-i', 1, box),
        ('generation-viii', 1, box),
      ]);
    });
  });

  test('o progresso leva à box da primeira espécie da geração, e a forma '
      'regional não segura a geração da espécie', () async {
    // Como o Raticate de Alola: um Vaporeon "do Sun/Moon" na box 1, ao
    // lado do Vaporeon, e o Nihilego, a espécie da geração VII, na box 2.
    final backend = backendWith(galarGroup: 'sun-moon');
    final dexId = backend.addDex(name: 'Caça', isShinyDex: true);
    backend
      ..addBox(dexId: dexId, name: 'Caça 1', formIds: [134, 10600])
      ..addBox(dexId: dexId, name: 'Caça 2', formIds: [793]);
    final boxes = [
      for (final summary in await backend.fetchBoxes(dexId)) summary.id,
    ];
    // Só o Vaporeon registrado (shiny), no primeiro slot da box 1.
    final vaporeon = (await backend.fetchSlots(
      dexId: dexId,
      boxId: boxes[0],
    )).first;
    await backend.deposit(
      slotId: vaporeon.id,
      specimenId: backend.addSpecimen(formId: 134, isShiny: true),
    );

    final generations = await backend.fetchGenerations(dexId);

    expect(
      generations.map(
        (g) => (g.generation, g.total, g.registered, g.firstBox.id),
      ),
      [
        // A geração I fica completa sem a forma regional.
        ('generation-i', 1, 1, boxes[0]),
        ('generation-vii', 2, 0, boxes[1]),
      ],
    );
  });

  test('sem catálogo, a geração é a da espécie', () async {
    final backend = FakeBackend()
      ..addForm(id: 25, name: 'pikachu')
      ..addForm(id: 10600, name: 'vaporeon-galar');
    final dexId = backend.addDex(name: 'Caça', isShinyDex: true);
    backend.addBox(dexId: dexId, name: 'Caça 1', formIds: [25, 10600]);

    final generations = await backend.fetchGenerations(dexId);

    // Sem número nacional no seed, vale o `pokeapiId`: 10600 cai na IX.
    expect(generations.map((g) => (g.generation, g.total)), [
      ('generation-i', 1),
      ('generation-ix', 1),
    ]);
  });
}
