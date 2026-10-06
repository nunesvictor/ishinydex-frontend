import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';

void main() {
  test('valores padrão sem --dart-define', () {
    final env = ProviderContainer().read(envProvider);
    expect(env.localData, isFalse);
    expect(env.appVersion, 'dev');
    expect(env.catalogUrl, isNull);
    expect(env.spritesBaseUrl, Env.defaultSpritesBaseUrl);
    expect(env.dropboxAppKey, isNull);
    expect(env.syncAvailable, isFalse);
  });

  test('sincronização: só no modo local e com a app key', () {
    Env env({bool local = true, String? key = 'k'}) =>
        Env(localData: local, dropboxAppKey: key);
    expect(env().syncAvailable, isTrue);
    expect(env(local: false).syncAvailable, isFalse);
    expect(env(key: null).syncAvailable, isFalse);
  });

  test('fromEnvironment aceita a página base', () {
    final env = Env.fromEnvironment(base: Uri.parse('http://x:1/'));
    expect(env.catalogUrl, isNull);
  });

  test('resolveCatalogUrl: vazio é sem catálogo; relativo usa a página', () {
    final page = Uri.parse('https://x.github.io/ishinydex/#/dexes');
    expect(Env.resolveCatalogUrl('', page), isNull);
    expect(
      Env.resolveCatalogUrl('catalog/catalog.json', page),
      'https://x.github.io/ishinydex/catalog/catalog.json',
    );
  });

  group('resolveUrl', () {
    final page = Uri.parse('https://x.github.io/ishinydex/#/dexes/1');

    test('URL absoluta é mantida', () {
      expect(
        Env.resolveUrl('https://cdn.exemplo.com/catalog.json', page),
        'https://cdn.exemplo.com/catalog.json',
      );
    });

    test('URL relativa usa a página', () {
      expect(
        Env.resolveUrl('/catalog.json', page),
        'https://x.github.io/catalog.json',
      );
    });
  });
}
