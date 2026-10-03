import 'dart:async';
import 'dart:convert';

import 'package:ishinydex/features/local/data/local_data_storage.dart';

/// Registros canônicos por tipo (`dexes`, `specimens`...), como o
/// `FakeBackend.records`.
typedef Records = Map<String, List<Map<String, dynamic>>>;

/// O arquivo de dados do modo local, que é também o formato do
/// exportar/importar e do sync:
///
/// ```json
/// {"schemaVersion": 1, "kind": "ishinydex-data", "catalog": "...",
///  "savedAt": "...", "records": {"specimens": [{..., "updatedAt": "..."}]},
///  "deleted": {"specimens": {"123": "..."}}}
/// ```
///
/// As datas nascem por comparação: a cada [save], cada registro é comparado
/// com o último estado salvo. Novo ou alterado ganha `updatedAt`; sumido
/// vira marca em `deleted`. Assim nenhuma regra do app precisa saber de
/// persistência, e o sync tem a data de cada registro para juntar dois
/// aparelhos.
class LocalStore {
  LocalStore(this.storage, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// Maior `schemaVersion` que este app sabe ler.
  static const schemaVersion = 1;
  static const kind = 'ishinydex-data';

  final LocalDataStorage storage;
  final DateTime Function() _now;

  /// Último estado conhecido: tipo → id → (registro em JSON, updatedAt).
  final _stamps = <String, Map<int, ({String json, String updatedAt})>>{};

  /// Exclusões: tipo → id → data.
  final deleted = <String, Map<String, String>>{};

  /// Lê o arquivo salvo e devolve os registros (sem as datas) para
  /// restaurar o backend; vazio num aparelho novo. Formato mais novo que o
  /// do app → [FormatException].
  Future<Records> load() async {
    final raw = await storage.read();
    if (raw == null) return const {};
    return adopt(parse(raw));
  }

  /// Valida um arquivo de dados (salvo, importado ou do sync).
  static Map<String, dynamic> parse(String raw) {
    final Object? file;
    try {
      file = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('Não é um arquivo de dados do iShinyDex.');
    }
    if (file is! Map<String, dynamic> || file['kind'] != kind) {
      throw const FormatException('Não é um arquivo de dados do iShinyDex.');
    }
    if ((file['schemaVersion'] as int) > schemaVersion) {
      throw const FormatException(
        'Os dados foram salvos por uma versão mais nova do app.',
      );
    }
    return file;
  }

  /// Passa a considerar [file] o último estado salvo (datas e exclusões) e
  /// devolve os registros dele, sem as datas.
  Records adopt(Map<String, dynamic> file) {
    _stamps.clear();
    deleted.clear();
    _lastRecords = null;
    final records = <String, List<Map<String, dynamic>>>{};
    for (final MapEntry(key: type, value: list)
        in (file['records'] as Map<String, dynamic>).entries) {
      final stamps = _stamps[type] = {};
      records[type] = [
        for (final item in (list as List).cast<Map<String, dynamic>>())
          () {
            final record = {...item}..remove('updatedAt');
            stamps[record['id'] as int] = (
              json: jsonEncode(record),
              updatedAt: item['updatedAt'] as String,
            );
            return record;
          }(),
      ];
    }
    for (final MapEntry(key: type, value: ids)
        in (file['deleted'] as Map<String, dynamic>).entries) {
      deleted[type] = {...(ids as Map<String, dynamic>).cast<String, String>()};
    }
    return records;
  }

  /// O arquivo com os [records] atuais, carimbando o que mudou desde o
  /// último [file] (ver a classe).
  Map<String, dynamic> file(Records records, {required String catalog}) {
    final now = _now().toUtc().toIso8601String();
    final out = <String, List<Map<String, dynamic>>>{};
    for (final MapEntry(key: type, value: list) in records.entries) {
      final before = _stamps[type] ?? const {};
      final after = <int, ({String json, String updatedAt})>{};
      out[type] = [
        for (final record in list)
          () {
            final id = record['id'] as int;
            final json = jsonEncode(record);
            final old = before[id];
            final stamp = old != null && old.json == json ? old.updatedAt : now;
            after[id] = (json: json, updatedAt: stamp);
            deleted[type]?.remove('$id');
            return {...record, 'updatedAt': stamp};
          }(),
      ];
      for (final id in before.keys) {
        if (!after.containsKey(id)) (deleted[type] ??= {})['$id'] = now;
      }
      _stamps[type] = after;
    }
    return {
      'schemaVersion': schemaVersion,
      'kind': kind,
      'catalog': catalog,
      'savedAt': now,
      'records': out,
      'deleted': deleted,
    };
  }

  /// Último JSON gravado; evita regravar quando nada mudou.
  String? _lastRecords;

  /// Grava o arquivo se algum registro mudou desde a última gravação.
  /// Devolve se gravou.
  Future<bool> save(Records records, {required String catalog}) async {
    final current = jsonEncode(records);
    if (current == _lastRecords) return false;
    await storage.write(jsonEncode(file(records, catalog: catalog)));
    _lastRecords = current;
    return true;
  }
}

/// Agenda uma gravação [delay] depois do último uso; usos seguidos
/// adiam (uma gravação para uma rajada de mudanças).
class SaveScheduler {
  SaveScheduler({required this.delay, required this.save});

  final Duration delay;
  final Future<void> Function() save;
  Timer? _timer;

  void schedule() {
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(save()));
  }
}
