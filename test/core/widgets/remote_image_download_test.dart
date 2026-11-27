import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/widgets/remote_image.dart';

/// O download de verdade, contra um servidor local. Num arquivo à parte, sem
/// `testWidgets`: o binding dos testes de tela troca o `HttpClient` por um
/// que responde 400 a tudo.
void main() {
  late HttpServer server;
  late Set<int> connections;

  setUp(() async {
    connections = {};
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0)
      ..listen((request) async {
        connections.add(request.connectionInfo!.remotePort);
        final response = request.response;
        if (request.uri.path == '/25.png') {
          response.add([1, 2, 3]);
        } else {
          response.statusCode = HttpStatus.notFound;
        }
        await response.close();
      });
  });
  tearDown(() => server.close(force: true));

  Uri url(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');

  test('200: os bytes da resposta', () async {
    expect(await downloadBytes(url('/25.png')), [1, 2, 3]);
  });

  test('outro status: falha, para a imagem cair no fallback', () async {
    await expectLater(
      downloadBytes(url('/nao-existe.png')),
      throwsA(
        isA<HttpException>().having((e) => e.message, 'message', 'HTTP 404'),
      ),
    );
  });

  test(
    'a mesma conexão para vários downloads, mesmo após um 404 (#432)',
    () async {
      await downloadBytes(url('/25.png'));
      await expectLater(
        downloadBytes(url('/nao-existe.png')),
        throwsA(isA<HttpException>()),
      );
      await downloadBytes(url('/25.png'));
      expect(connections, hasLength(1));
    },
  );
}
