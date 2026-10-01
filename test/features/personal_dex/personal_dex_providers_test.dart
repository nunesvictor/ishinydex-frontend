import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/personal_dex/data/http_personal_dex_repository.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/specimens/data/http_specimen_repository.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

import '../../helpers/helpers.dart';

void main() {
  test('repositórios HTTP quando USE_FAKE_API=false', () {
    final container = createContainer(
      overrides: [
        envProvider.overrideWithValue(
          const Env(apiBaseUrl: 'http://x/api', useFakeApi: false),
        ),
      ],
    );
    expect(
      container.read(personalDexRepositoryProvider),
      isA<HttpPersonalDexRepository>(),
    );
    expect(
      container.read(specimenRepositoryProvider),
      isA<HttpSpecimenRepository>(),
    );
  });

  group('SlotActions', () {
    late FakeBackend backend;

    setUp(() => backend = FakeBackend.seeded());

    test('deposit/release atualizam as contagens em cache', () async {
      final container = createContainer(
        overrides: [
          envProvider.overrideWithValue(fakeEnv),
          fakeBackendProvider.overrideWithValue(backend),
        ],
      );
      const key = (dexId: 1, boxId: 1);
      final listSub = container.listen(dexListProvider, (_, _) {});
      final dexSub = container.listen(dexProvider(1), (_, _) {});
      final boxesSub = container.listen(boxesProvider(1), (_, _) {});
      final slotsSub = container.listen(slotsProvider(key), (_, _) {});
      addTearDown(() {
        listSub.close();
        dexSub.close();
        boxesSub.close();
        slotsSub.close();
      });

      final before = await container.read(dexProvider(1).future);
      final slot = (await container.read(slotsProvider(key).future))[2];
      final saur = (await backend.fetchAvailable(3)).single;
      // Shiny para contar no progresso do shiny dex.
      await backend.bulkUpdate(
        ids: [saur.id],
        changes: const SpecimenChanges(isShiny: SetTo(true)),
      );

      final actions = container.read(slotActionsProvider);
      final updated = await actions.deposit(slot, specimenId: saur.id);
      expect(updated.isRegistered, true);
      expect(
        (await container.read(dexProvider(1).future)).registered,
        before.registered + 1,
      );
      expect(
        (await container.read(dexListProvider.future)).first.registered,
        before.registered + 1,
      );
      expect(
        (await container.read(boxesProvider(1).future)).first.registered,
        21,
      );
      expect(
        (await container.read(slotsProvider(key).future))[2].isRegistered,
        true,
      );

      await actions.release(updated);
      expect(
        (await container.read(dexProvider(1).future)).registered,
        before.registered,
      );
      expect(await backend.fetchAvailable(3), isEmpty);
    });

    test('slot sem personal_dex só invalida a lista', () async {
      final container = createContainer(
        overrides: [
          envProvider.overrideWithValue(fakeEnv),
          fakeBackendProvider.overrideWithValue(backend),
        ],
      );
      final slot = (await backend.fetchSlots(
        dexId: 1,
        boxId: 1,
      ))[0].copyWith(personalDex: null);
      await container.read(slotActionsProvider).release(slot);
      expect((await backend.fetchSlots(dexId: 1, boxId: 1))[0].isMissing, true);
    });

    test('specimenEdited recarrega o specimen e o slot', () async {
      final container = createContainer(
        overrides: [
          envProvider.overrideWithValue(fakeEnv),
          fakeBackendProvider.overrideWithValue(backend),
        ],
      );
      const key = (dexId: 1, boxId: 1);
      final specimenSub = container.listen(specimenProvider(1), (_, _) {});
      final slotsSub = container.listen(slotsProvider(key), (_, _) {});
      addTearDown(() {
        specimenSub.close();
        slotsSub.close();
      });
      final slot = (await container.read(slotsProvider(key).future)).first;
      await container.read(specimenProvider(1).future);
      await backend.update(
        1,
        SpecimenDraft.fromSpecimen(await backend.fetchSpecimen(1))
            .copyWith(nickname: 'Bulba'),
      );

      container.read(slotActionsProvider).specimenEdited(slot);
      expect(
        (await container.read(specimenProvider(1).future)).nickname,
        'Bulba',
      );
      expect(
        (await container.read(slotsProvider(key).future))
            .first
            .specimen!
            .nickname,
        'Bulba',
      );
    });
  });
}
