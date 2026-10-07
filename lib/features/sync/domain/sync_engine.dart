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
    this.maxAttempts = 3,
  });

  final DropboxClient client;
  final SyncTarget target;
  final int maxAttempts;

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
      final local = target.currentFile();
      if (remoteFile != null && sameData(local, remoteFile)) {
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
