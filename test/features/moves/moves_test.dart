import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/moves/data/moves_source.dart';
import 'package:ishinydex/features/moves/domain/moves_data.dart';
import 'package:ishinydex/features/moves/moves_providers.dart';

import '../../fixtures/catalog_fixture.dart';
import '../../fixtures/moves_fixture.dart';
import '../../helpers/helpers.dart';

const _catalogUrl = 'https://pages.example/ishinydex/catalog/catalog.json';
const _movesUrl =
    'https://pages.example/ishinydex/catalog/moves-2026.10.03.json';

Catalog _catalog({String? movesFile = 'moves-2026.10.03.json'}) =>
    Catalog.fromJson({
      ...catalogJson(),
      'movesFile': ?movesFile,
    }, spriteBase: 'https://sprites/');

/// Um download que não passa pela rede: o progresso dado e o texto.
class _Source extends MovesSource {
  _Source(this.result, {this.progress = const []}) : super(Dio(), _movesUrl);

  final Future<String> Function() result;
  final List<(int, int?)> progress;
  int calls = 0;

  @override
  Future<String> fetch(void Function(int received, int? total) onProgress) {
    calls++;
    for (final (received, total) in progress) {
      onProgress(received, total);
    }
    return result();
  }
}

void main() {
  group('MovesData', () {
    final data = MovesData.fromJson(movesJson());

    test('os jogos de cada Pokémon e o que ele aprende', () {
      expect(data.groupsOf(1), ['x-y', 'scarlet-violet', 'champions']);
      expect(data.groupsOf(999), isEmpty);
      final sv = data.learnset(1, 'scarlet-violet');
      expect(sv.map((l) => (l.move.label, l.method, l.level)).take(3), [
        ('Vine Whip', 'level-up', 3),
        ('Tackle', 'level-up', 1),
        ('Leech Seed', 'level-up', 1),
      ]);
      final seedBomb = sv[3];
      expect(seedBomb.machine, 'tm71');
      expect((seedBomb.machineKind, seedBomb.machineNumber), ('TM', 71));
      expect(data.learnset(1, 'x-y')[1].machine, 'tm86');
      // Sem o jogo ou sem o Pokémon, nada.
      expect(data.learnset(1, 'red-blue'), isEmpty);
      expect(data.learnset(999, 'x-y'), isEmpty);
      // Sem item da TM: só o tipo de máquina.
      final noItem = data.learnset(3, 'scarlet-violet').single;
      expect((noItem.machine, noItem.machineNumber), (null, null));
      expect(noItem.machineKind, 'TM');
      expect(
        const MoveLearn(
          move: MoveInfo(
            index: 0,
            name: 'x',
            label: 'X',
            type: 'normal',
            category: 'status',
            pp: 1,
          ),
          method: 'machine',
          level: 0,
          machine: 'tr12',
        ).machineKind,
        'TR',
      );
    });

    test('os dados do golpe e os valores de jogos antigos', () {
      final tackle = data.moves[3];
      expect(
        (tackle.name, tackle.label, tackle.type, tackle.category),
        ('tackle', 'Tackle', 'normal', 'physical'),
      );
      expect((tackle.power, tackle.accuracy, tackle.pp), (40, 100, 35));
      expect((tackle.target, tackle.effect), ('selected-pokemon', 'Hits.'));
      final order = {'x-y': 15, 'sun-moon': 17, 'scarlet-violet': 25};
      int orderOf(String g) => order[g] ?? 0;
      // No X/Y (antes do Sun/Moon), o valor antigo; o null é o atual.
      expect(tackle.statsIn('x-y', orderOf), (
        type: 'normal',
        power: 50,
        accuracy: 100,
        pp: 35,
      ));
      expect(tackle.statsIn('scarlet-violet', orderOf).power, 40);
      // Sem past nem campos opcionais.
      final vine = data.moves[4];
      expect((vine.priority, vine.target, vine.effect), (0, '', ''));
      expect(vine.past, isEmpty);
      expect(vine.statsIn('x-y', orderOf).power, 45);
    });
  });

  group('download', () {
    test('a fonte: o arquivo ao lado do catálogo', () {
      final container = createContainer(
        overrides: [
          envProvider.overrideWithValue(const Env(catalogUrl: _catalogUrl)),
          fakeBackendProvider.overrideWithValue(
            FakeBackend.fromCatalog(_catalog()),
          ),
        ],
      );
      expect(container.read(movesSourceProvider)?.url, _movesUrl);
      expect(container.read(movesDioProvider), isA<Dio>());
    });

    test('sem o arquivo no catálogo, ou sem catálogo: indisponível', () {
      for (final overrides in [
        [
          envProvider.overrideWithValue(const Env(catalogUrl: _catalogUrl)),
          fakeBackendProvider.overrideWithValue(
            FakeBackend.fromCatalog(_catalog(movesFile: null)),
          ),
        ],
        [envProvider.overrideWithValue(const Env())],
      ]) {
        final container = createContainer(overrides: overrides);
        expect(container.read(movesSourceProvider), isNull);
        expect(container.read(movesProvider), isA<MovesUnavailable>());
        container.read(movesProvider.notifier).retry();
        expect(container.read(movesProvider), isA<MovesUnavailable>());
      }
    });

    test('baixa com progresso, prepara e fica pronto', () async {
      final source = _Source(
        () async => jsonEncode(movesJson()),
        progress: const [(100, 1000), (500, null)],
      );
      final container = createContainer(
        overrides: [movesSourceProvider.overrideWithValue(source)],
      );
      final states = <MovesState>[];
      container.listen(
        movesProvider,
        (_, next) => states.add(next),
        fireImmediately: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(states.first, isA<MovesDownloading>());
      expect(
        [
          for (final s in states.whereType<MovesDownloading>().skip(1))
            (s.received, s.total),
        ],
        [(100, 1000), (500, null)],
      );
      expect(states.whereType<MovesPreparing>(), hasLength(1));
      final ready = states.last as MovesReady;
      expect(ready.data.moves, hasLength(5));
      // Uma vez só: ler de novo não baixa de novo.
      container.read(movesProvider);
      expect(source.calls, 1);
    });

    test('sem conexão: offline; tentar de novo baixa', () async {
      var fail = true;
      final source = _Source(() async {
        if (fail) {
          throw DioException(
            requestOptions: RequestOptions(path: _movesUrl),
            type: DioExceptionType.connectionTimeout,
          );
        }
        return jsonEncode(movesJson());
      });
      final container = createContainer(
        overrides: [movesSourceProvider.overrideWithValue(source)],
      )..listen(movesProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      expect((container.read(movesProvider) as MovesFailed).offline, true);

      fail = false;
      final notifier = container.read(movesProvider.notifier)..retry();
      expect(container.read(movesProvider), isA<MovesDownloading>());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(movesProvider), isA<MovesReady>());
      // Pronto: tentar de novo não faz nada.
      notifier.retry();
      expect(source.calls, 2);
    });

    test('outro erro (arquivo quebrado): falha sem ser offline', () async {
      final container = createContainer(
        overrides: [
          movesSourceProvider.overrideWithValue(_Source(() async => '{')),
        ],
      )..listen(movesProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect((container.read(movesProvider) as MovesFailed).offline, false);
    });

    test(
      'o MovesSource baixa o texto pelo Dio, com o total quando vem',
      () async {
        final dio = Dio();
        DioAdapter(dio: dio)
            .onGet(_movesUrl, (server) => server.reply(200, {'ok': 1}));
        final progress = <(int, int?)>[];
        final text = await MovesSource(
          dio,
          _movesUrl,
        ).fetch((r, t) => progress.add((r, t)));
        expect(jsonDecode(text), {'ok': 1});
      },
    );
  });
}
