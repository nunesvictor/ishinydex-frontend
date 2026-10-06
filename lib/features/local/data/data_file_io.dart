import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
// Só as opções do web: a biblioteca inteira depende do navegador e não
// carrega nos testes (VM).
// ignore: implementation_imports
import 'package:file_picker_web/src/file_picker_web_options.dart';

/// Baixar e escolher o arquivo de dados (exportar/importar).
abstract interface class DataFileIo {
  /// Oferece [bytes] como o arquivo [name] (no navegador, um download; no
  /// iPhone e no iPad, a folha de salvar/compartilhar).
  Future<void> save(String name, Uint8List bytes);

  /// Nome e conteúdo do arquivo escolhido; `null` se a pessoa desistir.
  /// [FormatException] se o arquivo não puder ser lido.
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
      // Por padrão, o picker do web desiste se a janela recupera o foco e a
      // escolha não chega em 500 ms. No iOS, um arquivo do iCloud ainda está
      // sendo baixado nessa hora: a escolha chega depois e era ignorada.
      // Desistir de verdade continua funcionando (evento `cancel` do input).
      webOptions: const FilePickerWebOptions(cancelUploadOnWindowBlur: false),
    );
    if (file == null) return null;
    try {
      return (name: file.name, bytes: await file.xFile.readAsBytes());
    } on Object {
      throw FormatException('Não foi possível ler ${file.name}.');
    }
  }
}
