import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/theme/app_theme.dart';

String _hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

void main() {
  test('index.html usa a cor do AppBar de cada tema na barra de status', () {
    final html = File('web/index.html').readAsStringSync();
    final light = _hex(AppTheme.light().colorScheme.surface);
    final dark = _hex(AppTheme.dark().colorScheme.surface);

    expect(
      html,
      contains(
        '<meta name="theme-color" media="(prefers-color-scheme: light)" '
        'content="$light">',
      ),
    );
    expect(
      html,
      contains(
        '<meta name="theme-color" media="(prefers-color-scheme: dark)" '
        'content="$dark">',
      ),
    );
    expect(html, contains('body { background-color: $light; }'));
    expect(html, contains('body { background-color: $dark; }'));
  });

  test('splash: invisível até a margem, com as cores do tema', () {
    final html = File('web/index.html').readAsStringSync();
    final light = AppTheme.light().colorScheme;
    final dark = AppTheme.dark().colorScheme;

    // Só aparece depois da margem de tolerância (o atraso da animação).
    expect(html, contains('animation: splash-in 200ms ease 450ms forwards;'));
    expect(html, contains('color: ${_hex(light.onSurface)}; opacity: 0;'));
    expect(html, contains('background: ${_hex(light.primaryContainer)};'));
    expect(html, contains('background: ${_hex(light.primary)};'));
    expect(html, contains('#splash { color: ${_hex(dark.onSurface)}; }'));
    expect(
      html,
      contains('.splash-track { background: ${_hex(dark.primaryContainer)}; }'),
    );
    expect(
      html,
      contains('.splash-bar { background: ${_hex(dark.primary)}; }'),
    );
    // Sai no primeiro quadro do Flutter, antes de o app carregar.
    expect(html, contains("addEventListener('flutter-first-frame'"));
    expect(
      html.indexOf('<div id="splash"'),
      lessThan(html.indexOf('flutter_bootstrap.js')),
    );
  });

  test('splash: aviso e Recarregar se o primeiro quadro não vier', () {
    final html = File('web/index.html').readAsStringSync();
    final light = AppTheme.light().colorScheme;
    final dark = AppTheme.dark().colorScheme;

    expect(html, contains("classList.add('slow');\n    }, 15000);"));
    expect(html, contains('clearTimeout(slowTimer);'));
    expect(html, contains('Está demorando mais que o normal.'));
    expect(html, contains('onclick="location.reload()">Recarregar</button>'));
    // O splash não recebe toques, exceto com o aviso (o botão).
    expect(html, contains('#splash.slow { pointer-events: auto; }'));
    expect(
      html,
      contains(
        'background: ${_hex(light.primary)}; color: ${_hex(light.onPrimary)};',
      ),
    );
    expect(
      html,
      contains(
        '.splash-slow button { background: ${_hex(dark.primary)}; '
        'color: ${_hex(dark.onPrimary)}; }',
      ),
    );
    expect(html, contains('color: ${_hex(light.onSurfaceVariant)}; }'));
    expect(
      html,
      contains('.splash-slow { color: ${_hex(dark.onSurfaceVariant)}; }'),
    );
  });

  test('service worker: registrado, versionado e só GET no cache', () {
    final html = File('web/index.html').readAsStringSync();
    final sw = File('web/sw.js').readAsStringSync();

    expect(html, contains("navigator.serviceWorker.register('sw.js')"));
    // Só depois do primeiro quadro: a troca de worker numa atualização não
    // concorre com o boot (#176).
    final firstFrame = html.substring(
      html.indexOf("addEventListener('flutter-first-frame'"),
    );
    expect(firstFrame, contains('registerServiceWorker();'));
    expect(RegExp(r'serviceWorker\.register\(').allMatches(html), hasLength(1));
    // A versão é trocada no build, como no flutter_bootstrap.js.
    expect(sw, contains("const VERSION = '__BUILD_VERSION__';"));
    expect(sw, contains("if (request.method !== 'GET') return;"));
  });
}
