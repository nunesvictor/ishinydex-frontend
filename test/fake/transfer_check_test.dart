import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

import '../fixtures/catalog_fixture.dart';
import '../helpers/helpers.dart';

void main() {
  test("Let's Go: só entra quem tem a marca dele; sair é livre", () async {
    final backend = FakeBackend.seeded();
    final ot = backend.addTrainer(
      name: 'Ash',
      trainerId: '819503',
      version: 'lets-go-pikachu',
    );
    final save = await backend.createSave(trainerId: ot);
    expect(save.requiredMark, 'lets-go');
    final fromLgpe = await backend.create(
      SpecimenDraft(form: 1, ability: 'run-away', ot: ot),
    );
    final other = (await backend.fetchSlot(1)).specimen!.id;

    expect(backend.transferCheck([fromLgpe.id], save).allowed, isTrue);
    expect(backend.transferCheck([fromLgpe.id, other], save), (
      allowed: false,
      outside: 0, // sem catálogo, sem aviso
    ));
    await expectLater(
      backend.transfer([fromLgpe.id, other], saveId: save.id),
      throwsA(
        isA<ValidationFailure>().having((f) => f.fieldErrors.keys, 'campos', [
          'save',
        ]),
      ),
    );
    expect(await backend.transfer([fromLgpe.id], saveId: save.id), 1);
    expect(await backend.transfer([fromLgpe.id], saveId: 1), 1);
  });

  test('aviso: quantos estão fora da pokédex do jogo do save', () async {
    final catalog = Catalog.fromJson(
      catalogJson(),
      spriteBase: Env.defaultSpritesBaseUrl,
    );
    final backend = FakeBackend.fromCatalog(catalog);
    final ot = backend.addTrainer(
      name: 'Ash',
      trainerId: '1',
      version: 'sword',
    );
    final save = await backend.createSave(trainerId: ot);
    final espeon = await backend.create(
      const SpecimenDraft(form: 196, ability: 'overgrow'),
    );
    final eevee = await backend.create(
      const SpecimenDraft(form: 133, ability: 'overgrow'),
    );
    final container = createContainer(
      overrides: [fakeBackendProvider.overrideWithValue(backend)],
    );
    expect(container.read(transferCheckProvider)([espeon.id, eevee.id], save), (
      allowed: true,
      outside: 1,
    ));
  });
}
