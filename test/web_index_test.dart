import 'dart:convert';
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
    // Em inglês no HTML; o script do idioma troca para o data-pt.
    expect(
      html,
      contains(
        "<span data-pt=\"Está demorando mais que o normal.\">It's taking longer than usual.</span>",
      ),
    );
    expect(
      html,
      contains(
        'onclick="location.reload()" data-pt="Recarregar">Reload</button>',
      ),
    );
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

    expect(html, contains("sw.register('sw.js')"));
    // Só depois do primeiro quadro: a troca de worker numa atualização não
    // concorre com o boot (#176).
    final firstFrame = html.substring(
      html.indexOf("addEventListener('flutter-first-frame'"),
    );
    expect(firstFrame, contains('registerServiceWorker();'));
    expect(RegExp(r'\.register\(').allMatches(html), hasLength(1));
    // A versão é trocada no build, como no flutter_bootstrap.js.
    expect(sw, contains("const VERSION = '__BUILD_VERSION__';"));
    expect(sw, contains("if (request.method !== 'GET') return;"));
  });

  test('golpes (#36): cache primeiro, num cache que fica entre versões', () {
    final sw = File('web/sw.js').readAsStringSync();
    // O arquivo dos golpes, pelo nome versionado, vai para o próprio cache.
    expect(sw, contains("const MOVES_CACHE = 'ishinydex-moves';"));
    expect(sw, contains(r'/\/catalog\/moves-[^/]+\.json$/'));
    expect(sw, contains('event.respondWith(movesFirst(request));'));
    final moves = sw.substring(sw.indexOf('async function movesFirst'));
    expect(moves, contains('const hit = await cache.match(request);'));
    expect(moves, contains('if (hit) return hit;'));
    // Guardar o novo apaga os dos catálogos anteriores.
    expect(moves, contains('k.url !== request.url'));
    // A limpeza de versões do app só mexe nos caches do app.
    expect(sw, contains("n.startsWith('ishinydex-app-')"));
  });

  test('worker novo espera o primeiro quadro; aviso de versão nova (#228)', () {
    final html = File('web/index.html').readAsStringSync();
    final sw = File('web/sw.js').readAsStringSync();
    final install = sw.substring(
      sw.indexOf("addEventListener('install'"),
      sw.indexOf("addEventListener('message'"),
    );
    // Sem assumir sozinho: o navegador instala o worker novo ao abrir a
    // página, e assumir no boot derrubava os downloads no iOS.
    expect(install, isNot(contains('self.skipWaiting')));
    expect(
      sw,
      contains("if (event.data === 'skip-waiting') self.skipWaiting();"),
    );
    expect(sw, contains('version: VERSION'));
    expect(html, contains("postMessage('skip-waiting')"));
    expect(html, contains("postMessage('version')"));
    expect(html, contains("new Event('ishinydex-update-ready')"));
    expect(html, contains('registration.update()'));
  });

  test('tema do shell (#273): Claro ou Escuro de Ajustes vencem o aparelho', () {
    final html = File('web/index.html').readAsStringSync();
    final light = AppTheme.light().colorScheme;
    final dark = AppTheme.dark().colorScheme;
    // A mesma chave do PrefsThemeModeStorage, com o prefixo do
    // shared_preferences na web.
    final storage = File('lib/core/theme/app_theme_mode.dart')
        .readAsStringSync();
    expect(storage, contains("key = 'app_theme'"));
    expect(html, contains("localStorage.getItem('flutter.app_theme')"));
    expect(html, contains('document.documentElement.dataset.theme = saved;'));
    // As duas metas ficam com a cor do tema escolhido.
    expect(
      html,
      contains(
        "saved === 'dark' ? '${_hex(dark.surface)}' : '${_hex(light.surface)}'",
      ),
    );
    for (final (name, scheme) in [('light', light), ('dark', dark)]) {
      final root = ':root[data-theme="$name"]';
      expect(
        html,
        contains('$root body { background-color: ${_hex(scheme.surface)}; }'),
      );
      expect(
        html,
        contains('$root #splash { color: ${_hex(scheme.onSurface)}; }'),
      );
      expect(
        html,
        contains(
          '$root .splash-track { background: ${_hex(scheme.primaryContainer)}; }',
        ),
      );
      expect(
        html,
        contains('$root .splash-bar { background: ${_hex(scheme.primary)}; }'),
      );
    }
    // O script vem depois das metas que ele troca.
    expect(
      html.indexOf("getItem('flutter.app_theme')"),
      greaterThan(html.lastIndexOf('<meta name="theme-color"')),
    );
  });

  group('idioma do shell (#178)', () {
    test('inglês por padrão; português pelo Ajustes ou pelo navegador', () {
      final html = File('web/index.html').readAsStringSync();
      expect(html, contains('<html lang="en">'));
      // A mesma chave do PrefsLanguageStorage, com o prefixo do
      // shared_preferences na web.
      final storage = File('lib/core/l10n/app_language.dart')
          .readAsStringSync();
      expect(storage, contains("_key = 'app_language'"));
      expect(html, contains("localStorage.getItem('flutter.app_language')"));
      expect(html, contains("startsWith('pt')"));
      expect(html, contains("'manifest.pt-BR.json'"));
      // O script do idioma vem depois do manifesto e da descrição que troca.
      expect(
        html.indexOf('window.ishinydexLang = '),
        greaterThan(html.indexOf('<link rel="manifest"')),
      );
    });

    test('os dois manifestos só diferem na descrição e no idioma', () {
      Map<String, dynamic> read(String name) =>
          jsonDecode(File('web/$name').readAsStringSync())
              as Map<String, dynamic>;
      final en = read('manifest.json');
      final pt = read('manifest.pt-BR.json');
      expect(en['lang'], 'en');
      expect(pt['lang'], 'pt-BR');
      expect(en['description'], isNot(pt['description']));
      for (final key in {...en.keys, ...pt.keys}) {
        if (key == 'lang' || key == 'description') continue;
        expect(jsonEncode(en[key]), jsonEncode(pt[key]), reason: key);
      }
      // Os dois vão para o cache offline.
      final sw = File('web/sw.js').readAsStringSync();
      expect(sw, contains("'manifest.json'"));
      expect(sw, contains("'manifest.pt-BR.json'"));
    });
  });
}
