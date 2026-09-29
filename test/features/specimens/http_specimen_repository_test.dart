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
}
