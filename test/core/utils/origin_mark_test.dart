import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/utils/origin_mark.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';

void main() {
  test('fromSlug: valores da API, desconhecido e nulo', () {
    for (final mark in OriginMark.values) {
      expect(OriginMark.fromSlug(mark.slug), mark);
    }
    expect(OriginMark.fromSlug('paldea'), OriginMark.paldea);
    expect(OriginMark.fromSlug('lets-go'), OriginMark.letsGo);
    expect(OriginMark.fromSlug('none'), isNull);
    expect(OriginMark.fromSlug('kanto'), isNull);
    expect(OriginMark.fromSlug(null), isNull);
  });

  test('fromVersion: todo jogo que vira save tem marca', () {
    for (final version in Save.transferVersions) {
      expect(OriginMark.fromVersion(version), isNotNull, reason: version);
    }
    expect(OriginMark.fromVersion('lets-go-eevee'), OriginMark.letsGo);
    // FRLG do Switch: não vira save, mas tem marca (a do GBA).
    expect(OriginMark.fromVersion('firered'), OriginMark.gba);
    expect(OriginMark.fromVersion('leafgreen'), OriginMark.gba);
    expect(Save.transferVersions, isNot(contains('firered')));
    expect(OriginMark.fromVersion('red'), isNull);
  });

  test('cada marca tem nome e ícone próprios', () {
    expect(OriginMark.go.label, 'GO');
    expect(OriginMark.go.games, 'Pokémon GO');
    expect(OriginMark.alola.label, 'SM/USUM');
    expect(OriginMark.kalos.label, 'XY/ORAS');
    expect(OriginMark.bdsp.label, 'BDSP');
    expect(OriginMark.galar.label, 'SwSh');
    expect(OriginMark.gba.label, 'GBA');
    expect(OriginMark.gba.games, 'FireRed e LeafGreen (Switch)');
    expect(OriginMark.gba.asset, 'assets/origin_marks/gba.png');
    expect(OriginMark.go.asset, 'assets/origin_marks/go.png');
    expect(OriginMark.gameBoy.asset, 'assets/origin_marks/game_boy.png');
    expect(
      OriginMark.values.map((m) => m.asset).toSet(),
      hasLength(OriginMark.values.length),
    );
  });

  test('nomes de FireRed e LeafGreen como os jogos se chamam', () {
    expect(versionLabel('firered'), 'FireRed');
    expect(versionLabel('leafgreen'), 'LeafGreen');
  });
}
