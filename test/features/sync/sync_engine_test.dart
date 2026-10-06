import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/local/data/local_data_storage.dart';
import 'package:ishinydex/features/local/data/local_store.dart';
import 'package:ishinydex/features/local/local_data_providers.dart';
import 'package:ishinydex/features/sync/data/dropbox_client.dart';
import 'package:ishinydex/features/sync/domain/sync_engine.dart';

import '../../fixtures/catalog_fixture.dart';
import 'fake_dropbox.dart';

/// Um aparelho: os dados locais de verdade (LocalData), vistos pelo sync.
class _Device implements SyncTarget {
  _Device(this.data);

  final LocalData data;

  @override
  Map<String, dynamic> currentFile() => data.currentFile();

  @override
  Future<void> apply(Map<String, dynamic> file, {required bool merge}) =>
      data.import(file, merge: merge);

  Future<List<String>> trainers() async => [
    for (final t in await data.backend.fetchTrainers()) t.name,
  ];
}

void main() {
  final catalog = Catalog.fromJson(
    catalogJson(),
    spriteBase: Env.defaultSpritesBaseUrl,
  );
  late FakeDropbox dropbox;

  _Device device() => _Device(
    LocalData(
      store: LocalStore(InMemoryLocalDataStorage()),
      backend: FakeBackend.local(catalog),
      catalogVersion: catalog.version,
    ),
  );

  SyncEngine engine(_Device device) => SyncEngine(
    client: DropboxClient(dropbox.dio(), appKey: 'k', refreshToken: 'rt'),
    target: device,
  );

  setUp(() => dropbox = FakeDropbox());

  test('primeiro sync envia; sem mudanças, não envia de novo', () async {
    final phone = device();
    await phone.data.backend.createTrainer(name: 'Ash', trainerId: '1');
    expect(await engine(phone).sync(), (pulled: false, pushed: true));
    expect(dropbox.content?['kind'], LocalStore.kind);
    final rev = dropbox.rev;
    expect(await engine(phone).sync(), (pulled: false, pushed: false));
    expect(dropbox.rev, rev);
  });

  test('dois aparelhos: cada um recebe o que o outro fez', () async {
    final phone = device();
    final tablet = device();
    await phone.data.backend.createTrainer(name: 'Ash', trainerId: '1');
    await engine(phone).sync();
    await tablet.data.backend.createTrainer(name: 'Misty', trainerId: '2');
    expect(await engine(tablet).sync(), (pulled: true, pushed: true));
    expect(await tablet.trainers(), unorderedEquals(['Ash', 'Misty']));
    expect(await engine(phone).sync(), (pulled: true, pushed: false));
    expect(await phone.trainers(), unorderedEquals(['Ash', 'Misty']));
  });

  test(
    'primeira conexão: usar só os do Dropbox ou só os do aparelho',
    () async {
      final remote = device();
      await remote.data.backend.createTrainer(name: 'Ash', trainerId: '1');
      await engine(remote).sync();

      final useRemote = device();
      await useRemote.data.backend.createTrainer(name: 'Brock', trainerId: '3');
      // Envia as marcas de exclusão do que havia aqui (o Brock).
      expect(await engine(useRemote).sync(mode: FirstSync.useRemote), (
        pulled: true,
        pushed: true,
      ));
      expect(await useRemote.trainers(), ['Ash']);

      final useLocal = device();
      await useLocal.data.backend.createTrainer(name: 'Brock', trainerId: '3');
      expect(await engine(useLocal).sync(mode: FirstSync.useLocal), (
        pulled: false,
        pushed: true,
      ));
      expect(await useLocal.trainers(), ['Brock']);
      final names = [
        for (final t
            in (dropbox.content!['records'] as Map)['trainers'] as List)
          (t as Map)['name'],
      ];
      expect(names, ['Brock']);
    },
  );

  test('outro aparelho envia no meio: junta e tenta de novo', () async {
    final phone = device();
    final tablet = device();
    await tablet.data.backend.createTrainer(name: 'Misty', trainerId: '2');
    final tabletFile = tablet.currentFile();
    await phone.data.backend.createTrainer(name: 'Ash', trainerId: '1');
    dropbox.beforeUpload = () => dropbox.put(tabletFile);

    expect(await engine(phone).sync(), (pulled: true, pushed: true));
    expect(await phone.trainers(), unorderedEquals(['Ash', 'Misty']));
    expect([
      for (final t in (dropbox.content!['records'] as Map)['trainers'] as List)
        (t as Map)['name'],
    ], unorderedEquals(['Ash', 'Misty']));
  });

  test('conflito em todas as tentativas: desiste com o erro', () async {
    final phone = device();
    final other = device().currentFile();
    await phone.data.backend.createTrainer(name: 'Ash', trainerId: '1');
    final client = DropboxClient(dropbox.dio(), appKey: 'k', refreshToken: 'r');
    final sync = SyncEngine(client: client, target: phone, maxAttempts: 2);
    var uploads = 0;
    void conflict() {
      uploads++;
      dropbox
        ..put(other)
        ..beforeUpload = conflict;
    }

    dropbox.beforeUpload = conflict;
    await expectLater(sync.sync(), throwsA(isA<DropboxConflictException>()));
    expect(uploads, 2);
  });

  test('sameData ignora a ordem dos registros e das chaves', () {
    Map<String, dynamic> file(List<Map<String, dynamic>> trainers) => {
      'savedAt': 'qualquer',
      'records': {'trainers': trainers},
      'deleted': <String, dynamic>{},
    };
    expect(
      SyncEngine.sameData(
        file([
          {'id': 1, 'name': 'A'},
          {
            'id': 2,
            'name': 'B',
            'tags': [1, 2],
          },
        ]),
        file([
          {
            'tags': [1, 2],
            'name': 'B',
            'id': 2,
          },
          {'name': 'A', 'id': 1},
        ]),
      ),
      isTrue,
    );
    expect(
      SyncEngine.sameData(
        file([
          {
            'id': 1,
            'tags': [1, 2],
          },
        ]),
        file([
          {
            'id': 1,
            'tags': [2, 1],
          },
        ]),
      ),
      isFalse,
    );
  });
}
