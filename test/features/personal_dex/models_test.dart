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

  test('FormRef.dexNumber: nº nacional, ou o pokeapiId sem ele', () {
    final alola = FormRef.fromJson({
      'id': 2,
      'name': 'raichu-alola',
      'pokeapi_id': 10100,
      'national_number': 26,
      'sprite_url': '',
      'shiny_sprite_url': '',
    });
    expect(alola.nationalNumber, 26);
    expect(alola.dexNumber, '#0026');
    expect(alola.copyWith(nationalNumber: null).dexNumber, '#10100');
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

  group('caçadas', () {
    test('Hunt.parse: slot achatado, motivos e shiny lock', () {
      final hunt = Hunt.parse({
        ...missingSlotJson,
        'reasons': ['no_shiny', 'foo', 'pokeball'],
        'shiny_lock': 'distro-only',
      });
      expect(hunt.slot.id, 20);
      expect(hunt.slot.isMissing, true);
      expect(hunt.reasons, [HuntReason.noShiny, HuntReason.pokeball]);
      expect(hunt.shinyLock, ShinyLock.distroOnly);
      final plain = Hunt.parse({
        ...missingSlotJson,
        'reasons': <String>[],
        'shiny_lock': null,
      });
      expect(plain.shinyLock, isNull);
    });

    test('HuntQuery: padrão manda só os motivos', () {
      expect(const HuntQuery().toQueryParameters(), {'reasons': 'no_shiny'});
      expect(const HuntQuery().scopeCount, 0);
    });

    test('HuntQuery: todos os filtros', () {
      const query = HuntQuery(
        reasons: [HuntReason.noShiny, HuntReason.fromGo, HuntReason.pokeball],
        acceptedBalls: ['poke-ball', 'premier-ball'],
        generations: ['generation-vii'],
        types: ['water', 'flying'],
        categories: [HuntCategory.legendary, HuntCategory.ultraBeast],
        search: ' tapu ',
        includeLocked: true,
      );
      expect(query.toQueryParameters(), {
        'reasons': 'no_shiny,from_go,pokeball',
        'accepted_balls': 'poke-ball,premier-ball',
        'generation': 'generation-vii',
        'type': 'water,flying',
        'category': 'legendary,ultra-beast',
        'search': 'tapu',
        'include_locked': true,
      });
      expect(query.scopeCount, 4);
      expect(
        query.clearScope(),
        const HuntQuery(
          reasons: [HuntReason.noShiny, HuntReason.fromGo, HuntReason.pokeball],
          acceptedBalls: ['poke-ball', 'premier-ball'],
          search: ' tapu ',
        ),
      );
    });

    test('rótulos e parâmetros dos enums', () {
      expect(HuntReason.fromParam('from_go'), HuntReason.fromGo);
      expect(HuntReason.fromParam('foo'), isNull);
      expect(ShinyLock.fromParam('unobtainable'), ShinyLock.unobtainable);
      expect(ShinyLock.fromParam(null), isNull);
      expect(HuntCategory.ultraBeast.param, 'ultra-beast');
      expect(HuntCategory.regular.label, 'Comum');
      expect(ShinyLock.unobtainable.label, 'Shiny impossível');
    });
  });
}
