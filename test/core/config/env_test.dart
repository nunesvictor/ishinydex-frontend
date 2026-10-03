import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';

void main() {
  test('valores padrão sem --dart-define', () {
    final env = ProviderContainer().read(envProvider);
    expect(env.apiBaseUrl, 'http://localhost:8008/api');
    expect(env.useFakeApi, false);
    expect(env.appVersion, 'dev');
  });

  test('fromEnvironment aceita a página base', () {
    final env = Env.fromEnvironment(base: Uri.parse('http://x:1/'));
    expect(env.apiBaseUrl, 'http://localhost:8008/api');
  });

  group('resolveApiBaseUrl', () {
    final page = Uri.parse('http://192.168.0.10:8090/#/dexes/1');

    test('URL absoluta é mantida', () {
      expect(
        Env.resolveApiBaseUrl('https://api.exemplo.com/api', page),
        'https://api.exemplo.com/api',
      );
    });

    test('URL relativa usa a origem da página', () {
      expect(
        Env.resolveApiBaseUrl('/api', page),
        'http://192.168.0.10:8090/api',
      );
    });
  });
}
