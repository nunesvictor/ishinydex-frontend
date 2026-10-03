import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/features/local/data/local_data_storage.dart';
import 'package:ishinydex/features/local/data/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late InMemoryLocalDataStorage storage;
  late DateTime now;
  late LocalStore store;

  Map<String, dynamic> saved() =>
      jsonDecode(storage.data!) as Map<String, dynamic>;
  List<dynamic> savedRecords(String type) =>
      (saved()['records'] as Map<String, dynamic>)[type] as List;

  setUp(() {
    storage = InMemoryLocalDataStorage();
    now = DateTime.utc(2026, 10, 3, 12);
    store = LocalStore(storage, now: () => now);
  });

  Records records(List<Map<String, dynamic>> specimens) => {
    'specimens': specimens,
  };

  test('aparelho novo: sem registros', () async {
    expect(await store.load(), isEmpty);
  });

  test('carimba novos e alterados; mantém a data dos iguais', () async {
    expect(
      await store.save(
        records([
          {'id': 1, 'nickname': 'A'},
          {'id': 2, 'nickname': 'B'},
        ]),
        catalog: 'catalog-1',
      ),
      true,
    );
    final first = saved();
    expect(first['schemaVersion'], LocalStore.schemaVersion);
    expect(first['kind'], LocalStore.kind);
    expect(first['catalog'], 'catalog-1');
    expect(savedRecords('specimens').first, {
      'id': 1,
      'nickname': 'A',
      'updatedAt': '2026-10-03T12:00:00.000Z',
    });

    // Nada mudou: não grava de novo.
    expect(
      await store.save(
        records([
          {'id': 1, 'nickname': 'A'},
          {'id': 2, 'nickname': 'B'},
        ]),
        catalog: 'catalog-1',
      ),
      false,
    );

    now = DateTime.utc(2026, 10, 3, 13);
    await store.save(
      records([
        {'id': 1, 'nickname': 'A'},
        {'id': 2, 'nickname': 'Bê'},
      ]),
      catalog: 'catalog-1',
    );
    final [one, two] = savedRecords('specimens');
    expect((one as Map)['updatedAt'], '2026-10-03T12:00:00.000Z');
    expect((two as Map)['updatedAt'], '2026-10-03T13:00:00.000Z');
  });

  test('registro sumido vira marca; ao voltar, a marca sai', () async {
    await store.save(
      records([
        {'id': 1},
        {'id': 2},
      ]),
      catalog: 'c',
    );
    now = DateTime.utc(2026, 10, 4);
    await store.save(
      records([
        {'id': 1},
      ]),
      catalog: 'c',
    );
    expect(saved()['deleted'], {
      'specimens': {'2': '2026-10-04T00:00:00.000Z'},
    });

    await store.save(
      records([
        {'id': 1},
        {'id': 2},
      ]),
      catalog: 'c',
    );
    expect(saved()['deleted'], {'specimens': <String, String>{}});
  });

  test(
    'ler o arquivo devolve os registros sem as datas, e as mantém',
    () async {
      await store.save(
        records([
          {'id': 7, 'nickname': 'Saur'},
        ]),
        catalog: 'c',
      );
      now = DateTime.utc(2026, 10, 4);
      await store.save(records([]), catalog: 'c');

      final reopened = LocalStore(storage, now: () => DateTime.utc(2027));
      expect(await reopened.load(), {'specimens': <Map<String, dynamic>>[]});
      expect(reopened.deleted['specimens'], {'7': '2026-10-04T00:00:00.000Z'});

      await LocalStore(storage, now: () => now).save(
        records([
          {'id': 8},
        ]),
        catalog: 'c',
      );
      final again = LocalStore(storage, now: () => DateTime.utc(2027));
      expect(await again.load(), {
        'specimens': [
          {'id': 8},
        ],
      });
      // Reler e salvar o mesmo conteúdo não muda a data.
      await again.save(
        records([
          {'id': 8},
        ]),
        catalog: 'c',
      );
      expect(
        (savedRecords('specimens').single as Map)['updatedAt'],
        '2026-10-04T00:00:00.000Z',
      );
    },
  );

  test('outro arquivo ou formato mais novo: FormatException', () async {
    storage.data = jsonEncode({'kind': 'outra-coisa'});
    expect(store.load, throwsA(isA<FormatException>()));
    storage.data = jsonEncode({
      'kind': LocalStore.kind,
      'schemaVersion': LocalStore.schemaVersion + 1,
    });
    expect(store.load, throwsA(isA<FormatException>()));
  });

  testWidgets('SaveScheduler: uma gravação por rajada, depois do atraso', (
    tester,
  ) async {
    var saves = 0;
    final scheduler = SaveScheduler(
      delay: const Duration(milliseconds: 500),
      save: () async => saves++,
    )..schedule();
    await tester.pump(const Duration(milliseconds: 300));
    scheduler.schedule();
    await tester.pump(const Duration(milliseconds: 300));
    expect(saves, 0);
    await tester.pump(const Duration(milliseconds: 300));
    expect(saves, 1);
  });

  test('PrefsLocalDataStorage lê e grava', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PrefsLocalDataStorage();
    expect(await prefs.read(), isNull);
    await prefs.write('{"a":1}');
    expect(await prefs.read(), '{"a":1}');
  });
}
