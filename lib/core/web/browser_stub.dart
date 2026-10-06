import 'dart:typed_data';

/// Arquivo escolhido: nome e conteúdo.
typedef PickedFile = ({String name, Uint8List bytes});

/// Fora do navegador não há página: ver `browser_web.dart`.
Future<PickedFile?> pickFileInPage({required String accept}) =>
    throw UnsupportedError('Só no navegador.');

/// Fora do navegador não há página: ver `browser_web.dart`.
void openUrl(String url) => throw UnsupportedError('Só no navegador.');

/// Fora do navegador não há página: ver `browser_web.dart`.
void replaceUrl(String url) => throw UnsupportedError('Só no navegador.');
