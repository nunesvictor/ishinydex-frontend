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

  test('service worker: registrado, versionado e sem a API no cache', () {
    final html = File('web/index.html').readAsStringSync();
    final sw = File('web/sw.js').readAsStringSync();
    final docker = File('Dockerfile').readAsStringSync();

    expect(html, contains("navigator.serviceWorker.register('sw.js')"));
    // A versão é trocada no build, como no flutter_bootstrap.js.
    expect(sw, contains("const VERSION = '__BUILD_VERSION__';"));
    expect(docker, contains('build/web/flutter_bootstrap.js build/web/sw.js'));
    expect(sw, contains(r'/\/(api|admin)\//'));
    expect(sw, contains("if (request.method !== 'GET') return;"));
  });
}
