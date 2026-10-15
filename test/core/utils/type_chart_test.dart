import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/utils/type_chart.dart';

void main() {
  test('a tabela da geração 6: 51 super efetivos, 61 pouco e 8 imunes', () {
    var (double, half, none) = (0, 0, 0);
    for (final a in pokemonTypes) {
      for (final d in pokemonTypes) {
        switch (effectiveness(a, d)) {
          case 2:
            double++;
          case 0.5:
            half++;
          case 0:
            none++;
        }
      }
    }
    expect((double, half, none), (51, 61, 8));
  });

  test('Garchomp (Dragon/Ground): Ice 4×, Electric 0×', () {
    final m = defenseMultipliers(['dragon', 'ground']);
    expect(m['ice'], 4);
    expect(m['dragon'], 2);
    expect(m['fairy'], 2);
    expect(m['fire'], 0.5);
    expect(m['electric'], 0);
    expect(m['water'], 1);
  });

  test(
    'Bulbasaur (Grass/Poison): Grass ¼×; tipos fora da tabela não contam',
    () {
      expect(defenseMultipliers(['grass', 'poison'])['grass'], 0.25);
      expect(defenseMultipliers(['grass', 'stellar'])['fire'], 2);
      expect(defenseMultipliers(['stellar']).values.toSet(), {1});
      expect(effectiveness('stellar', 'grass'), 1);
      expect(isChartType('fairy'), isTrue);
      expect(isChartType('stellar'), isFalse);
    },
  );

  test('STAB: Ground acerta 2× Fire, Electric, Poison, Rock e Steel', () {
    expect(superEffectiveAgainst('ground'), [
      'fire',
      'electric',
      'poison',
      'rock',
      'steel',
    ]);
    expect(superEffectiveAgainst('normal'), isEmpty);
  });
}
