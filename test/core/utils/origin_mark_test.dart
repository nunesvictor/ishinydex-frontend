import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/utils/origin_mark.dart';

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

  test('cada marca tem nome e ícone próprios', () {
    expect(OriginMark.go.label, 'Pokémon GO');
    expect(OriginMark.go.asset, 'assets/origin_marks/go.png');
    expect(OriginMark.gameBoy.asset, 'assets/origin_marks/game_boy.png');
    expect(
      OriginMark.values.map((m) => m.asset).toSet(),
      hasLength(OriginMark.values.length),
    );
  });
}
