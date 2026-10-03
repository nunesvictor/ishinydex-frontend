import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/features/shiny_locks/data/http_shiny_lock_repository.dart';
import 'package:ishinydex/features/shiny_locks/domain/models.dart';

import '../../fixtures/api_fixtures.dart';

void main() {
  late DioAdapter adapter;
  late HttpShinyLockRepository repository;

  setUp(() {
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api/'));
    adapter = DioAdapter(dio: dio);
    repository = HttpShinyLockRepository(dio);
  });

  final draft = ShinyLockDraft.of(ShinyLock.fromJson(shinyLockJson));

  test('lista, cria, edita e apaga', () async {
    adapter
      ..onGet('shiny-locks/', (server) => server.reply(200, [shinyLockJson]))
      ..onPost(
        'shiny-locks/',
        (server) => server.reply(201, shinyLockJson),
        data: draft.toJson(),
      )
      ..onPatch(
        'shiny-locks/25/',
        (server) => server.reply(200, shinyLockJson),
        data: draft.toJson(),
      )
      ..onDelete('shiny-locks/25/', (server) => server.reply(204, null));

    expect((await repository.fetchShinyLocks()).single.id, 25);
    expect((await repository.createShinyLock(draft)).id, 25);
    expect((await repository.updateShinyLock(25, draft)).id, 25);
    await repository.deleteShinyLock(25);
  });

  test('erro de validação vem por campo', () async {
    adapter.onPost(
      'shiny-locks/',
      (server) => server.reply(400, {
        'caption': ['Já existe.'],
      }),
      data: draft.toJson(),
    );

    expect(
      () => repository.createShinyLock(draft),
      throwsA(
        isA<ValidationFailure>().having(
          (f) => f.errorFor('caption'),
          'caption',
          'Já existe.',
        ),
      ),
    );
  });
}
