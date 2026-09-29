import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';

import '../../fixtures/api_fixtures.dart';

void main() {
  test('Slot registrado', () {
    final slot = Slot.fromJson(registeredSlotJson);
    expect(slot.isRegistered, true);
    expect(slot.isMissing, false);
    expect(slot.isFree, false);
    expect(slot.spriteUrl, contains('/shiny/1.png'));
    expect(slot.specimen!.displayName, 'Bulbasaur');
    expect(slot.form!.displayName, 'Bulbasaur');
    expect(slot.box.name, 'HOME 1');
  });

  test('Slot faltante e slot livre', () {
    final missing = Slot.fromJson(missingSlotJson);
    expect(missing.isMissing, true);
    expect(missing.form!.formName, 'alola');
    expect(missing.form!.spriteFor(shiny: false), isNot(contains('shiny')));

    final free = Slot.fromJson({
      ...missingSlotJson,
      'form': null,
      'is_shiny_display': false,
    });
    expect(free.isFree, true);
    expect(free.isRegistered, false);
    expect(free.isMissing, false);
    expect(free.spriteUrl, isNull);
  });

  test('SpecimenSummary.displayName', () {
    expect(const SpecimenSummary(id: 1, nickname: 'Bubu').displayName, 'Bubu');
    expect(
      const SpecimenSummary(
        id: 1,
        nickname: '',
        formName: 'mr-mime',
      ).displayName,
      'Mr Mime',
    );
    expect(const SpecimenSummary(id: 7).displayName, 'Specimen #7');
  });

  test('PersonalDex e BoxSummary', () {
    final dex = PersonalDex.fromJson(dexJson);
    expect(dex.missing, 69);
    expect(dex.isShinyDex, true);
    final boxes = [
      for (final b in boxesJson) BoxSummary.fromJson(b as Map<String, dynamic>),
    ];
    expect(boxes[0].isComplete, false);
    expect(boxes[1].isComplete, true);
    expect(
      const BoxSummary(
        id: 1,
        name: 'x',
        position: 1,
        total: 0,
        registered: 0,
      ).isComplete,
      false,
    );
  });

  test('GenerationProgress: rótulo e faltantes', () {
    const box = BoxRef(id: 1, name: 'HOME 1', position: 1);
    const gen = GenerationProgress(
      generation: 'generation-iv',
      total: 10,
      registered: 7,
      firstBox: box,
    );
    expect(gen.label, 'Geração IV');
    expect(gen.missing, 3);
    expect(gen.copyWith(generation: null).label, 'Outras formas');
  });
}
