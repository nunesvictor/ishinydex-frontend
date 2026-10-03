/// Junta dois arquivos de dados (`LocalStore`): o do aparelho e outro
/// (importado, ou o do Dropbox no sync).
///
/// Registro a registro, vale a versão com o `updatedAt` mais recente; em
/// empate, a do [incoming]. Uma exclusão vence quando é mais nova que a
/// última mudança do registro nos dois lados; senão o registro fica (alguém
/// o mudou depois de outro aparelho apagá-lo). Datas em ISO 8601 UTC
/// comparam como texto.
Map<String, dynamic> mergeDataFiles(
  Map<String, dynamic> local,
  Map<String, dynamic> incoming,
) {
  Map<String, Map<String, Map<String, dynamic>>> recordsOf(
    Map<String, dynamic> file,
  ) => {
    for (final MapEntry(key: type, value: list)
        in (file['records'] as Map<String, dynamic>).entries)
      type: {
        for (final record in (list as List).cast<Map<String, dynamic>>())
          '${record['id']}': record,
      },
  };
  Map<String, Map<String, String>> deletedOf(Map<String, dynamic> file) => {
    for (final MapEntry(key: type, value: ids)
        in (file['deleted'] as Map<String, dynamic>).entries)
      type: (ids as Map<String, dynamic>).cast<String, String>(),
  };

  final mine = recordsOf(local);
  final theirs = recordsOf(incoming);
  final deletedMine = deletedOf(local);
  final deletedTheirs = deletedOf(incoming);

  final records = <String, List<Map<String, dynamic>>>{};
  final deleted = <String, Map<String, String>>{};
  final types = {
    ...mine.keys,
    ...theirs.keys,
    ...deletedMine.keys,
    ...deletedTheirs.keys,
  };
  for (final type in types) {
    final a = mine[type] ?? const <String, Map<String, dynamic>>{};
    final b = theirs[type] ?? const <String, Map<String, dynamic>>{};
    final gone = <String, String>{};
    for (final source in [deletedMine[type], deletedTheirs[type]]) {
      for (final MapEntry(key: id, value: at)
          in (source ?? const <String, String>{}).entries) {
        final known = gone[id];
        if (known == null || at.compareTo(known) > 0) gone[id] = at;
      }
    }
    final kept = <Map<String, dynamic>>[];
    for (final id in {...a.keys, ...b.keys}) {
      final x = a[id];
      final y = b[id];
      final Map<String, dynamic> winner;
      if (x == null) {
        winner = y!;
      } else if (y == null) {
        winner = x;
      } else {
        winner = _at(x).compareTo(_at(y)) > 0 ? x : y;
      }
      final deletedAt = gone[id];
      if (deletedAt != null && deletedAt.compareTo(_at(winner)) >= 0) {
        continue;
      }
      gone.remove(id);
      kept.add(winner);
    }
    records[type] = kept;
    deleted[type] = gone;
  }
  return {
    ...incoming,
    'savedAt': [
      local['savedAt'] as String,
      incoming['savedAt'] as String,
    ].reduce((a, b) => a.compareTo(b) > 0 ? a : b),
    'records': records,
    'deleted': deleted,
  };
}

String _at(Map<String, dynamic> record) => record['updatedAt'] as String;
