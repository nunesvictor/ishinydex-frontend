import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/local/data/data_file_io.dart';
import 'package:ishinydex/features/local/data/local_store.dart';
import 'package:ishinydex/features/local/domain/data_merge.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/shiny_locks/shiny_lock_providers.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Dados do modo local (exportar/importar); `null` fora dele.
final localDataProvider = Provider<LocalData?>((ref) => null);

final dataFileIoProvider = Provider<DataFileIo>(
  (ref) => FilePickerDataFileIo(),
);

/// Resumo de um arquivo de dados, mostrado antes de importar.
typedef DataFileSummary = ({
  int dexes,
  int specimens,
  int saves,
  DateTime savedAt,
});

/// O arquivo de dados do aparelho: exportar e importar (substituindo ou
/// juntando). O sync vai usar o mesmo caminho.
class LocalData {
  LocalData({
    required this.store,
    required this.backend,
    required this.catalogVersion,
  });

  final LocalStore store;
  final FakeBackend backend;
  final String catalogVersion;

  /// Chamado quando os dados do aparelho mudam e são gravados (edição ou
  /// importação); o sync usa para enviar as mudanças.
  void Function()? onChanged;

  /// Grava, se algo mudou desde a última gravação, e avisa [onChanged].
  Future<void> save() async {
    if (await store.save(backend.records, catalog: catalogVersion)) {
      onChanged?.call();
    }
  }

  /// O arquivo atual, com as datas em dia.
  Map<String, dynamic> currentFile() =>
      store.file(backend.records, catalog: catalogVersion);

  /// Nome e conteúdo do arquivo para baixar: `ishinydex-AAAA-MM-DD.json`.
  ({String name, Uint8List bytes}) export({DateTime? today}) {
    final day = (today ?? DateTime.now()).toIso8601String().substring(0, 10);
    return (
      name: 'ishinydex-$day.json',
      bytes: utf8.encode(jsonEncode(currentFile())),
    );
  }

  /// Lê e valida um arquivo escolhido ([FormatException] se não servir).
  static Map<String, dynamic> read(Uint8List bytes) {
    final String raw;
    try {
      raw = utf8.decode(bytes);
    } on FormatException {
      throw const FormatException('Não é um arquivo de dados do iShinyDex.');
    }
    return LocalStore.parse(raw);
  }

  static DataFileSummary summarize(Map<String, dynamic> file) {
    final records = file['records'] as Map<String, dynamic>;
    int count(String type) => (records[type] as List?)?.length ?? 0;
    return (
      dexes: count('dexes'),
      specimens: count('specimens'),
      saves: count('saves'),
      savedAt: DateTime.parse(file['savedAt'] as String).toLocal(),
    );
  }

  /// Passa a usar [file] (ou a junção dele com os dados do aparelho, com
  /// [merge]) e grava. [notify]: avisar [onChanged] (o sync, que também
  /// importa, não precisa ser avisado do que ele mesmo fez).
  Future<void> import(
    Map<String, dynamic> file, {
    required bool merge,
    bool notify = true,
  }) async {
    final next = merge ? mergeDataFiles(currentFile(), file) : file;
    backend.replaceRecords(store.adopt(next));
    await store.save(backend.records, catalog: catalogVersion);
    if (notify) onChanged?.call();
  }
}

final localDataActionsProvider = Provider<LocalDataActions>(
  LocalDataActions.new,
);

/// Exportar e importar a partir da interface (Ajustes).
class LocalDataActions {
  LocalDataActions(this._ref);

  final Ref _ref;

  LocalData get _data => _ref.read(localDataProvider)!;

  /// Baixa o arquivo; devolve o nome dele.
  Future<String> export() async {
    final file = _data.export();
    await _ref.read(dataFileIoProvider).save(file.name, file.bytes);
    return file.name;
  }

  /// Escolhe e valida um arquivo ([FormatException] se não servir);
  /// `null` se a pessoa desistir.
  Future<({String name, Map<String, dynamic> file})?> pick() async {
    final picked = await _ref.read(dataFileIoProvider).pick();
    if (picked == null) return null;
    return (name: picked.name, file: LocalData.read(picked.bytes));
  }

  /// Importa e recarrega tudo que a tela mostra ([notify]: ver
  /// [LocalData.import]).
  Future<void> import(
    Map<String, dynamic> file, {
    required bool merge,
    bool notify = true,
  }) async {
    await _data.import(file, merge: merge, notify: notify);
    _ref.read(slotActionsProvider).specimensChanged();
    _ref
      ..invalidate(trainersProvider)
      ..invalidate(savesProvider)
      ..invalidate(shinyLocksProvider)
      ..invalidate(linkPreviewProvider)
      ..invalidate(formSlotsProvider)
      ..invalidate(slotSearchProvider)
      ..invalidate(availableSpecimensProvider)
      ..invalidate(dexPreviewProvider);
  }
}
