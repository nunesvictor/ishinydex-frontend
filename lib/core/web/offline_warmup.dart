import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:ishinydex/core/theme/app_theme.dart';
import 'package:ishinydex/core/web/browser.dart' as browser;

/// Os caracteres que o app escreve e que a Roboto não tem (#337). No
/// navegador, o Flutter baixa a fonte deles do `fonts.gstatic.com` só quando
/// um texto os usa; sem internet nessa hora, viram um quadrado vazio. O
/// emoji de gênero (com o seletor de emoji) vem de outra fonte que o
/// símbolo sozinho, por isso os dois.
const fallbackGlyphs = '✓ ♂ ♀ ♂️ ♀️ ↳ ↑ ↓ → −';

/// Quanto esperar depois do primeiro quadro: os downloads do boot primeiro.
const warmUpDelay = Duration(seconds: 5);

/// Deixa guardado no service worker (`web/sw.js`), com a internet de agora,
/// o que o app só baixa quando usa (#337): as fontes dos [fallbackGlyphs] e
/// todos os assets da versão (marcas de origem, ícones de jogo e de tipo).
/// Uma versão nova guarda os assets em outra pasta (`v/<hash>/`), então a
/// marca de um espécime aberto pela primeira vez offline não aparecia.
Future<void> warmUpOffline({
  AssetBundle? bundle,
  Duration delay = warmUpDelay,
  Future<void> Function() cacheReady = browser.offlineCacheReady,
}) async {
  await Future<void>.delayed(delay);
  await cacheReady();
  warmUpFallbackFonts();
  await precacheAssets(bundle ?? rootBundle);
}

/// Mede um texto com os [fallbackGlyphs], fora da tela: é o que faz o
/// Flutter baixar as fontes deles. Fora do navegador, não baixa nada.
void warmUpFallbackFonts() {
  final builder = ui.ParagraphBuilder(
    ui.ParagraphStyle(fontFamily: AppTheme.fontFamily),
  )..addText(fallbackGlyphs);
  builder.build()
    ..layout(const ui.ParagraphConstraints(width: 1000))
    ..dispose();
}

/// Carrega, um por vez, cada asset do [bundle]: no navegador, cada um passa
/// pelo service worker, que o guarda. Para no primeiro erro, inclusive o da
/// lista de assets (sem internet, os outros também falhariam).
Future<void> precacheAssets(AssetBundle bundle) async {
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    for (final key in manifest.listAssets()) {
      await bundle.load(key);
    }
  } on Object {
    // Sem internet: fica para a próxima abertura.
  }
}
