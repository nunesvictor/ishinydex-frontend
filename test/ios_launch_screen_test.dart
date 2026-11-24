import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

// A launch screen do iOS (#423) é o que o aparelho mostra enquanto o app
// nativo abre, antes do primeiro quadro do Flutter: o equivalente ao splash
// do PWA (web/index.html). Ela não roda código, então as cores ficam
// duplicadas em cores nomeadas do Assets.xcassets; estes testes garantem
// que elas continuam iguais às do AppTheme.

const _assets = 'ios/Runner/Assets.xcassets';

String _hex(Color c) =>
    c.toARGB32().toRadixString(16).substring(2).toUpperCase();

/// As cores de um `.colorset`, como RRGGBB: `light` (padrão) e `dark`.
Map<String, String> _colorset(String name) {
  final json = jsonDecode(
    File('$_assets/$name.colorset/Contents.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final result = <String, String>{};
  for (final entry in json['colors'] as List) {
    final e = entry as Map<String, dynamic>;
    final appearances = (e['appearances'] as List?) ?? const [];
    final dark = appearances.any(
      (a) => (a as Map)['appearance'] == 'luminosity' && a['value'] == 'dark',
    );
    final c = (e['color'] as Map)['components'] as Map;
    String byte(String key) => (c[key] as String).substring(2).toUpperCase();
    result[dark ? 'dark' : 'light'] =
        '${byte('red')}${byte('green')}${byte('blue')}';
  }
  return result;
}

void main() {
  final light = AppTheme.light().colorScheme;
  final dark = AppTheme.dark().colorScheme;

  test('fundo da launch screen: o surface de cada tema', () {
    expect(_colorset('LaunchBackground'), {
      'light': _hex(light.surface),
      'dark': _hex(dark.surface),
    });
  });

  test('nome do app na launch screen: o onSurface de cada tema', () {
    expect(_colorset('LaunchText'), {
      'light': _hex(light.onSurface),
      'dark': _hex(dark.onSurface),
    });
  });

  test('o storyboard usa as cores nomeadas, o ícone e o nome', () {
    final storyboard = File('ios/Runner/Base.lproj/LaunchScreen.storyboard')
        .readAsStringSync();

    expect(
      storyboard,
      contains('<color key="backgroundColor" name="LaunchBackground"/>'),
    );
    expect(storyboard, contains('<color key="textColor" name="LaunchText"/>'));
    expect(storyboard, contains('text="iShinyDex"'));
    expect(
      storyboard,
      contains('<image name="LaunchImage" width="96" height="96"/>'),
    );
  });
}
