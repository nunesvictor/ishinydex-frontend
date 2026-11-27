import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

/// Uma imagem da internet (sprite, ball, item), com o cache certo para cada
/// plataforma (#425).
///
/// - **PWA:** o `NetworkImage` de sempre. O service worker já guarda cada
///   imagem em disco no primeiro uso.
/// - **App nativo:** o [DiskCachedImage]. O Flutter só guarda as imagens na
///   memória, que se perde quando o iOS fecha o app em segundo plano; em
///   disco, cada imagem é baixada uma vez e funciona sem internet.
ImageProvider remoteImage(String url, {bool web = kIsWeb}) => web
    ? NetworkImage(url, webHtmlElementStrategy: WebHtmlElementStrategy.fallback)
    : DiskCachedImage(url);

/// Baixa os bytes de um endereço; falha (exceção) se a resposta não for 200.
typedef Download = Future<Uint8List> Function(Uri url);

/// Onde o app nativo guarda as imagens baixadas, e como as baixa.
///
/// A pasta padrão é a de cache do app (`Library/Caches` no iOS): o sistema
/// pode limpá-la quando falta espaço, e tudo bem, a imagem é baixada de
/// novo. Os endereços dos sprites não mudam de conteúdo, então não há
/// expiração: o que está no disco vale para sempre.
class RemoteImageCache {
  RemoteImageCache({
    Future<Directory> Function()? directory,
    this.download = downloadBytes,
  }) : _directory = directory ?? _defaultDirectory;

  /// O cache do app; trocável nos testes.
  static RemoteImageCache instance = RemoteImageCache();

  final Future<Directory> Function() _directory;
  final Download download;

  static Future<Directory> _defaultDirectory() async =>
      Directory('${(await getApplicationCacheDirectory()).path}/images');

  /// O arquivo de um endereço: o SHA-1 do endereço como nome, que cabe em
  /// qualquer sistema de arquivos e não depende dos caracteres da URL.
  Future<File> fileFor(String url) async {
    final name = sha1.convert(utf8.encode(url)).toString();
    return File('${(await _directory()).path}/$name');
  }

  /// Os bytes da imagem: do disco, se já estiver lá; senão, da internet, e
  /// guarda no disco para a próxima vez. Sem a pasta (um erro do sistema),
  /// ainda baixa: o cache é um ganho, não uma condição.
  Future<Uint8List> bytes(String url) async {
    File? file;
    try {
      file = await fileFor(url);
      if (file.existsSync()) {
        final cached = await file.readAsBytes();
        if (cached.isNotEmpty) return cached;
      }
    } on Exception {
      file = null;
    }
    final fresh = await download(Uri.parse(url));
    if (file != null) await _save(file, fresh);
    return fresh;
  }

  /// Apaga o arquivo de um endereço (ex.: guardado corrompido).
  Future<void> evict(String url) async {
    try {
      final file = await fileFor(url);
      if (file.existsSync()) await file.delete();
    } on Exception {
      // Nada a apagar.
    }
  }

  /// Grava num arquivo temporário e renomeia: se o app for fechado no meio,
  /// fica só o temporário, e nunca uma imagem pela metade no lugar da certa.
  static Future<void> _save(File file, Uint8List bytes) async {
    try {
      await file.parent.create(recursive: true);
      final partial = File('${file.path}.part');
      await partial.writeAsBytes(bytes, flush: true);
      await partial.rename(file.path);
    } on Exception {
      // Sem espaço ou sem permissão: a imagem aparece, só não fica guardada.
    }
  }
}

/// Um `HttpClient` para todos os downloads, como o do `NetworkImage`: ele
/// reaproveita as conexões (keep-alive). Com um cliente por imagem, cada
/// sprite pagava a conexão e o TLS inteiros, de 0,1 a 0,3 s no celular
/// (#432).
final HttpClient _client = HttpClient();

/// Baixa com o `HttpClient` do Dart (só no nativo; a web usa o navegador).
Future<Uint8List> downloadBytes(Uri url) async {
  final response = await (await _client.getUrl(url)).close();
  if (response.statusCode != HttpStatus.ok) {
    // Lê o corpo até o fim, para a conexão voltar livre para o próximo.
    await response.drain<void>();
    throw HttpException('HTTP ${response.statusCode}', uri: url);
  }
  return await consolidateHttpClientResponseBytes(response);
}

/// Imagem da internet guardada em disco pelo [RemoteImageCache], para o app
/// nativo.
///
/// Dois [DiskCachedImage] do mesmo endereço são iguais: o `imageCache` do
/// Flutter os trata como a mesma imagem, então quem pré-carrega (ex.:
/// `NeighborBoxPrecache`) e quem desenha (`PokemonSprite`) dividem a mesma
/// imagem decodificada, como já acontecia com o `NetworkImage`.
@immutable
class DiskCachedImage extends ImageProvider<DiskCachedImage> {
  const DiskCachedImage(this.url, {this.cache});

  final String url;

  /// O cache a usar; `null` = o [RemoteImageCache.instance] da hora.
  final RemoteImageCache? cache;

  @override
  Future<DiskCachedImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    DiskCachedImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _load(decode),
    scale: 1,
    debugLabel: url,
  );

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final store = cache ?? RemoteImageCache.instance;
    final bytes = await store.bytes(url);
    try {
      return await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    } on Object {
      // O que veio não é uma imagem: não guarda, para tentar de novo depois.
      await store.evict(url);
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is DiskCachedImage && other.url == url && other.cache == cache;

  @override
  int get hashCode => Object.hash(url, cache);

  @override
  String toString() => 'DiskCachedImage("$url")';
}
