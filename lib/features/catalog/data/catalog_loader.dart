import 'package:dio/dio.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';

/// Catálogo carregado, com o tempo que levou (download + leitura), mostrado
/// em Sobre: é a medida de quanto o pacote pesa no aparelho.
class CatalogLoad {
  const CatalogLoad({required this.catalog, required this.elapsed});

  final Catalog catalog;
  final Duration elapsed;
}

/// Baixa e lê o `catalog.json` de [url].
Future<CatalogLoad> loadCatalog(
  Dio dio, {
  required String url,
  required String spriteBase,
}) async {
  final watch = Stopwatch()..start();
  final response = await dio.get<Map<String, dynamic>>(url);
  final catalog = Catalog.fromJson(response.data!, spriteBase: spriteBase);
  return CatalogLoad(catalog: catalog, elapsed: watch.elapsed);
}
