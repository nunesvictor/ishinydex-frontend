import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/shiny_locks/domain/models.dart';
import 'package:ishinydex/features/shiny_locks/shiny_lock_providers.dart';

import '../../helpers/helpers.dart';

void main() {
  test('o repositório é o backend local', () {
    final backend = FakeBackend.seeded();
    final container = createContainer(
      overrides: [fakeBackendProvider.overrideWithValue(backend)],
    );
    expect(container.read(shinyLockRepositoryProvider), same(backend));
  });

  test('mudar um lock recarrega as contagens do dex (#359)', () async {
    final backend = FakeBackend.seeded();
    final container = createContainer(
      overrides: [fakeBackendProvider.overrideWithValue(backend)],
    );
    final dexId = (await backend.fetchDexes()).first.id;
    final lock = (await backend.fetchShinyLocks()).first;
    final rebuilt = <String>[];
    container
      ..listen(dexListProvider, (_, next) {
        if (next.isLoading) rebuilt.add('lista');
      })
      ..listen(dexProvider(dexId), (_, next) {
        if (next.isLoading) rebuilt.add('dex');
      })
      ..listen(generationsProvider(dexId), (_, next) {
        if (next.isLoading) rebuilt.add('gerações');
      });
    await container.read(dexListProvider.future);
    await container.read(dexProvider(dexId).future);
    await container.read(generationsProvider(dexId).future);

    await container
        .read(shinyLockActionsProvider)
        .update(
          lock.id,
          ShinyLockDraft.of(lock).copyWith(active: !lock.active),
        );
    await container.pump();
    expect(rebuilt, containsAll(['lista', 'dex', 'gerações']));
  });
}
