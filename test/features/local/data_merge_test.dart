import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/features/local/domain/data_merge.dart';

Map<String, dynamic> _file({
  List<Map<String, dynamic>> specimens = const [],
  Map<String, String> deleted = const {},
  String savedAt = '2026-10-01T00:00:00.000Z',
}) => {
  'schemaVersion': 1,
  'kind': 'ishinydex-data',
  'catalog': 'catalog-x',
  'savedAt': savedAt,
  'records': {'specimens': specimens},
  'deleted': {'specimens': deleted},
};

Map<String, dynamic> _rec(int id, String nick, String at) => {
  'id': id,
  'nickname': nick,
  'updatedAt': at,
};

const _d1 = '2026-10-01T00:00:00.000Z';
const _d2 = '2026-10-02T00:00:00.000Z';
const _d3 = '2026-10-03T00:00:00.000Z';

List<String> _names(Map<String, dynamic> file) => [
  for (final r
      in ((file['records'] as Map)['specimens'] as List)
          .cast<Map<String, dynamic>>())
    '${r['id']}:${r['nickname']}',
];

Map<String, String> _deleted(Map<String, dynamic> file) =>
    ((file['deleted'] as Map)['specimens'] as Map).cast<String, String>();

void main() {
  test('vale a mudança mais recente; só de um lado, entra', () {
    final merged = mergeDataFiles(
      _file(specimens: [_rec(1, 'velho', _d1), _rec(2, 'só aqui', _d1)]),
      _file(
        specimens: [_rec(1, 'novo', _d2), _rec(3, 'só lá', _d1)],
        savedAt: _d3,
      ),
    );
    expect(_names(merged), ['1:novo', '2:só aqui', '3:só lá']);
    expect(merged['savedAt'], _d3);
  });

  test('o mais recente vence dos dois lados; empate, o que chega', () {
    expect(
      _names(
        mergeDataFiles(
          _file(specimens: [_rec(1, 'aqui', _d2)], savedAt: _d3),
          _file(specimens: [_rec(1, 'lá', _d1)]),
        ),
      ),
      ['1:aqui'],
    );
    expect(
      _names(
        mergeDataFiles(
          _file(specimens: [_rec(1, 'aqui', _d1)]),
          _file(specimens: [_rec(1, 'lá', _d1)]),
        ),
      ),
      ['1:lá'],
    );
  });

  test('exclusão mais nova apaga; mudança mais nova sobrevive', () {
    final apagado = mergeDataFiles(
      _file(specimens: [_rec(1, 'a', _d1)]),
      _file(deleted: {'1': _d2}),
    );
    expect(_names(apagado), isEmpty);
    expect(_deleted(apagado), {'1': _d2});

    final mudouDepois = mergeDataFiles(
      _file(specimens: [_rec(1, 'a', _d3)]),
      _file(deleted: {'1': _d2}),
    );
    expect(_names(mudouDepois), ['1:a']);
    expect(_deleted(mudouDepois), isEmpty);
  });

  test('marcas dos dois lados: fica a mais recente', () {
    final merged = mergeDataFiles(
      _file(deleted: {'9': _d1}),
      _file(deleted: {'9': _d2, '8': _d1}),
    );
    expect(_deleted(merged), {'9': _d2, '8': _d1});
  });

  test('substituir: fica o arquivo, e o que só havia aqui vira exclusão', () {
    final replaced = replaceDataFile(
      _file(
        specimens: [_rec(1, 'aqui', _d1), _rec(2, 'teste', _d2)],
        savedAt: _d3,
      ),
      _file(specimens: [_rec(1, 'arquivo', _d1)], deleted: {'9': _d1}),
    );
    expect(_names(replaced), ['1:arquivo']);
    expect(_deleted(replaced), {'9': _d1, '2': _d3});
    expect(replaced['savedAt'], _d1);

    // No sync, o registro substituído some também do outro lado.
    final other = _file(specimens: [_rec(2, 'teste', _d2)]);
    expect(_names(mergeDataFiles(other, replaced)), ['1:arquivo']);
  });

  test('substituir: tipos que o arquivo não traz também são apagados', () {
    final replaced = replaceDataFile(
      {
        ..._file(savedAt: _d3),
        'records': {
          'trainers': [
            {'id': 5, 'updatedAt': _d1},
          ],
        },
      },
      {..._file(), 'deleted': <String, dynamic>{}},
    );
    expect(replaced['deleted'], {
      'trainers': {'5': _d3},
    });
  });
}
