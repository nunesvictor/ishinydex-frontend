import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/local/data/local_data_storage.dart';
import 'package:ishinydex/features/local/data/local_store.dart';
import 'package:ishinydex/features/local/local_data_providers.dart';

import '../fixtures/catalog_fixture.dart';

typedef _Records = Map<String, List<Map<String, dynamic>>>;

/// Os registros sem os do [type] cujo id é [id].
_Records _without(_Records records, String type, Object? id) => {
  ...records,
  type: [
    for (final r in records[type]!)
      if (r['id'] != id) r,
  ],
};

void main() {
  group('restauração com conflito do sync (#388)', () {
    test('slot de uma box apagada fica guardado, sem quebrar', () {
      final records = FakeBackend.seeded().records;
      final box = records['boxes']!.first['id'];
      final cut = _without(records, 'boxes', box);
      final orphans = [
        for (final s in records['slots']!)
          if (s['box'] == box) s,
      ];

      final backend = FakeBackend.seeded()..replaceRecords(cut);

      final out = backend.records;
      expect(out['boxes']!.any((b) => b['id'] == box), isFalse);
      // Os slots da box voltam iguais no próximo arquivo.
      for (final slot in orphans) {
        expect(out['slots']!.where((s) => s['id'] == slot['id']).single, slot);
      }
      expect(out['slots'], hasLength(records['slots']!.length));
    });

    test('save de um treinador apagado fica guardado, sem quebrar', () {
      final records = FakeBackend.seeded().records;
      final save = records['saves']!.first;
      final cut = _without(records, 'trainers', save['trainer']);

      final backend = FakeBackend.seeded()..replaceRecords(cut);

      expect(backend.records['saves'], contains(save));
    });

    test('falha no meio: os dados de antes voltam', () {
      final backend = FakeBackend.seeded();
      final before = jsonEncode(backend.records);
      final records = backend.records;
      // Um espécime sem o campo obrigatório: a restauração quebra depois
      // de já ter limpado tudo.
      final broken = {
        ...records,
        'specimens': [
          {...records['specimens']!.first}..remove('isShiny'),
          ...records['specimens']!.skip(1),
        ],
      };

      expect(() => backend.replaceRecords(broken), throwsA(isA<TypeError>()));
      expect(jsonEncode(backend.records), before);
    });
  });

  test('importar um arquivo que falha não deixa o arquivo de dados '
      'adiantado (#388)', () async {
    final catalog = Catalog.fromJson(
      catalogJson(),
      spriteBase: Env.defaultSpritesBaseUrl,
    );
    final backend = FakeBackend.local(catalog)
      ..addTrainer(name: 'Ash', trainerId: '123456');
    final data = LocalData(
      store: LocalStore(
        InMemoryLocalDataStorage(),
        now: () => DateTime.utc(2026, 11, 2),
      ),
      backend: backend,
      catalogVersion: catalog.version,
    );
    await data.save();
    final before = data.currentFile();
    final broken = {
      ...before,
      'records': {
        ...before['records'] as Map<String, dynamic>,
        'trainers': [
          {'id': 999, 'updatedAt': '2026-11-03T00:00:00.000Z'},
        ],
      },
    };

    expect(
      () => data.import(broken, merge: true, notify: false),
      throwsA(isA<TypeError>()),
    );
    // O backend e o store como antes: o próximo arquivo é igual ao de
    // antes, sem exclusões nem datas novas.
    expect(jsonEncode(data.currentFile()), jsonEncode(before));
  });
}
