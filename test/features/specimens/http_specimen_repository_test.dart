import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/features/specimens/data/http_specimen_repository.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';

import '../../fixtures/api_fixtures.dart';

void main() {
  late DioAdapter adapter;
  late HttpSpecimenRepository repository;

  setUp(() {
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api/'));
    adapter = DioAdapter(dio: dio);
    repository = HttpSpecimenRepository(dio);
  });

  test('fetchAvailable filtra por forma e disponibilidade', () async {
    adapter.onGet(
      'specimens/',
      (server) => server.reply(200, specimenPageJson),
      queryParameters: {'form_id': 1, 'available': true, 'page_size': 100},
    );
    expect((await repository.fetchAvailable(1)).single.id, 1);
  });

  test('create envia o draft e trata erro de ability', () async {
    adapter
      ..onPost(
        'specimens/',
        (server) => server.reply(201, specimenJson),
        data: const SpecimenDraft(form: 1, ability: 'overgrow').toRequestJson(),
      )
      ..onPost(
        'specimens/',
        (server) => server.reply(400, {
          'ability': ['Habilidade inválida.'],
        }),
        data: const SpecimenDraft(form: 1, ability: 'x').toRequestJson(),
      );
    expect(
      (await repository.create(
        const SpecimenDraft(form: 1, ability: 'overgrow'),
      )).ability,
      'overgrow',
    );
    expect(
      repository.create(const SpecimenDraft(form: 1, ability: 'x')),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('fetchSpecimen, update (PATCH sem form) e release', () async {
    final draft = SpecimenDraft.fromSpecimen(Specimen.fromJson(specimenJson))
        .copyWith(nickname: 'Bulba', observation: '');
    adapter
      ..onGet('specimens/1/', (server) => server.reply(200, specimenJson))
      ..onPatch(
        'specimens/1/',
        (server) => server.reply(200, {...specimenJson, 'nickname': 'Bulba'}),
        data: draft.toUpdateJson(),
      )
      ..onDelete('specimens/1/', (server) => server.reply(204, null))
      ..onDelete('specimens/2/', (server) => server.reply(404, null));
    expect((await repository.fetchSpecimen(1)).ability, 'overgrow');
    expect((await repository.update(1, draft)).nickname, 'Bulba');
    await repository.release(1);
    expect(repository.release(2), throwsA(isA<NotFoundFailure>()));
  });

  test('fetchForm, fetchOptions e fetchTrainers', () async {
    adapter
      ..onGet('forms/1/', (server) => server.reply(200, formDetailJson))
      ..onGet('specimens/options/', (server) => server.reply(200, optionsJson))
      ..onGet(
        'trainers/',
        (server) => server.reply(200, trainerPageJson),
        queryParameters: {'page_size': 100},
      );
    expect((await repository.fetchForm(1)).abilities, hasLength(2));
    expect((await repository.fetchOptions()).gender.single.value, 'male');
    expect((await repository.fetchTrainers()).single.trainerId, '123456');
  });

  test('createTrainer (com e sem versão) e fetchVersions', () async {
    adapter
      ..onPost(
        'trainers/',
        (server) => server.reply(201, {
          'id': 3,
          'name': 'Red',
          'trainer_id': '1996',
          'version': 'red',
        }),
        data: {'name': 'Red', 'trainer_id': '1996', 'version': 'red'},
      )
      ..onPost(
        'trainers/',
        (server) => server.reply(400, {
          'name': ['Este campo não pode ser em branco.'],
        }),
        data: {'name': '', 'trainer_id': '1'},
      )
      ..onGet(
        'versions/',
        (server) => server.reply(200, [
          {
            'name': 'red',
            'version_group': 'red-blue',
            'generation': 'generation-i',
          },
        ]),
      );
    final red = await repository.createTrainer(
      name: 'Red',
      trainerId: '1996',
      version: 'red',
    );
    expect(red.label, 'Red (1996) · Red');
    // Sem versão, o campo nem vai no corpo.
    expect(
      repository.createTrainer(name: '', trainerId: '1'),
      throwsA(isA<ValidationFailure>()),
    );
    expect((await repository.fetchVersions()).single.label, 'Red');
  });

  test('fetchSpecimens envia só os filtros usados', () async {
    final page = {
      'count': 1,
      'next': null,
      'previous': null,
      'results': [specimenJson],
    };
    adapter
      ..onGet(
        'specimens/',
        (server) => server.reply(200, page),
        queryParameters: {'page': 1, 'page_size': 20},
      )
      ..onGet(
        'specimens/',
        (server) => server.reply(200, page),
        queryParameters: {
          'page': 2,
          'page_size': 20,
          'search': 'bulba',
          'available': false,
          'is_shiny': true,
          'is_alpha': true,
          'is_from_go': true,
          'pokeball': 'dive-ball',
          'ordering': '-created_at',
        },
      );
    expect(
      (await repository.fetchSpecimens(
        emptySpecimenQuery,
        page: 1,
        pageSize: 20,
      )).count,
      1,
    );
    final filtered = await repository.fetchSpecimens(
      emptySpecimenQuery.copyWith(
        search: ' bulba ',
        status: SpecimenStatus.deposited,
        shinyOnly: true,
        alphaOnly: true,
        fromGoOnly: true,
        pokeballs: const ['dive-ball'],
        ordering: SpecimenOrdering.createdDesc,
      ),
      page: 2,
      pageSize: 20,
    );
    expect(filtered.results.single.id, 1);
  });

  test('searchForms', () async {
    adapter.onGet(
      'forms/',
      (server) => server.reply(200, {
        'count': 1,
        'next': null,
        'previous': null,
        'results': [registeredSlotJson['form']],
      }),
      queryParameters: {'search': 'bulba', 'page_size': 30},
    );
    expect((await repository.searchForms(' bulba ')).single.name, 'bulbasaur');
  });
}
