import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/shiny_hunts/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/shiny_hunt_providers.dart';

import '../../helpers/helpers.dart';

void main() {
  final now = DateTime(2026, 10, 9, 12);

  test('cronômetro: tempo, parar e o registro do espécime', () {
    final hunt = ShinyHunt(
      id: 1,
      form: 1,
      unit: 'hours',
      accumulatedSeconds: 600,
      runningSince: now.subtract(const Duration(hours: 1)),
      startedAt: DateTime(2026, 9, 15),
      method: 'random',
    );
    expect(hunt.running, isTrue);
    expect(hunt.timed, isTrue);
    expect(hunt.elapsed(now), const Duration(minutes: 70));
    final stopped = hunt.stopped(now);
    expect(stopped.running, isFalse);
    expect(stopped.accumulatedSeconds, 4200);
    expect(hunt.toRecord(now).count, 70);
    expect(hunt.toRecord(now).startedAt, DateTime(2026, 9, 15));
    const counted = ShinyHunt(id: 2, form: 1, count: 12, unit: 'resets');
    expect(counted.toRecord(now).count, 12);
    expect(const ShinyHunt(id: 3, form: 1).toRecord(now).count, isNull);
    expect(
      const ShinyHunt(id: 4, form: 1, unit: 'hours').toRecord(now).count,
      isNull,
    );
    expect(timerLabel(const Duration(minutes: 312)), '5 h 12 min');
    expect(timerLabel(const Duration(minutes: 7)), '7 min');
  });

  test('backend local: validações, um cronômetro, registros', () async {
    final backend = FakeBackend.seeded();
    final ot = backend.addTrainer(
      name: 'Ash',
      trainerId: '1',
      version: 'scarlet',
    );
    final save = await backend.createSave(trainerId: ot);
    Future<void> fails(ShinyHunt h, Object matcher) =>
        expectLater(backend.saveShinyHunt(h), throwsA(matcher));
    await fails(const ShinyHunt(id: 0, form: 99999), isA<ValidationFailure>());
    await fails(const ShinyHunt(id: 7, form: 1), isA<NotFoundFailure>());
    await fails(
      const ShinyHunt(id: 0, form: 1, save: 999),
      isA<ValidationFailure>(),
    );
    await fails(
      const ShinyHunt(id: 0, form: 1, count: -1),
      isA<ValidationFailure>(),
    );

    final a = await backend.saveShinyHunt(
      ShinyHunt(
        id: 0,
        form: 2,
        save: save.id,
        runningSince: now,
        unit: 'hours',
      ),
    );
    expect(a.id, isNot(0));
    expect(a.formRef?.id, 2);
    final b = await backend.saveShinyHunt(
      ShinyHunt(
        id: 0,
        form: 1,
        paused: true,
        pausedAt: DateTime(2026, 10),
        startedAt: DateTime(2026, 9),
        count: 40,
      ),
    );
    // Outro cronômetro com um rodando: recusado; o mesmo pode regravar.
    await fails(b.copyWith(runningSince: now), isA<ValidationFailure>());
    expect((await backend.saveShinyHunt(a)).id, a.id);

    final copy = FakeBackend.seeded()..replaceRecords(backend.records);
    expect(await copy.fetchShinyHunts(), await backend.fetchShinyHunts());
    // Forma fora do catálogo: guardada à parte; save sumido: sem save.
    final records = backend.records;
    final orphan = {...records['shinyHunts']!.first, 'form': 99999};
    final noSave = {...records['shinyHunts']!.first, 'id': 50, 'save': 999};
    final other = FakeBackend.seeded()
      ..replaceRecords({
        ...records,
        'shinyHunts': [orphan, noSave],
      });
    expect((await other.fetchShinyHunts()).single.save, isNull);
    expect(other.records['shinyHunts'], contains(orphan));

    await backend.deleteShinyHunt(a.id);
    await expectLater(
      backend.deleteShinyHunt(a.id),
      throwsA(isA<NotFoundFailure>()),
    );
  });

  test('ações: contagem, cronômetro, pausar, retomar e excluir', () async {
    final backend = FakeBackend.seeded();
    final container = createContainer(
      overrides: [
        fakeBackendProvider.overrideWithValue(backend),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    final actions = container.read(shinyHuntActionsProvider);
    expect(actions.today(), DateTime(2026, 10, 9));
    var hunt = await actions.save(const ShinyHunt(id: 0, form: 1));
    hunt = await actions.add(hunt, 1);
    expect(hunt.count, 1);
    hunt = await actions.add(hunt, -5);
    expect(hunt.count, 0);
    hunt = await actions.toggleTimer(hunt);
    expect(hunt.runningSince, now);
    hunt = await actions.toggleTimer(hunt);
    expect(hunt.running, isFalse);
    expect(await container.read(shinyHuntsProvider.future), [hunt]);
    expect(container.read(huntedFormsProvider), {1});
    hunt = await actions.pause(hunt);
    expect(hunt.paused, isTrue);
    expect(hunt.pausedAt, DateTime(2026, 10, 9));
    await container.read(shinyHuntsProvider.future);
    expect(container.read(huntedFormsProvider), isEmpty);
    hunt = await actions.resume(hunt);
    expect(hunt.paused, isFalse);
    await actions.delete(hunt.id);
    expect(await container.read(shinyHuntsProvider.future), isEmpty);
    expect(createContainer().read(clockProvider)(), isA<DateTime>());
  });
}
