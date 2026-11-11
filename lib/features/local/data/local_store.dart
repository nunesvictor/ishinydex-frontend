import 'dart:async';
import 'dart:convert';

import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/features/local/data/local_data_storage.dart';

/// Registros canônicos por tipo (`dexes`, `specimens`...), como o
/// `FakeBackend.records`.
typedef Records = Map<String, List<Map<String, dynamic>>>;

/// O arquivo de dados do modo local, que é também o formato do
/// exportar/importar e do sync:
///
/// ```json
/// {"schemaVersion": 7, "kind": "ishinydex-data", "catalog": "...",
///  "savedAt": "...", "records": {"specimens": [{..., "updatedAt": "..."}]},
///  "deleted": {"specimens": {"123": "..."}},
///  "devices": {"<aparelho>": "..."}, "arrived": {"specimens": {"123": "..."}}}
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

  /// Maior `schemaVersion` que este app sabe ler, e o que ele grava. O 2
  /// trouxe o registro da caçada no espécime (frontend#163): um app antigo
  /// leria o arquivo, descartaria o campo ao regravar e, pelo sync, apagaria
  /// o registro; com o 2 ele recusa o arquivo. O 3 trouxe o Shiny Charm do
  /// save e as odds das caçadas (v2.9.0), pelo mesmo motivo. O 4 trouxe a
  /// receita do dex (de onde ele nasceu, #34), também pelo mesmo motivo. O 5
  /// trouxe a marca de origem escolhida do espécime (#360), pelo mesmo
  /// motivo. O 6 trouxe os times do team builder (#231): um app antigo
  /// descartaria os `teams` ao regravar. O 7 trouxe a limpeza das exclusões
  /// (#393): um app antigo descartaria o `devices` e o `arrived` e, sem eles,
  /// a limpeza apagaria marcas que ele ainda não recebeu. Os anteriores são
  /// lidos; o "veio do GO" de antes do 5 passa para o GO como jogo ao
  /// carregar (`migrateGoRecords`).
  static const schemaVersion = 7;
  static const kind = 'ishinydex-data';

  final LocalDataStorage storage;
  final DateTime Function() _now;

  /// Último estado conhecido: tipo → id → (registro em JSON, updatedAt).
  final _stamps = <String, Map<int, ({String json, String updatedAt})>>{};

  /// Exclusões: tipo → id → data.
  final deleted = <String, Map<String, String>>{};

  /// O último sync de cada aparelho (#393): id do aparelho → data.
  final synced = <String, String>{};

  /// Quando cada exclusão chegou ao Dropbox (#393): tipo → id → data.
  final arrived = <String, Map<String, String>>{};

  /// Um aparelho sem sync há mais que isso deixa de contar na limpeza das
  /// exclusões; sem Dropbox, é a idade em que a exclusão some.
  static const inactiveAfter = Duration(days: 183);

  /// A exclusão fica pelo menos isso depois de chegar ao Dropbox: cobre o
  /// aparelho que ainda não sincronizou com esta versão (fora de [synced]).
  static const keepAtLeast = Duration(days: 30);

  /// Lê o arquivo salvo e devolve os registros (sem as datas) para
  /// restaurar o backend; vazio num aparelho novo. Formato mais novo que o
  /// do app → [DataFailure].
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
      throw const DataFailure(Problem.notADataFile());
    }
    if (file is! Map<String, dynamic> || file['kind'] != kind) {
      throw const DataFailure(Problem.notADataFile());
    }
    if ((file['schemaVersion'] as int) > schemaVersion) {
      throw const DataFailure(Problem.dataFromNewerApp());
    }
    return file;
  }

  /// Passa a considerar [file] o último estado salvo (datas e exclusões) e
  /// devolve os registros dele, sem as datas.
  Records adopt(Map<String, dynamic> file) {
    _stamps.clear();
    deleted.clear();
    synced
      ..clear()
      ..addAll(
        ((file['devices'] as Map<String, dynamic>?) ?? const {})
            .cast<String, String>(),
      );
    arrived.clear();
    for (final MapEntry(key: type, value: ids)
        in ((file['arrived'] as Map<String, dynamic>?) ?? const {}).entries) {
      arrived[type] = {...(ids as Map<String, dynamic>).cast<String, String>()};
    }
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
    _dropDuplicateShinyLocks(records);
    _dropEmptySlots(records);
    _dropCellConflicts(records);
    return records;
  }

  /// Shiny locks repetidos viram um só (frontend#357): cada aparelho novo
  /// criava os locks padrão com ids próprios, e juntar os dados no sync
  /// somava as cópias. Iguais = mesmo nome, tipo e formas; fica o mudado
  /// por último (no empate, o de menor id, para todo aparelho escolher o
  /// mesmo) e os outros viram exclusão, que o sync leva adiante.
  void _dropDuplicateShinyLocks(Records records) {
    final locks = records['shinyLocks'];
    if (locks == null) return;
    final stamps = _stamps['shinyLocks']!;
    final best = <String, Map<String, dynamic>>{};
    for (final lock in locks) {
      final key = jsonEncode([
        lock['caption'],
        lock['lockType'],
        [...(lock['forms'] as List).cast<int>()]..sort(),
      ]);
      final kept = best[key];
      if (kept == null || _ranksAbove(lock, kept, stamps)) best[key] = lock;
    }
    if (best.length == locks.length) return;
    final now = _now().toUtc().toIso8601String();
    final keep = best.values.toSet();
    for (final lock in locks.where((l) => !keep.contains(l))) {
      final id = lock['id'] as int;
      stamps.remove(id);
      (deleted['shinyLocks'] ??= {})['$id'] = now;
    }
    locks.retainWhere(keep.contains);
  }

  /// Os slots vazios (sem dex, forma ou espécime) saem do arquivo (#392): o
  /// backend os recria. Os do arquivo do schema 6 somem sem exclusão, porque
  /// a ausência já quer dizer vazio.
  void _dropEmptySlots(Records records) {
    final slots = records['slots'];
    if (slots == null) return;
    final stamps = _stamps['slots']!;
    slots.removeWhere((slot) {
      final empty =
          slot['dex'] == null &&
          slot['form'] == null &&
          slot['specimen'] == null;
      if (empty) stamps.remove(slot['id'] as int);
      return empty;
    });
  }

  /// Dois registros para a mesma célula (#392: dois aparelhos ocuparam a
  /// célula com ids diferentes): fica o mudado por último (no empate, o de
  /// menor id), e os outros viram exclusão; o espécime deles volta ao
  /// inventário.
  void _dropCellConflicts(Records records) {
    final slots = records['slots'];
    if (slots == null) return;
    final stamps = _stamps['slots']!;
    final best = <String, Map<String, dynamic>>{};
    for (final slot in slots) {
      final key = '${slot['box']}:${slot['row']}:${slot['col']}';
      final kept = best[key];
      if (kept == null || _ranksAbove(slot, kept, stamps)) best[key] = slot;
    }
    if (best.length == slots.length) return;
    final now = _now().toUtc().toIso8601String();
    final keep = best.values.toSet();
    for (final slot in slots.where((s) => !keep.contains(s))) {
      final id = slot['id'] as int;
      stamps.remove(id);
      (deleted['slots'] ??= {})['$id'] = now;
    }
    slots.retainWhere(keep.contains);
  }

  static bool _ranksAbove(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
    Map<int, ({String json, String updatedAt})> stamps,
  ) {
    final ida = a['id'] as int;
    final idb = b['id'] as int;
    final byDate = stamps[ida]!.updatedAt.compareTo(stamps[idb]!.updatedAt);
    return byDate > 0 || (byDate == 0 && ida < idb);
  }

  /// O sync do aparelho [device] em [at] (#393): marca a data dele, a data
  /// em que as exclusões novas chegaram ao Dropbox (este sync as envia) e
  /// apaga as que todos os aparelhos ativos já receberam: chegaram há mais
  /// de [keepAtLeast] e antes do último sync de cada um. Quem não sincroniza
  /// há mais de [inactiveAfter] deixa de contar.
  void markSynced(String device, DateTime at) {
    final now = _iso(at);
    synced[device] = now;
    for (final MapEntry(key: type, value: ids) in deleted.entries) {
      final seen = arrived[type] ??= {};
      for (final id in ids.keys) {
        seen.putIfAbsent(id, () => now);
      }
    }
    final active = _iso(at.subtract(inactiveAfter));
    synced.removeWhere((_, date) => date.compareTo(active) < 0);
    final floor = _iso(at.subtract(keepAtLeast));
    final horizon = synced.values.fold(
      floor,
      (oldest, date) => date.compareTo(oldest) < 0 ? date : oldest,
    );
    for (final MapEntry(key: type, value: ids) in deleted.entries) {
      final seen = arrived[type]!;
      ids.removeWhere((id, _) => seen[id]!.compareTo(horizon) < 0);
    }
  }

  static String _iso(DateTime date) => date.toUtc().toIso8601String();

  /// Sem sync (#393): as exclusões com mais de [inactiveAfter] somem; só
  /// servem para o "Importar → Juntar".
  void _dropOldWithoutSync() {
    if (synced.isNotEmpty) return;
    final limit = _iso(_now().subtract(inactiveAfter));
    for (final ids in deleted.values) {
      ids.removeWhere((_, date) => date.compareTo(limit) < 0);
    }
  }

  /// As datas de chegada só das exclusões que existem.
  Map<String, Map<String, String>> get _arrivedNow => {
    for (final MapEntry(key: type, value: ids) in arrived.entries)
      type: {
        for (final MapEntry(:key, :value) in ids.entries)
          if (deleted[type]?.containsKey(key) ?? false) key: value,
      },
  };

  /// O arquivo com os [records] atuais, carimbando o que mudou desde o
  /// último [file] (ver a classe).
  Map<String, dynamic> file(Records records, {required String catalog}) {
    final now = _now().toUtc().toIso8601String();
    _dropOldWithoutSync();
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
            arrived[type]?.remove('$id');
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
      'devices': {...synced},
      'arrived': _arrivedNow,
    };
  }

  /// Último JSON gravado; evita regravar quando nada mudou.
  String? _lastRecords;

  /// Grava o arquivo se algum registro mudou desde a última gravação.
  /// Devolve se gravou.
  /// Com [force], grava mesmo sem mudança nos registros (o sync mudou as
  /// exclusões ou as datas dos aparelhos).
  Future<bool> save(
    Records records, {
    required String catalog,
    bool force = false,
  }) async {
    final current = jsonEncode(records);
    if (current == _lastRecords && !force) return false;
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
