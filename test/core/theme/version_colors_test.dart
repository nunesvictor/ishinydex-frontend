import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/theme/version_colors.dart';

import '../../helpers/contrast.dart';

void main() {
  test('todo jogo com ícone tem cor (menos o Champions, sem cor de marca)', () {
    final games = [
      for (final f in Directory('assets/game_icons').listSync())
        f.uri.pathSegments.last.split('.').first,
    ]..remove('champions');
    expect(games, isNotEmpty);
    for (final game in games) {
      expect(versionColors, contains(game), reason: game);
    }
  });

  test('contraste do texto (4,5) em todas as versões, nos dois temas', () {
    for (final version in versionColors.keys) {
      for (final brightness in Brightness.values) {
        final tone = versionTone(version, brightness)!;
        expect(
          contrast(tone.foreground, tone.background),
          greaterThanOrEqualTo(4.5),
          reason: '$version (${brightness.name})',
        );
      }
    }
  });

  test('o matiz da marca: Scarlet avermelhado, Violet arroxeado', () {
    double hue(Color c) => HSLColor.fromColor(c).hue;
    final scarlet = versionTone('scarlet', Brightness.light)!;
    final violet = versionTone('violet', Brightness.dark)!;
    expect(hue(scarlet.background), closeTo(hue(versionColors['scarlet']!), 1));
    expect(hue(violet.foreground), closeTo(hue(versionColors['violet']!), 1));
    // Claro: fundo claro, texto escuro; escuro: o contrário.
    expect(
      scarlet.background.computeLuminance(),
      greaterThan(scarlet.foreground.computeLuminance()),
    );
    expect(
      violet.background.computeLuminance(),
      lessThan(violet.foreground.computeLuminance()),
    );
    expect(versionTone('champions', Brightness.light), isNull);
  });
}
