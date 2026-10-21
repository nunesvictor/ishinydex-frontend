import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';

import '../fixtures/catalog_fixture.dart';

/// #324: a geração sai do número nacional. O Vaporeon de Galar tem o
/// `pokeapiId` 10600, e antes caía na geração 9.
void main() {
  late FakeBackend backend;
  late int dexId;

  setUp(() {
    backend = FakeBackend.fromCatalog(
      Catalog.fromJson(catalogJson(), spriteBase: Env.defaultSpritesBaseUrl),
    );
    dexId = backend.addDex(name: 'Caça', isShinyDex: true);
    backend
      ..addBox(dexId: dexId, name: 'Caça 1', formIds: [134, 10600])
      ..addSpecimen(formId: 10600);
  });

  test('as Caçadas filtram a forma alternativa pela geração dela', () async {
    Future<List<String>> names(List<String> generations) async => [
      for (final hunt in (await backend.fetchHunts(
        dexId,
        HuntQuery(generations: generations),
        page: 1,
        pageSize: 50,
      )).results)
        hunt.slot.form!.name,
    ];

    expect(await names(['generation-i']), ['vaporeon', 'vaporeon-galar']);
    expect(await names(['generation-ix']), isEmpty);
  });

  test('o inventário filtra a forma alternativa pela geração dela', () async {
    Future<Set<String?>> forms(String generation) async => {
      for (final specimen in (await backend.fetchSpecimens(
        SpecimenQuery(generations: [generation]),
        page: 1,
        pageSize: 100,
      )).results)
        specimen.formName,
    };

    expect(await forms('generation-i'), contains('vaporeon-galar'));
    expect(await forms('generation-ix'), isNot(contains('vaporeon-galar')));
  });

  test('o progresso conta a forma alternativa na geração dela', () async {
    final generations = await backend.fetchGenerations(dexId);
    expect(generations.map((g) => (g.generation, g.total)), [
      ('generation-i', 2),
    ]);
  });
}
