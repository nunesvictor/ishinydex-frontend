import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/features/personal_dex/data/http_personal_dex_repository.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';

import '../../fixtures/api_fixtures.dart';

void main() {
  late DioAdapter adapter;
  late HttpPersonalDexRepository repository;

  setUp(() {
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api/'));
    adapter = DioAdapter(dio: dio);
    repository = HttpPersonalDexRepository(dio);
  });

  test('fetchDexes percorre todas as páginas', () async {
    adapter
      ..onGet(
        'personal-dexes/',
        (server) => server.reply(200, {
          ...dexPageJson,
          'next': 'http://test/api/personal-dexes/?page=2',
        }),
        queryParameters: {'page': 1, 'page_size': 100},
      )
      ..onGet(
        'personal-dexes/',
        (server) => server.reply(200, {
          ...dexPageJson,
          'results': [
            {...dexJson, 'id': 2},
          ],
        }),
        queryParameters: {'page': 2, 'page_size': 100},
      );
    final dexes = await repository.fetchDexes();
    expect(dexes.map((d) => d.id), [1, 2]);
  });

  test('fetchDex e 404', () async {
    adapter
      ..onGet('personal-dexes/1/', (server) => server.reply(200, dexJson))
      ..onGet(
        'personal-dexes/9/',
        (server) => server.reply(404, {'detail': 'Não encontrado.'}),
      );
    expect((await repository.fetchDex(1)).name, 'Shiny Living Dex');
    expect(repository.fetchDex(9), throwsA(isA<NotFoundFailure>()));
  });

  test('fetchBoxes e fetchSlots', () async {
    adapter
      ..onGet(
        'personal-dexes/1/boxes/',
        (server) => server.reply(200, boxesJson),
      )
      ..onGet(
        'slots/',
        (server) => server.reply(200, [registeredSlotJson, missingSlotJson]),
        queryParameters: {'personal_dex': 1, 'box': 1},
      );
    expect(await repository.fetchBoxes(1), hasLength(2));
    final slots = await repository.fetchSlots(dexId: 1, boxId: 1);
    expect(slots.map((s) => s.isRegistered), [true, false]);
  });

  test('deposit e erro de validação', () async {
    adapter
      ..onPost(
        'slots/20/deposit/',
        (server) => server.reply(200, registeredSlotJson),
        data: {'specimen_id': 5},
      )
      ..onPost(
        'slots/20/deposit/',
        (server) => server.reply(400, {
          'specimen_id': ['Forma diferente.'],
        }),
        data: {'specimen_id': 6},
      );
    expect(
      (await repository.deposit(slotId: 20, specimenId: 5)).isRegistered,
      true,
    );
    expect(
      repository.deposit(slotId: 20, specimenId: 6),
      throwsA(
        isA<ValidationFailure>().having(
          (f) => f.errorFor('specimen_id'),
          'specimen_id',
          'Forma diferente.',
        ),
      ),
    );
  });

  test('fetchSlot', () async {
    adapter.onGet(
      'slots/1/',
      (server) => server.reply(200, registeredSlotJson),
    );
    expect((await repository.fetchSlot(1)).isRegistered, true);
  });

  test('searchSlots', () async {
    adapter.onGet(
      'slots/',
      (server) => server.reply(200, {
        'count': 1,
        'next': null,
        'previous': null,
        'results': [registeredSlotJson],
      }),
      queryParameters: {'personal_dex': 1, 'search': 'bulba', 'page_size': 30},
    );
    expect(
      (await repository.searchSlots(dexId: 1, search: ' bulba ')).single.id,
      1,
    );
  });

  test('fetchGenerations', () async {
    adapter.onGet(
      'personal-dexes/1/generations/',
      (server) => server.reply(200, [
        {
          'generation': 'generation-i',
          'total': 151,
          'registered': 140,
          'first_box': {'id': 1, 'name': 'HOME 1', 'position': 1},
        },
      ]),
    );
    final gens = await repository.fetchGenerations(1);
    expect(gens.single.label, 'Geração I');
    expect(gens.single.firstBox.name, 'HOME 1');
  });

  test('previewNewDex e createDex', () async {
    adapter
      ..onGet(
        'personal-dexes/preview/',
        (server) => server.reply(200, {
          'forms': 1227,
          'boxes_needed': 45,
          'largest_free_run': 150,
          'enough_space': true,
          'first_box': {'id': 50, 'name': 'HOME 50', 'position': 50},
        }),
        queryParameters: {'force_new_box': true},
      )
      ..onPost(
        'personal-dexes/',
        (server) => server.reply(201, {
          'id': 3,
          'name': 'Living',
          'is_shiny_dex': false,
          'force_new_box': true,
          'total': 1227,
          'registered': 0,
        }),
        data: {'name': 'Living', 'is_shiny_dex': false, 'force_new_box': true},
      );
    final preview = await repository.previewNewDex(forceNewBox: true);
    expect(preview.boxesNeeded, 45);
    expect(preview.firstBox!.name, 'HOME 50');
    final dex = await repository.createDex(
      name: 'Living',
      isShinyDex: false,
      forceNewBox: true,
    );
    expect(dex.total, 1227);
  });

  test('fetchHunts: filtros e paginação', () async {
    adapter.onGet(
      'personal-dexes/1/hunts/',
      (server) => server.reply(200, {
        'count': 1,
        'next': null,
        'previous': null,
        'results': [
          {
            ...missingSlotJson,
            'reasons': ['no_shiny'],
            'shiny_lock': null,
          },
        ],
      }),
      queryParameters: {
        'reasons': 'no_shiny,from_go',
        'generation': 'generation-vii',
        'page': 2,
        'page_size': 20,
      },
    );
    final page = await repository.fetchHunts(
      1,
      const HuntQuery(
        reasons: [HuntReason.noShiny, HuntReason.fromGo],
        generations: ['generation-vii'],
      ),
      page: 2,
      pageSize: 20,
    );
    expect(page.count, 1);
    expect(page.results.single.reasons, [HuntReason.noShiny]);
  });
}
