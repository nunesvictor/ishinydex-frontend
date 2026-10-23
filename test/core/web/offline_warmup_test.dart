import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/web/offline_warmup.dart';

/// O bundle dos testes (os assets de verdade), contando o que carrega; com
/// [failAfter], falha a partir desse carregamento (sem internet).
class _CountingBundle extends CachingAssetBundle {
  _CountingBundle({this.failAfter});

  final int? failAfter;
  final loaded = <String>[];

  @override
  Future<ByteData> load(String key) async {
    if (failAfter case final n? when loaded.length >= n) {
      throw const SocketException('offline');
    }
    loaded.add(key);
    return await rootBundle.load(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('carrega cada asset da versão, uma vez', () async {
    final bundle = _CountingBundle();
    var ready = false;
    await warmUpOffline(
      bundle: bundle,
      delay: Duration.zero,
      cacheReady: () async => ready = true,
    );
    expect(ready, isTrue);
    expect(bundle.loaded, contains('assets/origin_marks/paldea.png'));
    expect(bundle.loaded, contains('assets/icons/shiny.png'));
    expect(bundle.loaded.toSet(), hasLength(bundle.loaded.length));
  });

  test('fora do navegador, não espera service worker', () async {
    final bundle = _CountingBundle(failAfter: 0);
    await warmUpOffline(bundle: bundle, delay: Duration.zero);
    expect(bundle.loaded, isEmpty);
  });

  test('para no primeiro erro', () async {
    final bundle = _CountingBundle(failAfter: 2);
    await precacheAssets(bundle);
    expect(bundle.loaded, hasLength(2));
  });

  test('os caracteres fora da Roboto que o app escreve', () {
    // Mede o texto sem erro (fora do navegador, não baixa nada).
    warmUpFallbackFonts();
    final source = [
      File('lib/core/utils/format.dart').readAsStringSync(),
      File('lib/features/personal_dex/presentation/widgets/form_details.dart')
          .readAsStringSync(),
      File('lib/features/shiny_hunts/presentation/hunt_card.dart')
          .readAsStringSync(),
    ].join();
    for (final glyph in ['✓', '♂️', '♀️', '↳']) {
      expect(source, contains(glyph));
      expect(fallbackGlyphs, contains(glyph));
    }
  });

  test('o service worker guarda as fontes do fonts.gstatic.com', () {
    final sw = File('web/sw.js').readAsStringSync();
    expect(sw, contains("const FONTS_HOST = 'fonts.gstatic.com';"));
    expect(sw, contains('cacheFirst(FONTS_CACHE, request)'));
    // Num cache que sobrevive às versões (sem o hash no nome).
    expect(sw, contains("const FONTS_CACHE = 'ishinydex-fonts';"));
  });
}
