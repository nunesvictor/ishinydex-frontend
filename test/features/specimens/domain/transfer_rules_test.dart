import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/specimens/domain/transfer_rules.dart';

void main() {
  test('bloqueios: formas que não saem, Spinda e Nincada no BDSP', () {
    expect(transferBlock('pikachu-starter', 'lets-go', 'scarlet'), isNotNull);
    expect(transferBlock('calyrex-shadow', null, 'sword'), isNotNull);
    expect(transferBlock('spinda', null, 'shining-pearl'), contains('Spinda'));
    expect(transferBlock('spinda', null, 'scarlet'), isNull);
    expect(transferBlock('nincada', 'paldea', 'brilliant-diamond'), isNotNull);
    expect(transferBlock('nincada', 'bdsp', 'brilliant-diamond'), isNull);
    expect(transferBlock('nincada', 'bdsp', 'sword'), contains('volta'));
    expect(transferBlock('nincada', null, 'sword'), isNull);
    expect(transferBlock('pikachu', null, 'brilliant-diamond'), isNull);
  });

  test('aviso: lendários, míticos e Ultracriaturas do GO, menos Meltan', () {
    expect(
      transferWarning('mewtwo', 'go', SpeciesCategory.legendary),
      isNotNull,
    );
    expect(
      transferWarning('nihilego', 'go', SpeciesCategory.ultraBeast),
      isNotNull,
    );
    expect(transferWarning('meltan', 'go', SpeciesCategory.mythical), isNull);
    expect(transferWarning('melmetal', 'go', SpeciesCategory.mythical), isNull);
    expect(
      transferWarning('mewtwo', 'kanto', SpeciesCategory.legendary),
      isNull,
    );
    expect(transferWarning('pikachu', 'go', SpeciesCategory.regular), isNull);
  });
}
