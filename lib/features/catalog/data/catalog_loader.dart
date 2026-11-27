import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:path_provider/path_provider.dart';

/// Catálogo carregado, com o tempo que levou (download + leitura), mostrado
/// em Sobre: é a medida de quanto o pacote pesa no aparelho.
class CatalogLoad {
  const CatalogLoad({required this.catalog, required this.elapsed});

  final Catalog catalog;
  final Duration elapsed;
}

/// Quanto a abertura espera pela rede quando já há um catálogo guardado
/// ([CatalogCache]); passou disso, abre com o guardado.
const catalogNetworkGrace = Duration(seconds: 4);

/// O último catálogo baixado, guardado no aparelho (#427).
///
/// Só o app nativo usa: no PWA, o service worker já guarda o `catalog.json`
/// (rede primeiro, cache de reserva). Sem ele, o nativo baixava 1,7 MB a
/// cada abertura e não abria sem internet.
abstract interface class CatalogCache {
  /// O JSON guardado; `null` se não houver (ou não der para ler).
  Future<String?> read();

  /// Guarda [json]; uma falha (sem espaço, por exemplo) é ignorada.
  Future<void> write(String json);
}

/// O [CatalogCache] em arquivo, na pasta de suporte do app
/// (`Library/Application Support` no iOS). Ao contrário da pasta de cache,
/// o iOS não a limpa sozinho: o app não pode ficar sem catálogo offline.
class FileCatalogCache implements CatalogCache {
  FileCatalogCache({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;

  Future<File> get _file async =>
      File('${(await _directory()).path}/catalog.json');

  @override
  Future<String?> read() async {
    try {
      final file = await _file;
      return file.existsSync() ? await file.readAsString() : null;
    } on Exception {
      return null;
    }
  }

  /// Grava num temporário e renomeia: um app fechado no meio nunca deixa
  /// meio catálogo no lugar do inteiro.
  @override
  Future<void> write(String json) async {
    try {
      final file = await _file;
      await file.parent.create(recursive: true);
      final partial = File('${file.path}.part');
      await partial.writeAsString(json, flush: true);
      await partial.rename(file.path);
    } on Exception {
      // Sem espaço ou sem permissão: abre igual, só não guarda.
    }
  }
}

/// Baixa e lê o `catalog.json` de [url].
///
/// Com um [cache] (app nativo), é rede primeiro com o guardado de reserva:
/// - sem catálogo guardado, espera a rede (a primeira abertura precisa dela);
/// - com um guardado, espera a rede até [grace]. Se ela falhar ou demorar,
///   abre com o guardado, e o download segue por trás: quando chegar, fica
///   guardado para a próxima abertura.
///
/// Só guarda um catálogo que foi lido sem erro.
Future<CatalogLoad> loadCatalog(
  Dio dio, {
  required String url,
  required String spriteBase,
  CatalogCache? cache,
  Duration grace = catalogNetworkGrace,
}) async {
  final watch = Stopwatch()..start();
  final saved = await cache?.read();
  final fresh = _download(dio, url, cache);
  Map<String, dynamic> json;
  if (saved == null) {
    json = await fresh;
  } else {
    try {
      json = await fresh.timeout(grace);
    } on Object {
      fresh.ignore();
      json = _decode(saved);
    }
  }
  final catalog = Catalog.fromJson(json, spriteBase: spriteBase);
  return CatalogLoad(catalog: catalog, elapsed: watch.elapsed);
}

Future<Map<String, dynamic>> _download(
  Dio dio,
  String url,
  CatalogCache? cache,
) async {
  final response = await dio.get<String>(
    url,
    options: Options(responseType: ResponseType.plain),
  );
  final text = response.data!;
  final json = _decode(text);
  await cache?.write(text);
  return json;
}

Map<String, dynamic> _decode(String text) =>
    jsonDecode(text) as Map<String, dynamic>;
