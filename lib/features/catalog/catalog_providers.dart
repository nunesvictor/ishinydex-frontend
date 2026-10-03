import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/data/catalog_loader.dart';

/// Catálogo carregado na inicialização (`main.dart`), quando há
/// `CATALOG_URL`; `null` sem ele.
final catalogLoadProvider = Provider<CatalogLoad?>((ref) => null);

/// Overrides da inicialização: no modo demonstração com `CATALOG_URL`,
/// carrega o catálogo e troca o seed fixo do `FakeBackend` pelo catálogo
/// real. Se o catálogo não carregar, segue com o seed fixo (e avisa no
/// console): a demonstração nunca fica sem abrir.
Future<List<Override>> catalogOverrides(
  Env env,
  Dio dio, {
  Duration latency = const Duration(milliseconds: 250),
}) async {
  final url = env.catalogUrl;
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
