import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:ishinydex/core/network/api_client.dart';

void main() {
  late String? token;
  late int unauthorizedCalls;
  late Dio dio;
  late DioAdapter adapter;

  setUp(() {
    token = null;
    unauthorizedCalls = 0;
    dio = createDio(
      baseUrl: 'http://test/api',
      readToken: () => token,
      onUnauthorized: () => unauthorizedCalls++,
    );
    adapter = DioAdapter(dio: dio);
  });

  test('normaliza a baseUrl com barra final', () {
    expect(dio.options.baseUrl, 'http://test/api/');
    final withSlash = createDio(
      baseUrl: 'http://x/',
      readToken: () => null,
      onUnauthorized: () {},
    );
    expect(withSlash.options.baseUrl, 'http://x/');
  });

  test('envia o token quando existe', () async {
    token = 'abc';
    adapter.onGet(
      'ping/',
      (server) => server.reply(200, {'ok': true}),
      headers: {'Authorization': 'Token abc'},
    );
    final response = await dio.get<Map<String, dynamic>>('ping/');
    expect(response.data, {'ok': true});
  });

  test('não envia Authorization sem token', () async {
    adapter.onGet('ping/', (server) => server.reply(200, <String, dynamic>{}));
    final response = await dio.get<Map<String, dynamic>>('ping/');
    expect(response.requestOptions.headers.containsKey('Authorization'), false);
  });

  test('401 chama onUnauthorized; outros erros não', () async {
    adapter
      ..onGet('private/', (server) => server.reply(401, {'detail': 'x'}))
      ..onGet('broken/', (server) => server.reply(500, {'detail': 'x'}));
    await expectLater(dio.get<void>('private/'), throwsA(isA<DioException>()));
    await expectLater(dio.get<void>('broken/'), throwsA(isA<DioException>()));
    expect(unauthorizedCalls, 1);
  });
}
