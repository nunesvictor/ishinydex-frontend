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

  test('SpecimenQuery.copyWith muda só o pedido', () {
    final query = emptySpecimenQuery.copyWith(alphaOnly: true);
    expect(query.alphaOnly, true);
    expect(query.fromGoOnly, false);
    expect(query.copyWith(search: 'x').alphaOnly, true);
    expect(query.copyWith(fromGoOnly: true).fromGoOnly, true);
  });

  test('SpecimenQuery: igualdade por valor, inclusive das listas', () {
    // Chave de provider: duas consultas iguais precisam ser a mesma chave.
    expect(
      const SpecimenQuery(pokeballs: ['dive-ball']),
      SpecimenQuery(pokeballs: ['dive-ball'].toList()),
    );
  });

  test('SpecimenQuery.toQueryParameters envia só os filtros usados', () {
    expect(emptySpecimenQuery.toQueryParameters(), isEmpty);
    expect(
      emptySpecimenQuery.copyWith(search: '  ').toQueryParameters(),
      isEmpty,
    );
    final full = SpecimenQuery(
      search: ' bulba ',
      status: SpecimenStatus.available,
      shinyOnly: true,
      alphaOnly: true,
      fromGoOnly: true,
      pokeballs: const ['dive-ball', 'dusk-ball'],
      withoutPokeball: true,
      types: const ['water', 'flying'],
      ots: const [1, 3],
      withoutOt: true,
      generations: const ['generation-i', 'generation-iv'],
      genders: const ['female'],
      natures: const ['jolly'],
      languages: const ['ja'],
      ability: ' levi ',
      capturedAfter: DateTime(2026, 1, 2),
      capturedBefore: DateTime(2026, 12, 31),
      ordering: SpecimenOrdering.capturedDesc,
    );
    expect(full.toQueryParameters(), {
      'search': 'bulba',
      'available': true,
      'is_shiny': true,
      'is_alpha': true,
      'is_from_go': true,
      'pokeball': 'dive-ball,dusk-ball,none',
      'type': 'water,flying',
      'ot': '1,3,none',
      'generation': 'generation-i,generation-iv',
      'gender': 'female',
      'nature': 'jolly',
      'language': 'ja',
      'ability': 'levi',
      'captured_after': '2026-01-02',
      'captured_before': '2026-12-31',
      'ordering': '-captured_at',
    });
    // Só "sem": a lista vai com o valor especial sozinho.
    expect(const SpecimenQuery(withoutOt: true).toQueryParameters(), {
      'ot': 'none',
    });
    expect(full.advancedCount, 10);

    final cleared = full.clearAdvanced();
    expect(cleared.advancedCount, 0);
    expect(cleared.toQueryParameters(), {
      'search': 'bulba',
      'available': true,
      'is_shiny': true,
      'is_alpha': true,
      'is_from_go': true,
    });
  });

  test('SpecimenQuery.advancedCount conta grupos, não valores', () {
    expect(emptySpecimenQuery.advancedCount, 0);
    // Filtros rápidos não contam.
    expect(const SpecimenQuery(search: 'x', shinyOnly: true).advancedCount, 0);
    expect(
      const SpecimenQuery(
        pokeballs: ['a', 'b'],
        withoutPokeball: true,
      ).advancedCount,
      1,
    );
    expect(const SpecimenQuery(ability: '  ').advancedCount, 0);
    expect(SpecimenQuery(capturedBefore: DateTime(2026)).advancedCount, 1);
  });

  test('SpecimenOrdering → ordering da API', () {
    expect(SpecimenOrdering.values.map((o) => o.param), [
      'dex',
      '-captured_at',
      'captured_at',
      '-created_at',
    ]);
  });

  test('SpecimenStatus → filtro available da API', () {
    expect(SpecimenStatus.all.availableParam, isNull);
    expect(SpecimenStatus.available.availableParam, true);
    expect(SpecimenStatus.deposited.availableParam, false);
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
