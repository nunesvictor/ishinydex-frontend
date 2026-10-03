import 'dart:convert';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/local/data/data_file_io.dart';
import 'package:ishinydex/features/local/data/local_data_storage.dart';
import 'package:ishinydex/features/local/data/local_store.dart';
import 'package:ishinydex/features/local/local_data_providers.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../../fixtures/catalog_fixture.dart';
import '../../helpers/helpers.dart';

final class _MemoryFile extends PlatformFile {
  _MemoryFile(this.name, this.bytes);

  @override
  final String name;
  final Uint8List bytes;

  @override
  Uri get uri => Uri.parse('memory:$name');

  @override
  XFile get xFile => XFile.fromData(bytes, name: name);

  @override
  int? lengthSync() => bytes.length;

  @override
  Future<int?> length() async => bytes.length;

  @override
  Future<Uint8List> readAsBytes() async => bytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);
}

class _FakePicker extends FilePickerPlatform with MockPlatformInterfaceMixin {
  PlatformFile? picked;
  ({String name, Uint8List bytes, String mime})? saved;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    dynamic Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => picked;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    dynamic Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    saved = (name: fileName, bytes: bytes, mime: mimeType);
    return null;
  }
}

void main() {
  final catalog = Catalog.fromJson(
    catalogJson(),
    spriteBase: Env.defaultSpritesBaseUrl,
  );

  LocalData make() {
    final backend = FakeBackend.local(catalog)
      ..addTrainer(name: 'Ash', trainerId: '123456');
    return LocalData(
      store: LocalStore(InMemoryLocalDataStorage()),
      backend: backend,
      catalogVersion: catalog.version,
    );
  }

  test('exportar: nome com a data e o arquivo de dados', () {
    final data = make();
    final file = data.export(today: DateTime(2026, 10, 3));
    expect(file.name, 'ishinydex-2026-10-03.json');
    final parsed = LocalData.read(file.bytes);
    expect(parsed['kind'], LocalStore.kind);
    final summary = LocalData.summarize(parsed);
    expect((summary.dexes, summary.specimens, summary.saves), (0, 0, 0));
    expect(summary.savedAt, isA<DateTime>());
  });

  test('arquivo inválido: FormatException com a mensagem', () {
    for (final bytes in [
      Uint8List.fromList([0xff, 0xfe]),
      utf8.encode('não é json'),
      utf8.encode('{"kind": "outro"}'),
      utf8.encode('[]'),
    ]) {
      expect(
        () => LocalData.read(bytes),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('iShinyDex'),
          ),
        ),
      );
    }
  });

  test('importar substituindo: o aparelho fica igual ao arquivo', () async {
    final other = make();
    await other.backend.createTrainer(name: 'Rei', trainerId: '999999');
    final file = other.currentFile();

    final data = make();
    await data.import(file, merge: false);
    expect([
      for (final t in await data.backend.fetchTrainers()) t.name,
    ], unorderedEquals(['Ash', 'Rei']));
    // Os ids do arquivo vieram junto: o "Ash" daqui saiu.
    expect(data.backend.records['trainers'], other.backend.records['trainers']);
    expect(
      (data.store.storage as InMemoryLocalDataStorage).data,
      contains('999999'),
    );
  });

  test('importar juntando: os dois lados ficam', () async {
    final other = make();
    final data = make();
    await data.import(other.currentFile(), merge: true);
    expect(await data.backend.fetchTrainers(), hasLength(2));
  });

  test('padrões: sem dados locais, e o file_picker para arquivos', () {
    final container = createContainer();
    expect(container.read(localDataProvider), isNull);
    expect(container.read(dataFileIoProvider), isA<FilePickerDataFileIo>());
  });

  group('FilePickerDataFileIo', () {
    late _FakePicker picker;

    setUp(() => FilePickerPlatform.instance = picker = _FakePicker());

    test('salvar oferece o JSON', () async {
      await FilePickerDataFileIo().save('x.json', Uint8List.fromList([1]));
      expect(picker.saved?.name, 'x.json');
      expect(picker.saved?.mime, 'application/json');
    });

    test('escolher devolve nome e conteúdo; desistir, null', () async {
      expect(await FilePickerDataFileIo().pick(), isNull);
      picker.picked = _MemoryFile('a.json', Uint8List.fromList([7]));
      final picked = await FilePickerDataFileIo().pick();
      expect(picked?.name, 'a.json');
      expect(picked?.bytes, [7]);
    });
  });
}
