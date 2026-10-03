import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Baixar e escolher o arquivo de dados (exportar/importar).
abstract interface class DataFileIo {
  /// Oferece [bytes] como o arquivo [name] (no navegador, um download; no
  /// iPhone e no iPad, a folha de salvar/compartilhar).
  Future<void> save(String name, Uint8List bytes);

  /// Nome e conteúdo do arquivo escolhido; `null` se a pessoa desistir.
  Future<({String name, Uint8List bytes})?> pick();
}

/// Pelo plugin `file_picker`, que funciona no navegador e no iOS.
class FilePickerDataFileIo implements DataFileIo {
  @override
  Future<void> save(String name, Uint8List bytes) async {
    await FilePicker.saveFile(
      fileName: name,
      bytes: bytes,
      mimeType: 'application/json',
    );
  }

  @override
  Future<({String name, Uint8List bytes})?> pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return null;
    return (name: file.name, bytes: await file.xFile.readAsBytes());
  }
}
