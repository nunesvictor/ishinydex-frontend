import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/fake/fake_backend.dart';

void main() {
  test('Champions: visita trava envio e libertar; volta libera', () async {
    final backend = FakeBackend.seeded();
    final ot = backend.addTrainer(
      name: 'Ash',
      trainerId: '1',
      version: 'scarlet',
    );
    final save = await backend.createSave(trainerId: ot);
    final id = (await backend.fetchSlot(1)).specimen!.id;

    await expectLater(
      backend.setChampionsVisit(999, visiting: true),
      throwsA(isA<NotFoundFailure>()),
    );
    final visiting = await backend.setChampionsVisit(id, visiting: true);
    expect(visiting.isVisitingChampions, isTrue);
    // De novo: nada muda.
    expect(await backend.setChampionsVisit(id, visiting: true), visiting);
    expect((await backend.fetchSlot(1)).specimen!.isVisitingChampions, isTrue);
    expect(
      backend.transferCheck([id], save).blocked.single.message,
      'Está visitando o Champions',
    );
    Matcher locked() => throwsA(
      isA<ValidationFailure>().having((f) => f.fieldErrors.keys, 'campos', [
        'champions',
      ]),
    );
    await expectLater(backend.release(id), locked());
    await expectLater(backend.bulkRelease([id]), locked());

    // Ida e volta pelos registros.
    final copy = FakeBackend.seeded()..replaceRecords(backend.records);
    expect(
      (await copy.fetchSpecimen(id)).championsSince,
      visiting.championsSince,
    );

    final back = await backend.setChampionsVisit(id, visiting: false);
    expect(back.isVisitingChampions, isFalse);
    expect(await backend.transfer([id], saveId: save.id), 1);
    // Num save, não visita.
    await expectLater(
      backend.setChampionsVisit(id, visiting: true),
      throwsA(isA<ValidationFailure>()),
    );
    await backend.release(id);
  });
}
