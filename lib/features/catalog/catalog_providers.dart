import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/data/catalog_loader.dart';
import 'package:ishinydex/features/local/data/local_data_storage.dart';
import 'package:ishinydex/features/local/data/local_store.dart';
import 'package:ishinydex/features/local/local_data_providers.dart';

/// Catálogo carregado na inicialização (`main.dart`), quando há
/// `CATALOG_URL`; `null` sem ele.
final catalogLoadProvider = Provider<CatalogLoad?>((ref) => null);

/// Overrides da inicialização. No modo local, ver [localOverrides] (sem o
/// catálogo, falha: quem chama mostra o erro). No modo demonstração com
/// `CATALOG_URL`,
/// carrega o catálogo e troca o seed fixo do `FakeBackend` pelo catálogo
/// real. Se o catálogo não carregar, segue com o seed fixo (e avisa no
/// console): a demonstração nunca fica sem abrir.
Future<List<Override>> catalogOverrides(
  Env env,
  Dio dio, {
  Duration latency = const Duration(milliseconds: 250),
  LocalDataStorage? storage,
}) async {
  final url = env.catalogUrl;
  if (env.localData) {
    if (url == null) throw StateError('O modo local precisa do CATALOG_URL.');
    return await localOverrides(
      env,
      dio,
      url,
      storage ?? PrefsLocalDataStorage(),
    );
  }
  if (!env.useFakeApi || url == null) return const [];
  try {
    final load = await loadCatalog(
      dio,
      url: url,
      spriteBase: env.spritesBaseUrl,
    );
    return [
      catalogLoadProvider.overrideWithValue(load),
      fakeBackendProvider.overrideWithValue(
        FakeBackend.fromCatalog(load.catalog, latency: latency),
      ),
    ];
  } on Object catch (error) {
    debugPrint('Catálogo indisponível ($error); usando a demonstração fixa.');
    return const [];
  }
}

/// Modo local: o catálogo e os dados salvos no aparelho viram o backend
/// local, e cada uso dele agenda a gravação ([SaveScheduler]).
Future<List<Override>> localOverrides(
  Env env,
  Dio dio,
  String url,
  LocalDataStorage storage, {
  Duration saveDelay = const Duration(milliseconds: 500),
}) async {
  final load = await loadCatalog(dio, url: url, spriteBase: env.spritesBaseUrl);
  final store = LocalStore(storage);
  final backend = FakeBackend.local(load.catalog, records: await store.load());
  final scheduler = SaveScheduler(
    delay: saveDelay,
    save: () => store.save(backend.records, catalog: load.catalog.version),
  );
  backend.onAccess = scheduler.schedule;
  return [
    catalogLoadProvider.overrideWithValue(load),
    fakeBackendProvider.overrideWithValue(backend),
    localDataProvider.overrideWithValue(
      LocalData(
        store: store,
        backend: backend,
        catalogVersion: load.catalog.version,
      ),
    ),
  ];
}
