import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

import '../../fixtures/api_fixtures.dart';

void main() {
  test('Specimen.fromJson com dados reais', () {
    final specimen = Specimen.fromJson(specimenJson);
    expect(specimen.form, 1);
    expect(specimen.isDeposited, true);
    expect(specimen.capturedAt, DateTime(2024, 9, 23));
    expect(specimen.spriteUrl, contains('/shiny/1.png'));
    expect(specimen.displayName, 'Bulbasaur');
  });

  test('Specimen.displayName', () {
    expect(const Specimen(id: 1, form: 1, nickname: 'Bu').displayName, 'Bu');
    expect(const Specimen(id: 2, form: 1).displayName, 'Specimen #2');
    expect(const Specimen(id: 2, form: 1).spriteUrl, isNull);
    expect(const Specimen(id: 2, form: 1).isDeposited, false);
  });

  test('SpecimenDraft.toRequestJson omite vazios e formata a data', () {
    expect(const SpecimenDraft(form: 3, nickname: '').toRequestJson(), {
      'form': 3,
      'is_alpha': false,
      'is_shiny': false,
      'is_from_go': false,
    });
    expect(
      SpecimenDraft(
        form: 3,
        nickname: 'N',
        ability: 'overgrow',
        language: 'en',
        gender: 'male',
        nature: 'adamant',
        isAlpha: true,
        isShiny: true,
        isFromGo: true,
        capturedAt: DateTime(2024, 1, 5, 13),
        pokeball: 'poke-ball',
        observation: 'obs',
        ot: 7,
      ).toRequestJson(),
      {
        'form': 3,
        'nickname': 'N',
        'ability': 'overgrow',
        'language': 'en',
        'gender': 'male',
        'nature': 'adamant',
        'is_alpha': true,
        'is_shiny': true,
        'is_from_go': true,
        'captured_at': '2024-01-05',
        'pokeball': 'poke-ball',
        'observation': 'obs',
        'ot': 7,
      },
    );
  });

  test('SpecimenDraft.fromSpecimen e toUpdateJson (null nos vazios)', () {
    final draft = SpecimenDraft.fromSpecimen(Specimen.fromJson(specimenJson));
    expect(draft.form, 1);
    expect(draft.ability, 'overgrow');
    expect(draft.isShiny, true);
    expect(draft.capturedAt, DateTime(2024, 9, 23));
    expect(draft.toUpdateJson(), {
      'nickname': null,
      'ability': 'overgrow',
      'language': 'en',
      'gender': 'male',
      'nature': 'naughty',
      'is_alpha': false,
      'is_shiny': true,
      'is_from_go': false,
      'captured_at': '2024-09-23',
      'pokeball': null,
      'observation': null,
      'ot': 7,
    });
    expect(
      const SpecimenDraft(form: 1).toUpdateJson(),
      containsPair('captured_at', null),
    );
  });

  test('FormDetail, opções e treinadores', () {
    final form = FormDetail.fromJson(formDetailJson);
    expect(form.abilities.last.isHidden, true);
    expect(form.types.first.type, 'grass');
    final options = SpecimenOptions.fromJson(optionsJson);
    expect(options.pokeball.single.label, 'Poké Ball');
    expect(options.pokeball.single.spriteUrl, endsWith('/poke-ball.png'));
    expect(options.nature.single.spriteUrl, isNull);
    final trainer = Trainer.fromJson(
      (trainerPageJson['results']! as List).first as Map<String, dynamic>,
    );
    expect(trainer.label, 'Ash (123456) · Ultra Moon');
    expect(trainer.copyWith(version: null).label, 'Ash (123456)');
  });

  test('GameVersion.fromJson e label', () {
    final version = GameVersion.fromJson(const {
      'name': 'scarlet',
      'version_group': 'scarlet-violet',
      'generation': 'generation-ix',
    });
    expect(version.versionGroup, 'scarlet-violet');
    expect(version.label, 'Scarlet');
  });

  test('sortForDeposit prioriza a shininess do dex', () {
    const specimens = [
      Specimen(id: 3, form: 1),
      Specimen(id: 2, form: 1, isShiny: true),
      Specimen(id: 1, form: 1),
    ];
    expect(sortForDeposit(specimens, preferShiny: true).map((s) => s.id), [
      2,
      1,
      3,
    ]);
    expect(sortForDeposit(specimens, preferShiny: false).map((s) => s.id), [
      1,
      3,
      2,
    ]);
  });
}
