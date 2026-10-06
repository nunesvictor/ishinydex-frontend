import 'dart:typed_data';

/// Arquivo escolhido: nome e conteúdo.
typedef PickedFile = ({String name, Uint8List bytes});

/// Fora do navegador não há página: ver `browser_web.dart`.
Future<PickedFile?> pickFileInPage({required String accept}) =>
    throw UnsupportedError('Só no navegador.');
