import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/local/data/local_data_storage.dart';
import 'package:ishinydex/features/local/data/local_store.dart';
import 'package:ishinydex/features/local/local_data_providers.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/shiny_hunts/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/shiny_hunt_providers.dart';
import 'package:ishinydex/features/shiny_locks/shiny_lock_providers.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

import '../../helpers/helpers.dart';

/// Um tipo de registro mudado "no outro aparelho" e o que a tela mostra
/// dele.
typedef _Case = ({
  /// Muda o primeiro registro do tipo, como faria o outro aparelho.
  void Function(Map<String, dynamic> record) change,

  /// O que a tela mostra, lido pelos providers.
  Future<Object?> Function(ProviderContainer container) shown,
});

void main() {
  // Um caso por tipo de registro do arquivo: um tipo novo sem caso aqui
  // faz o teste falhar, para não ficar fora da recarga depois do sync.
  final cases = <String, _Case>{
    'trainers': (
      change: (r) => r['name'] = 'Remoto',
      shown: (c) async => [
        for (final t in await c.read(trainersProvider.future)) t.name,
      ],
    ),
    'saves': (
      change: (r) => r['label'] = 'Remoto',
      shown: (c) async => [
        for (final s in await c.read(savesProvider.future)) s.label,
      ],
    ),
    'shinyHunts': (
      // A caçada pausada que foi retomada no outro aparelho.
      change: (r) => r['paused'] = false,
      shown: (c) async => [
        for (final h in await c.read(shinyHuntsProvider.future)) h.paused,
      ],
    ),
    'dexes': (
      change: (r) => r['name'] = 'Remoto',
      shown: (c) async => [
        for (final d in await c.read(dexListProvider.future)) d.name,
      ],
    ),
    'boxes': (
      change: (r) => r['name'] = 'Remoto',
      shown: (c) async => [
        for (final b in await c.read(boxesProvider(1).future)) b.name,
      ],
    ),
    'shinyLocks': (
      // O Pikachu (forma 25) passa de "só distribuição" a shiny lock: a
      // lista dos locks e a ficha da forma mudam.
      change: (r) => r['lockType'] = 'unobtainable',
      shown: (c) async => [
        for (final l in await c.read(shinyLocksProvider.future)) l.lockType,
        (await c.read(formDetailProvider(25).future)).isShinylocked,
      ],
    ),
    'specimens': (
      change: (r) => r['nickname'] = 'Remoto',
      shown: (c) async => (await c.read(specimenProvider(1).future)).nickname,
    ),
    'slots': (
      change: (r) => r['specimen'] = null,
      shown: (c) async => [
        for (final s in await c.read(
          slotsProvider((dexId: 1, boxId: 1)).future,
        ))
          s.specimen?.id,
      ],
    ),
  };

  test('há um caso para cada tipo de registro', () {
    expect(cases.keys, unorderedEquals(FakeBackend.recordTypes));
  });

  for (final MapEntry(key: type, value: (:change, :shown)) in cases.entries) {
    test('$type: o que chega pelo sync aparece sem recarregar', () async {
      final backend = FakeBackend.seeded();
      await backend.saveShinyHunt(
        const ShinyHunt(id: 0, form: 1, paused: true),
      );
      final data = LocalData(
        store: LocalStore(InMemoryLocalDataStorage()),
        backend: backend,
        catalogVersion: 'catalog-x',
      );
      ProviderContainer open() => createContainer(
        overrides: [
          fakeBackendProvider.overrideWithValue(backend),
          localDataProvider.overrideWithValue(data),
        ],
      );
      final container = open();
      // A tela aberta: os providers ficam vivos e com o valor em cache.
      for (final provider in [
        trainersProvider,
        savesProvider,
        shinyHuntsProvider,
        dexListProvider,
        boxesProvider(1),
        shinyLocksProvider,
        formDetailProvider(25),
        specimenProvider(1),
        slotsProvider((dexId: 1, boxId: 1)),
      ]) {
        container.listen(provider, (_, _) {});
      }
      final before = await shown(container);

      final file = data.currentFile();
      final records = file['records'] as Map<String, dynamic>;
      change((records[type] as List).first as Map<String, dynamic>);
      await container
          .read(localDataActionsProvider)
          .import(file, merge: false, notify: false);

      // Igual ao que uma tela aberta do zero (Ctrl+R) mostraria.
      final reloaded = await shown(open());
      expect(reloaded, isNot(before));
      expect(await shown(container), reloaded);
    });
  }
}
