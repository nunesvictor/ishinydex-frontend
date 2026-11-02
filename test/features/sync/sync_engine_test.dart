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

  @override
  Future<void> markSynced(String device, DateTime at) =>
      data.markSynced(device, at);

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

  SyncEngine engine(_Device device, {String id = 'phone', DateTime? at}) =>
      SyncEngine(
        client: DropboxClient(dropbox.dio(), appKey: 'k', refreshToken: 'rt'),
        target: device,
        device: id,
        now: at == null ? null : () => at,
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

  test('só este aparelho mudou: envia, sem contar como recebido', () async {
    final phone = device();
    await phone.data.backend.createTrainer(name: 'Ash', trainerId: '1');
    await engine(phone).sync();
    await phone.data.backend.createTrainer(name: 'Brock', trainerId: '3');
    // O Dropbox difere (não tem o Brock), mas juntar não muda nada aqui.
    expect(await engine(phone).sync(), (pulled: false, pushed: true));
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
    final sync = SyncEngine(
      client: client,
      target: phone,
      device: 'phone',
      maxAttempts: 2,
    );
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

  group('limpeza das exclusões (#393)', () {
    Map<String, dynamic> deletedOn(Map<String, dynamic> file) =>
        ((file['deleted'] as Map)['dexes'] as Map?)?.cast<String, dynamic>() ??
        const {};

    test('a marca só some depois de todos os aparelhos a receberem', () async {
      final phone = device();
      final pc = device();
      final dex = await phone.data.backend.createDex(
        name: 'Shiny',
        isShinyDex: true,
        forceNewBox: false,
      );
      final day = DateTime.utc(2026, 10);
      await engine(phone, at: day).sync();
      await engine(pc, id: 'pc', at: day).sync();
      await phone.data.backend.deleteDex(dex.id);
      await engine(phone, at: day.add(const Duration(days: 1))).sync();
      final mark = '${dex.id}';
      expect(deletedOn(dropbox.content!), contains(mark));
      expect(
        (dropbox.content!['arrived'] as Map)['dexes'],
        containsPair(mark, '2026-10-02T00:00:00.000Z'),
      );

      // 40 dias depois: o PC não sincronizou desde antes da chegada.
      final later = day.add(const Duration(days: 40));
      await engine(phone, at: later).sync();
      expect(deletedOn(dropbox.content!), contains(mark));

      // O PC recebe a exclusão; no sync seguinte, a marca some.
      await engine(pc, id: 'pc', at: later).sync();
      expect(await pc.data.backend.fetchDexes(), isEmpty);
      await engine(phone, at: later.add(const Duration(hours: 1))).sync();
      await engine(
        pc,
        id: 'pc',
        at: later.add(const Duration(hours: 2)),
      ).sync();
      expect(deletedOn(phone.currentFile()), isEmpty);
      expect(deletedOn(pc.currentFile()), isEmpty);
      expect(deletedOn(dropbox.content!), isEmpty);
    });

    test('sem mudança, avisa o Dropbox uma vez por dia', () async {
      final phone = device();
      final day = DateTime.utc(2026, 10);
      expect((await engine(phone, at: day).sync()).pushed, true);
      final hour = day.add(const Duration(hours: 1));
      expect((await engine(phone, at: hour).sync()).pushed, false);
      final next = day.add(const Duration(days: 1));
      expect((await engine(phone, at: next).sync()).pushed, true);
      expect(dropbox.content!['devices'], {
        'phone': '2026-10-02T00:00:00.000Z',
      });
    });
  });
}
