import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/utils/origin_mark.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final pt = lookupAppLocalizations(const Locale('pt'));

  test('jogos da marca de origem, com "e"/"and" em cada par', () {
    expect(pt.originMarkGames(OriginMark.go), 'Pokémon GO');
    expect(pt.originMarkGames(OriginMark.gba), 'FireRed e LeafGreen (Switch)');
    expect(
      en.originMarkGames(OriginMark.kalos),
      'X and Y / Omega Ruby and Alpha Sapphire',
    );
    for (final mark in OriginMark.values) {
      expect(en.originMarkGames(mark), isNotEmpty, reason: mark.slug);
    }
  });

  test('registrados fora do HOME', () {
    expect(pt.awayCount(0), '');
    expect(pt.awayCount(2), ' · 2 fora');
    expect(en.awayCount(2), ' · 2 away');
  });
}
