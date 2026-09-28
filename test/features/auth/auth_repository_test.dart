import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/features/auth/data/auth_repository.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late HttpAuthRepository repository;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://test/api/'));
    adapter = DioAdapter(dio: dio);
    repository = HttpAuthRepository(dio);
  });

  test('login retorna o token', () async {
    adapter.onPost(
      'auth/token/',
      (server) => server.reply(200, {'token': 'abc'}),
      data: {'username': 'ash', 'password': 'pika'},
    );
    expect(await repository.login(username: 'ash', password: 'pika'), 'abc');
  });

  test('credenciais inválidas viram ValidationFailure', () {
    adapter.onPost(
      'auth/token/',
      (server) => server.reply(400, {
        'non_field_errors': ['Credenciais inválidas.'],
      }),
      data: Matchers.any,
    );
    expect(
      repository.login(username: 'a', password: 'b'),
      throwsA(
        isA<ValidationFailure>().having(
          (f) => f.message,
          'message',
          'Credenciais inválidas.',
        ),
      ),
    );
  });
}
