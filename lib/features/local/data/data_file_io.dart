import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:ishinydex/core/web/browser.dart' as browser;

/// Baixar e escolher o arquivo de dados (exportar/importar).
abstract interface class DataFileIo {
  /// Oferece [bytes] como o arquivo [name] (no navegador, um download; no
  /// iPhone e no iPad, a folha de salvar/compartilhar).
  Future<void> save(String name, Uint8List bytes);

  /// Nome e conteúdo do arquivo escolhido; `null` se a pessoa desistir.
  /// [FormatException] se o arquivo não puder ser lido.
  Future<({String name, Uint8List bytes})?> pick();
}

/// Pelo plugin `file_picker`; no navegador, a escolha é pelo seletor próprio
/// ([browser.pickFileInPage]): com o do plugin, o Safari do iOS nunca
/// entregava o arquivo escolhido (ishinydex-frontend#120).
class FilePickerDataFileIo implements DataFileIo {
  FilePickerDataFileIo({
    Future<browser.PickedFile?> Function({required String accept})? pickInPage,
  }) : _pickInPage = pickInPage ?? (kIsWeb ? browser.pickFileInPage : null);

  final Future<browser.PickedFile?> Function({required String accept})?
  _pickInPage;

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
    if (_pickInPage case final pickInPage?) {
      return await pickInPage(accept: '.json,application/json');
    }
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return null;
    try {
      return (name: file.name, bytes: await file.xFile.readAsBytes());
    } on Object {
      throw FormatException('Não foi possível ler ${file.name}.');
    }
  }
}
