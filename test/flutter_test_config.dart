import 'dart:async';
import 'dart:io';

import 'package:ishinydex/core/widgets/remote_image.dart';

/// Roda antes de cada arquivo de teste (convenção do `flutter_test`).
///
/// As imagens da internet do app nativo (#425) ficam sem disco e sem rede
/// nos testes: o `path_provider` não tem implementação aqui, e o caminho de
/// verdade (canal da plataforma, arquivo, `HttpClient`) não termina dentro
/// do relógio falso dos testes de tela. Assim, toda imagem da rede falha na
/// hora e cai no fallback, como o `NetworkImage` já fazia (o `flutter_test`
/// responde 400 a todo pedido). Os testes do próprio cache montam o seu.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  RemoteImageCache.instance = RemoteImageCache(
    directory: () async => throw const FileSystemException('sem disco'),
    download: (url) async => throw HttpException('sem rede', uri: url),
  );
  await testMain();
}
