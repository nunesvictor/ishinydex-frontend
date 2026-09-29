import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/personal_dex/data/last_dex_storage.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/helpers.dart';
import '../../helpers/mocks.dart';

void main() {
  test('PrefsLastDexStorage grava e lê o id', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = PrefsLastDexStorage();
    expect(await storage.read(), isNull);
    await storage.write(7);
    expect(await storage.read(), 7);
  });

  test('provider padrão usa shared_preferences', () {
    expect(
      createContainer().read(lastDexStorageProvider),
      isA<PrefsLastDexStorage>(),
    );
  });

  group('resolveHomeDexId', () {
    // Semeado: dex 1 (shiny) e dex 2.
    final seeded = FakeBackend.seeded();

    test('último dex usado, se ainda existir', () async {
      expect(
        await resolveHomeDexId(
          storage: InMemoryLastDexStorage(2),
          repository: seeded,
        ),
        2,
      );
    });

    test('dex salvo que sumiu e vários dexes: fica na lista', () async {
      expect(
        await resolveHomeDexId(
          storage: InMemoryLastDexStorage(99),
          repository: seeded,
        ),
        isNull,
      );
    });

    test('um único dex abre direto', () async {
      final single = FakeBackend()..addDex(name: 'Único');
      expect(
        await resolveHomeDexId(
          storage: InMemoryLastDexStorage(),
          repository: single,
        ),
        1,
      );
    });

    test('erro da API é repassado', () async {
      final repository = MockPersonalDexRepository();
      when(repository.fetchDexes).thenThrow(const NetworkFailure());
      expect(
        resolveHomeDexId(
          storage: InMemoryLastDexStorage(),
          repository: repository,
        ),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}
