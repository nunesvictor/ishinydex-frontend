import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';

void main() {
  test('valores padrão sem --dart-define', () {
    final env = ProviderContainer().read(envProvider);
    expect(env.apiBaseUrl, 'http://localhost:8008/api');
    expect(env.useFakeApi, false);
    expect(env.appVersion, 'dev');
    expect(env.catalogUrl, isNull);
    expect(env.spritesBaseUrl, Env.defaultSpritesBaseUrl);
  });

  test('fromEnvironment aceita a página base', () {
    final env = Env.fromEnvironment(base: Uri.parse('http://x:1/'));
    expect(env.apiBaseUrl, 'http://localhost:8008/api');
  });

  test('resolveCatalogUrl: vazio é sem catálogo; relativo usa a página', () {
    final page = Uri.parse('https://x.github.io/ishinydex/#/dexes');
    expect(Env.resolveCatalogUrl('', page), isNull);
    expect(
      Env.resolveCatalogUrl('catalog/catalog.json', page),
      'https://x.github.io/ishinydex/catalog/catalog.json',
    );
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
