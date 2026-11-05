import 'dart:convert';

import 'package:ishinydex/features/local/data/local_store.dart';
import 'package:ishinydex/features/sync/data/dropbox_client.dart';

/// Os dados do aparelho, do ponto de vista do sync (em produção, o
/// exportar/importar de Ajustes, que já recarrega as telas).
abstract interface class SyncTarget {
  /// O arquivo de dados atual (formato do `LocalStore`).
  Map<String, dynamic> currentFile();

  /// Passa a usar [file], ou a junção dele com os dados do aparelho
  /// ([merge]: vale a mudança mais recente de cada registro).
  Future<void> apply(Map<String, dynamic> file, {required bool merge});

  /// O aparelho [device] sincronizou em [at]: marca as datas e limpa as
  /// exclusões que todos já receberam (#393).
  Future<void> markSynced(String device, DateTime at);
}

/// Primeira conexão com dados nos dois lados: o que fazer com eles.
enum FirstSync {
  /// Juntar os dois (o padrão, e o de todo sync depois do primeiro).
  merge,

  /// Usar só os do Dropbox: os do aparelho são substituídos.
  useRemote,

  /// Usar só os do aparelho: o arquivo do Dropbox é substituído.
  useLocal,
}

/// O que um sync fez: se os dados do aparelho mudaram (vieram mudanças de
/// outro aparelho) e se o Dropbox recebeu um arquivo novo.
typedef SyncResult = ({bool pulled, bool pushed});

/// Um sync: baixa o arquivo do Dropbox, junta com os dados do aparelho e
/// envia o resultado, só se algo mudou. O envio é condicional à versão
/// baixada: se outro aparelho enviou no meio, recomeça (até [maxAttempts]
/// vezes), e nada se perde.
class SyncEngine {
  SyncEngine({
    required this.client,
    required this.target,
    required this.device,
    this.maxAttempts = 3,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final DropboxClient client;
  final SyncTarget target;

  /// O id deste aparelho, para a limpeza das exclusões (#393).
  final String device;
  final int maxAttempts;
  final DateTime Function() _now;

  Future<SyncResult> sync({FirstSync mode = FirstSync.merge}) async {
    var current = mode;
    var pulled = false;
    for (var attempt = 1; ; attempt++) {
      final remote = await client.download();
      final remoteFile = remote == null
          ? null
          : LocalStore.parse(utf8.decode(remote.bytes));
      final before = target.currentFile();
      if (remoteFile != null &&
          current != FirstSync.useLocal &&
          !sameData(before, remoteFile)) {
        await target.apply(remoteFile, merge: current == FirstSync.merge);
        // O Dropbox pode diferir só por não ter as mudanças daqui: juntar
        // não muda nada neste aparelho, e isso não conta como recebido.
        if (!sameData(before, target.currentFile())) pulled = true;
      }
      // Depois de juntar com o do Dropbox: as exclusões daqui chegam lá
      // neste envio, e as que todos já receberam somem.
      final now = _now();
      await target.markSynced(device, now);
      final local = target.currentFile();
      if (remoteFile != null &&
          sameData(local, remoteFile) &&
          _seenRecently(remoteFile, now)) {
        return (pulled: pulled, pushed: false);
      }
      try {
        await client.upload(
          utf8.encode(jsonEncode(local)),
          rev: remote?.rev,
          overwrite: current == FirstSync.useLocal,
        );
        return (pulled: pulled, pushed: true);
      } on DropboxConflictException {
        if (attempt >= maxAttempts) rethrow;
        // Outro aparelho enviou antes: na próxima volta, junta com o dele.
        current = FirstSync.merge;
      }
    }
  }

  /// O Dropbox sabe que este aparelho sincronizou há menos de [refreshEvery]:
  /// sem isso, envia mesmo sem mudança, para os outros aparelhos não o
  /// acharem parado e não segurarem as exclusões por ele (#393).
  bool _seenRecently(Map<String, dynamic> remote, DateTime now) {
    final at = (remote['devices'] as Map<String, dynamic>?)?[device] as String?;
    return at != null &&
        now.difference(DateTime.parse(at)) < SyncEngine.refreshEvery;
  }

  /// De quanto em quanto tempo o aparelho avisa o Dropbox que está ativo.
  static const refreshEvery = Duration(days: 1);

  /// Os mesmos registros e exclusões, sem olhar a ordem (cada lado lista
  /// os registros numa ordem) nem `savedAt` e `catalog`.
  static bool sameData(Map<String, dynamic> a, Map<String, dynamic> b) =>
      _canonical(a) == _canonical(b);

  static String _canonical(Map<String, dynamic> file) {
    // Chaves em ordem alfabética, em qualquer profundidade; listas dentro
    // dos registros mantêm a ordem (ela faz parte do dado).
    Object? sortKeys(Object? value) => switch (value) {
      final Map<String, dynamic> map => {
        for (final key in map.keys.toList()..sort()) key: sortKeys(map[key]),
      },
      final List<dynamic> list => list.map(sortKeys).toList(),
      _ => value,
    };
    final records = file['records'] as Map<String, dynamic>;
    return jsonEncode({
      'records': {
        for (final type in records.keys.toList()..sort())
          type: [
            for (final record
                in (records[type] as List).cast<Map<String, dynamic>>().toList()
                  ..sort((x, y) => (x['id'] as int).compareTo(y['id'] as int)))
              sortKeys(record),
          ],
      },
      'deleted': sortKeys(file['deleted']),
    });
  }
}
