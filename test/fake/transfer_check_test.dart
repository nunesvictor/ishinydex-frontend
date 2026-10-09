import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
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
    final mixed = backend.transferCheck([fromLgpe.id, other], save);
    expect(mixed.allowed, isTrue);
    expect(mixed.movable, [fromLgpe.id]);
    expect(mixed.blocked.single.id, other);
    expect(mixed.blocked.single.message, contains('entram nesse save'));
    expect(mixed.outside, 0); // sem catálogo, sem aviso
    await expectLater(
      backend.transfer([other], saveId: save.id),
      throwsA(
        isA<ValidationFailure>().having((f) => f.fieldErrors.keys, 'campos', [
          'save',
        ]),
      ),
    );
    // Envio parcial: vai só quem pode.
    expect(await backend.transfer([fromLgpe.id, other], saveId: save.id), 1);
    expect((await backend.fetchSlot(1)).specimen!.location, isNull);
    expect(await backend.transfer([fromLgpe.id], saveId: 1), 1);
  });

  test("Let's Go: do GO só volta quem tem OT de Let's Go (GO Park)", () async {
    final backend = FakeBackend.seeded();
    final lgpe = backend.addTrainer(
      name: 'Ash',
      trainerId: '819503',
      version: 'lets-go-eevee',
    );
    final sword = backend.addTrainer(
      name: 'Ash',
      trainerId: '111111',
      version: 'sword',
    );
    final save = await backend.createSave(trainerId: lgpe);
    final goPark = await backend.create(
      SpecimenDraft(form: 1, ability: 'run-away', ot: lgpe, isFromGo: true),
    );
    final goSword = await backend.create(
      SpecimenDraft(form: 1, ability: 'run-away', ot: sword, isFromGo: true),
    );
    final goNoOt = await backend.create(
      const SpecimenDraft(form: 1, ability: 'run-away', isFromGo: true),
    );
    expect(goPark.originMark, 'go');

    expect(backend.transferCheck([goPark.id], save).allowed, isTrue);
    expect(backend.transferCheck([goSword.id], save).allowed, isFalse);
    expect(backend.transferCheck([goNoOt.id], save).allowed, isFalse);
    await expectLater(
      backend.transfer([goSword.id], saveId: save.id),
      throwsA(
        isA<ValidationFailure>().having(
          (f) => f.fieldErrors['save'],
          'mensagem',
          ['${save.restriction} entram nesse save.'],
        ),
      ),
    );
    expect(await backend.transfer([goPark.id], saveId: save.id), 1);
  });

  test('Save.accepts e restriction', () {
    Save save(String version) => Save(
      id: 1,
      trainer: Trainer(id: 1, name: 'Ash', trainerId: '1', version: version),
    );
    final lgpe = save('lets-go-pikachu');
    expect(lgpe.accepts('lets-go', 'lets-go-eevee'), isTrue);
    expect(lgpe.accepts('go', 'lets-go-eevee'), isTrue);
    expect(lgpe.accepts('go', 'scarlet'), isFalse);
    expect(lgpe.accepts('go', null), isFalse);
    expect(lgpe.accepts('paldea', 'lets-go-pikachu'), isFalse);
    expect(lgpe.accepts(null, null), isFalse);
    expect(lgpe.restriction, contains('GO Park'));
    final scarlet = save('scarlet');
    expect(scarlet.accepts(null, null), isTrue);
    expect(scarlet.accepts('go', null), isTrue);
    expect(scarlet.restriction, isNull);
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
    final check = container.read(transferCheckProvider)([
      espeon.id,
      eevee.id,
    ], save);
    expect(check.allowed, isTrue);
    expect(check.outside, 1);
  });

  test('restrições do HOME: bloqueios e avisos por espécime', () async {
    final backend = FakeBackend.seeded()
      ..addForm(id: 9001, name: 'spinda')
      ..addForm(id: 9002, name: 'kyurem-black')
      ..addForm(id: 9003, name: 'mewtwo', category: SpeciesCategory.legendary);
    final bd = backend.addTrainer(
      name: 'Ash',
      trainerId: '1',
      version: 'brilliant-diamond',
    );
    final save = await backend.createSave(trainerId: bd);
    Future<int> make(int form, {bool go = false}) async =>
        (await backend.create(
          SpecimenDraft(form: form, ability: '', isFromGo: go),
        )).id;
    final spinda = await make(9001);
    final kyurem = await make(9002);
    final mewtwo = await make(9003, go: true);
    final check = backend.transferCheck([spinda, kyurem, mewtwo], save);
    expect(check.movable, [mewtwo]);
    expect(check.blocked.map((b) => b.message), [
      'O Spinda não vai para o BDSP',
      'Essa forma não sai do HOME',
    ]);
    expect(check.warnings.single.id, mewtwo);
    expect(await backend.transfer([spinda, mewtwo], saveId: save.id), 1);
  });
}
