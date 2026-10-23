import 'dart:typed_data';

import 'package:ishinydex/core/web/share_outcome.dart';

/// Arquivo escolhido: nome e conteúdo.
typedef PickedFile = ({String name, Uint8List bytes});

/// Fora do navegador não há página: ver `browser_web.dart`.
Future<PickedFile?> pickFileInPage({required String accept}) =>
    throw UnsupportedError('Só no navegador.');

/// Fora do navegador não há página: ver `browser_web.dart`.
void openUrl(String url) => throw UnsupportedError('Só no navegador.');

/// Fora do navegador não há página: ver `browser_web.dart`.
void replaceUrl(String url) => throw UnsupportedError('Só no navegador.');

/// Fora do navegador não há página: ver `browser_web.dart`.
void openInNewTab(String url) => throw UnsupportedError('Só no navegador.');

/// Fora do navegador não há versão nova de página: nunca chama.
void onAppUpdateReady(void Function() onReady) {}

/// Fora do navegador não há service worker: termina logo.
Future<void> offlineCacheReady() async {}

/// Fora do navegador não há página: ver `browser_web.dart`.
void reloadPage() => throw UnsupportedError('Só no navegador.');

/// Fora do navegador não há página: ver `browser_web.dart`.
Future<ShareOutcome> shareFile(
  Uint8List bytes, {
  required String name,
  required String type,
}) => throw UnsupportedError('Só no navegador.');
