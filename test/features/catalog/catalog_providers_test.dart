import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/catalog_providers.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/local/data/local_data_storage.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/catalog_fixture.dart';
import '../../helpers/helpers.dart';

const _url = 'https://pages.example/ishinydex/catalog/catalog.json';
const _demo = Env(apiBaseUrl: 'x', useFakeApi: true, catalogUrl: _url);

void main() {
  late Dio dio;
  late DioAdapter adapter;

  setUp(() {
    dio = Dio();
    adapter = DioAdapter(dio: dio);
  });

  test('sem demonstração ou sem CATALOG_URL, nada muda', () async {
    expect(
      await catalogOverrides(
        const Env(apiBaseUrl: 'x', useFakeApi: false, catalogUrl: _url),
        dio,
      ),
      isEmpty,
    );
    expect(
      await catalogOverrides(const Env(apiBaseUrl: 'x', useFakeApi: true), dio),
      isEmpty,
    );
    expect(createContainer().read(catalogLoadProvider), isNull);
  });

  test('carrega o catálogo e a demonstração passa a usá-lo', () async {
    adapter.onGet(_url, (server) => server.reply(200, catalogJson()));

    final overrides = await catalogOverrides(
      _demo,
      dio,
      latency: Duration.zero,
    );
    final container = createContainer(overrides: overrides);

    final load = container.read(catalogLoadProvider)!;
    expect(load.catalog.version, 'catalog-2026.10.03');
    expect(load.elapsed, isA<Duration>());
    final backend = container.read(fakeBackendProvider);
    expect(backend.catalog, same(load.catalog));
    expect((await backend.fetchForm(150)).genderRate, -1);
  });

  test('catálogo indisponível: segue com o seed fixo', () async {
    adapter.onGet(_url, (server) => server.reply(404, null));

    expect(await catalogOverrides(_demo, dio), isEmpty);
  });

  group('modo local', () {
    const local = Env(apiBaseUrl: 'x', useFakeApi: false, localData: true);

    test('sem armazenamento informado, usa o shared_preferences', () async {
      SharedPreferences.setMockInitialValues({});
      adapter.onGet(_url, (server) => server.reply(200, catalogJson()));
      final overrides = await catalogOverrides(
        const Env(
          apiBaseUrl: 'x',
          useFakeApi: false,
          localData: true,
          catalogUrl: _url,
        ),
        dio,
      );
      expect(overrides, hasLength(3));
    });

    test('sem CATALOG_URL não abre', () {
      expect(() => catalogOverrides(local, dio), throwsA(isA<StateError>()));
    });

    testWidgets('carrega os dados salvos e grava depois de cada uso', (
      tester,
    ) async {
      adapter.onGet(_url, (server) => server.reply(200, catalogJson()));
      final storage = InMemoryLocalDataStorage();
      final overrides = await tester.runAsync(
        () => localOverrides(
          local,
          dio,
          _url,
          storage,
          saveDelay: const Duration(milliseconds: 10),
        ),
      );
      final container = createContainer(overrides: overrides!);
      final backend = container.read(fakeBackendProvider);
      expect(backend.randomIds, true);
      expect(container.read(catalogLoadProvider), isNotNull);

      await tester.runAsync(() async {
        await backend.createTrainer(name: 'Ash', trainerId: '123456');
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      expect(storage.data, contains('"trainerId":"123456"'));

      // Reabrir: os dados voltam.
      final reopened = await tester.runAsync(
        () => catalogOverrides(
          const Env(
            apiBaseUrl: 'x',
            useFakeApi: false,
            localData: true,
            catalogUrl: _url,
          ),
          dio,
          storage: storage,
        ),
      );
      final again = createContainer(overrides: reopened!);
      final trainers = await tester.runAsync(
        () => again.read(fakeBackendProvider).fetchTrainers(),
      );
      expect(trainers!.single.trainerId, '123456');
    });
  });

  group('FakeBackend.fromCatalog', () {
    late FakeBackend backend;

    setUp(() {
      backend = FakeBackend.fromCatalog(
        Catalog.fromJson(catalogJson(), spriteBase: Env.defaultSpritesBaseUrl),
      );
    });

    test('formas, opções, versões e shiny locks do catálogo', () async {
      final detail = await backend.fetchForm(1);
      expect(detail.stats.first, const FormStat(stat: 'hp', baseStat: 45));
      expect(detail.debutVersions, ['red', 'blue']);
      expect((await backend.fetchForm(150)).isDistroOnly, true);
      expect((await backend.fetchOptions()).nature.first.value, 'modest');
      expect((await backend.fetchVersions()).first.name, 'red');
      expect(
        (await backend.fetchShinyLocks()).single.caption,
        'Mewtwo de evento',
      );
      expect((await backend.searchForms('196')).single.name, 'espeon');
      // A Mega compartilha o nº nacional.
      expect(
        [for (final f in await backend.searchForms('3')) f.name],
        ['venusaur', 'venusaur-mega'],
      );
    });

    test('dex padrão inteiro no shiny dex, mais um living dex', () async {
      final dexes = await backend.fetchDexes();
      expect(dexes.map((d) => d.name), ['Shiny Living Dex', 'Living Dex']);
      final slots = await backend.fetchSlots(
        dexId: dexes.first.id,
        boxId: (await backend.fetchBoxes(dexes.first.id)).first.id,
      );
      expect([
        for (final s in slots) s.form?.id,
      ], containsAllInOrder([1, 2, 3, 133, 134, 196, 150, 172, 793]));
    });

    test('marca de origem e pokébola vêm do catálogo', () async {
      final trainer = (await backend.fetchTrainers()).firstWhere(
        (t) => t.version == 'scarlet',
      );
      final specimen = await backend.create(
        SpecimenDraft(form: 2, ot: trainer.id, pokeball: 'poke-ball'),
      );
      expect(specimen.originMark, 'paldea');
      expect(
        specimen.pokeballSpriteUrl,
        '${Env.defaultSpritesBaseUrl}/items/poke-ball.png',
      );
    });
  });
}
