import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/teams/domain/models.dart';

import 'team_fixture.dart';

const _sv = 'scarlet-violet';

Matcher _invalid(String field, Problem problem) => isA<ValidationFailure>()
    .having((f) => f.errorsFor(field), field, [problem]);

void main() {
  late FakeBackend backend;

  setUp(() => backend = teamBackend());

  test('o catálogo: os itens de cada jogo e os nomes do Pokémon', () {
    final catalog = teamCatalog();
    expect(
      [for (final i in catalog.heldItemsIn(_sv)) i.name],
      ['focus-sash', 'leftovers'],
    );
    expect(catalog.heldItemsIn('emerald'), isEmpty);
    expect(
      catalog.heldItem('focus-sash')?.spriteUrl,
      'https://sprites/items/focus-sash.png',
    );
    expect(catalog.heldItem('leftovers')?.spriteUrl, isNull);
    expect(catalog.heldItem('nada'), isNull);
    expect(catalog.pokemonNames(10033), (
      pokemon: 'venusaur',
      species: 'venusaur',
      isDefault: false,
    ));
    expect(catalog.pokemonNames(99999), isNull);
    expect(catalog.versionGroupNames, contains(_sv));
  });

  test('cria, grava e apaga o time', () async {
    final team = await backend.saveTeam(
      const Team(
        id: 0,
        name: '  Regulamento G  ',
        versionGroup: _sv,
        members: [
          TeamMember(
            form: 1,
            ability: 'overgrow',
            tera: 'fairy',
            moves: ['tackle'],
            evs: {'attack': 252, 'hp': 0},
            ivs: {'speed': 0, 'hp': 31},
          ),
        ],
      ),
    );
    expect(team.id, isPositive);
    expect(team.name, 'Regulamento G');
    final member = team.members.single;
    expect(member.formRef?.name, 'bulbasaur');
    expect(member.tera, 'fairy');
    // Só o que foge do padrão.
    expect(member.evs, {'attack': 252});
    expect(member.ivs, {'speed': 0});

    await backend.saveTeam(team.copyWith(name: 'Outro'));
    expect([for (final t in await backend.fetchTeams()) t.name], ['Outro']);

    await backend.deleteTeam(team.id);
    expect(await backend.fetchTeams(), isEmpty);
    expect(backend.deleteTeam(team.id), throwsA(isA<NotFoundFailure>()));
  });

  test('o Tera só fica no Scarlet/Violet', () async {
    final team = await backend.saveTeam(
      const Team(
        id: 0,
        name: 'X/Y',
        versionGroup: 'x-y',
        members: [TeamMember(form: 1, tera: 'fairy')],
      ),
    );
    expect(team.members.single.tera, isNull);
  });

  test('as regras do time e de cada membro', () async {
    Future<Team> save(Team team) => backend.saveTeam(team);
    const base = Team(id: 0, name: 'T', versionGroup: _sv);
    Team withMember(TeamMember m) => base.copyWith(members: [m]);

    expect(
      save(const Team(id: 99, name: 'T', versionGroup: _sv)),
      throwsA(isA<NotFoundFailure>()),
    );
    expect(
      save(base.copyWith(name: ' ')),
      throwsA(_invalid('name', const Problem.blank())),
    );
    expect(
      save(base.copyWith(versionGroup: 'gold-silver')),
      throwsA(_invalid('versionGroup', const Problem.noTeamsInGame())),
    );
    expect(
      save(base.copyWith(members: List.filled(7, const TeamMember(form: 1)))),
      throwsA(_invalid('members', const Problem.teamFull())),
    );
    expect(
      save(withMember(const TeamMember(form: 424242))),
      throwsA(_invalid('form', const Problem.invalidForm())),
    );
    expect(
      save(withMember(const TeamMember(form: 1, specimen: 77))),
      throwsA(_invalid('specimen', const Problem.specimenNotFound())),
    );
    for (final level in [0, 101]) {
      expect(
        save(withMember(TeamMember(form: 1, level: level))),
        throwsA(_invalid('level', const Problem.invalidLevel())),
      );
    }
    expect(
      save(withMember(const TeamMember(form: 1, ability: 'levitate'))),
      throwsA(_invalid('ability', const Problem.invalidAbility())),
    );
    expect(
      save(
        withMember(const TeamMember(form: 1, moves: ['a', 'b', 'c', 'd', 'e'])),
      ),
      throwsA(_invalid('moves', const Problem.invalidMoves())),
    );
    expect(
      save(withMember(const TeamMember(form: 1, moves: ['a', 'a']))),
      throwsA(_invalid('moves', const Problem.invalidMoves())),
    );
    expect(
      save(withMember(const TeamMember(form: 1, evs: {'hp': 253}))),
      throwsA(_invalid('evs', const Problem.invalidEvs())),
    );
    expect(
      save(withMember(const TeamMember(form: 1, evs: {'hp': -1}))),
      throwsA(_invalid('evs', const Problem.invalidEvs())),
    );
    expect(
      save(
        withMember(
          const TeamMember(
            form: 1,
            evs: {'hp': 252, 'attack': 252, 'speed': 8},
          ),
        ),
      ),
      throwsA(_invalid('evs', const Problem.invalidEvs())),
    );
    for (final iv in [-1, 32]) {
      expect(
        save(withMember(TeamMember(form: 1, ivs: {'hp': iv}))),
        throwsA(_invalid('ivs', const Problem.invalidIvs())),
      );
    }
  });

  test('o membro ligado a um espécime; apagado, deixa de estar', () async {
    final specimen = await backend.create(
      const SpecimenDraft(form: 1, nature: 'modest', ability: 'overgrow'),
    );
    await backend.create(const SpecimenDraft(form: 3));
    final ofForm = await backend.fetchSpecimensOfForm(1);
    expect([for (final s in ofForm) s.id], contains(specimen.id));
    expect({for (final s in ofForm) s.form}, {1});
    await backend.saveTeam(
      Team(
        id: 0,
        name: 'T',
        versionGroup: _sv,
        members: [TeamMember(form: 1, specimen: specimen.id)],
      ),
    );
    expect(
      (await backend.fetchTeams()).single.members.single.specimen,
      specimen.id,
    );

    await backend.release(specimen.id);
    expect((await backend.fetchTeams()).single.members.single.specimen, isNull);
  });

  test('os times nos registros: ida e volta, e órfãos guardados', () async {
    await backend.saveTeam(
      const Team(
        id: 0,
        name: 'T',
        versionGroup: _sv,
        members: [
          TeamMember(
            form: 1,
            level: 70,
            ability: 'chlorophyll',
            nature: 'modest',
            item: 'focus-sash',
            tera: 'grass',
            moves: ['tackle', 'vine-whip'],
            evs: {'speed': 252},
            ivs: {'attack': 0},
          ),
          TeamMember(form: 3),
        ],
      ),
    );
    final records = backend.records;
    final saved = (records['teams']!.single['members'] as List)
        .cast<Map<String, dynamic>>();
    expect(saved.first, {
      'form': 1,
      'level': 70,
      'ability': 'chlorophyll',
      'nature': 'modest',
      'item': 'focus-sash',
      'tera': 'grass',
      'moves': ['tackle', 'vine-whip'],
      'evs': {'speed': 252},
      'ivs': {'attack': 0},
    });
    expect(saved.last, {'form': 3, 'level': 50, 'moves': <String>[]});

    // Um time com forma fora do catálogo volta igual no próximo arquivo.
    const orphan = {
      'id': 9,
      'name': 'Órfão',
      'versionGroup': _sv,
      'members': [
        {'form': 424242, 'level': 50, 'moves': <String>[]},
      ],
    };
    final restored = teamBackend()
      ..replaceRecords({
        ...records,
        'teams': [...records['teams']!, orphan],
      });
    final teams = await restored.fetchTeams();
    expect(
      teams.single.members.first,
      (await backend.fetchTeams()).single.members.first,
    );
    expect(teams.single.members.last.formRef?.name, 'venusaur');
    expect(restored.records['teams'], hasLength(2));
    expect(restored.records['teams']!.last, orphan);
  });
}
