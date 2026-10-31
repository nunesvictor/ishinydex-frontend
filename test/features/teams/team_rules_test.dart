import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/teams/domain/models.dart';
import 'package:ishinydex/features/teams/domain/team_rules.dart';
import 'package:ishinydex/features/teams/presentation/team_widgets.dart';

import 'team_fixture.dart';

void main() {
  group('stats calculados', () {
    // O Ogerpon Cornerstone Mask do mock: Jolly, 252 Atq / 4 Def. Esp. / 252
    // Vel, IVs 31, nível 50.
    test('como nos jogos, com a natureza', () {
      expect(statValue('hp', base: 80, level: 50, ev: 0, iv: 31), 155);
      expect(statValue('attack', base: 120, level: 50, ev: 252, iv: 31), 172);
      expect(
        statValue('special-defense', base: 96, level: 50, ev: 4, iv: 31),
        117,
      );
      expect(
        statValue('speed', base: 110, level: 50, ev: 252, iv: 31, factor: 1.1),
        178,
      );
      expect(
        statValue(
          'special-attack',
          base: 60,
          level: 50,
          ev: 0,
          iv: 31,
          factor: 0.9,
        ),
        72,
      );
    });

    test('o Shedinja tem sempre 1 de HP', () {
      expect(
        statValue('hp', base: 1, level: 50, ev: 252, iv: 31, alwaysOneHp: true),
        1,
      );
    });

    test('a natureza aumenta um stat e diminui outro', () {
      const jolly = (up: 'speed', down: 'special-attack');
      expect(
        natureFactor('speed', increased: jolly.up, decreased: jolly.down),
        1.1,
      );
      expect(
        natureFactor(
          'special-attack',
          increased: jolly.up,
          decreased: jolly.down,
        ),
        0.9,
      );
      expect(
        natureFactor('attack', increased: jolly.up, decreased: jolly.down),
        1,
      );
      // Neutra: aumenta e diminui o mesmo.
      expect(
        natureFactor('attack', increased: 'attack', decreased: 'attack'),
        1,
      );
      expect(natureFactor('attack'), 1);
    });
  });

  test('o EV vai até 252 e o total até 510', () {
    const member = TeamMember(form: 1, evs: {'attack': 252, 'speed': 252});
    expect(member.evTotal, 504);
    expect(maxEvFor(member, 'hp'), 6);
    expect(maxEvFor(member, 'attack'), 252);
    expect(maxEvFor(const TeamMember(form: 1), 'hp'), 252);
    expect(member.ev('hp'), 0);
    expect(member.iv('hp'), 31);
  });

  test('o time cheio tem 6', () {
    const team = Team(id: 1, name: 'A', versionGroup: 'scarlet-violet');
    expect(team.isFull, isFalse);
    expect(
      team.copyWith(members: List.filled(6, const TeamMember(form: 1))).isFull,
      isTrue,
    );
  });

  test('os jogos com time: com item, habilidade e natureza', () {
    expect(
      groupHasTeams('scarlet-violet', generation: 'generation-ix'),
      isTrue,
    );
    expect(groupHasTeams('emerald', generation: 'generation-iii'), isTrue);
    expect(groupHasTeams('gold-silver', generation: 'generation-ii'), isFalse);
    expect(groupHasTeams('red-blue', generation: 'generation-i'), isFalse);
    expect(groupHasTeams('x-y', generation: null), isFalse);
    expect(
      groupHasTeams('the-teal-mask', generation: 'generation-ix'),
      isFalse,
    );
    expect(groupHasTeams('legends-za', generation: 'generation-ix'), isTrue);
    expect(
      groupHasTeams('mega-dimension', generation: 'generation-ix'),
      isFalse,
    );
    expect(
      groupHasTeams('legends-arceus', generation: 'generation-viii'),
      isFalse,
    );
  });

  group('nomes no Showdown', () {
    String name(String pokemon, String species, {bool isDefault = false}) =>
        showdownSpecies(
          pokemon: pokemon,
          species: species,
          isDefault: isDefault,
        );

    test('a espécie e a forma', () {
      expect(name('calyrex-shadow', 'calyrex'), 'Calyrex-Shadow');
      expect(name('urshifu-rapid-strike', 'urshifu'), 'Urshifu-Rapid-Strike');
      expect(
        name('flutter-mane', 'flutter-mane', isDefault: true),
        'Flutter Mane',
      );
      // A forma padrão fica só com a espécie.
      expect(name('keldeo-ordinary', 'keldeo', isDefault: true), 'Keldeo');
      // Forma que não começa pela espécie: só a espécie.
      expect(name('odd', 'eevee'), 'Eevee');
    });

    test('as que o Showdown chama diferente', () {
      expect(
        name('ogerpon-cornerstone-mask', 'ogerpon'),
        'Ogerpon-Cornerstone',
      );
      expect(name('meowstic-female', 'meowstic'), 'Meowstic-F');
      expect(
        name('maushold-family-of-four', 'maushold', isDefault: true),
        'Maushold-Four',
      );
      expect(name('mr-mime-galar', 'mr-mime'), 'Mr. Mime-Galar');
      expect(name('ho-oh', 'ho-oh', isDefault: true), 'Ho-Oh');
    });

    test('as habilidades em inglês', () {
      expect(abilityLabel('as-one-spectrier'), 'As One (Spectrier)');
      expect(abilityLabel('unseen-fist'), 'Unseen Fist');
    });
  });

  test('o texto do Showdown', () {
    final text = showdownText([
      (
        species: 'Calyrex-Shadow',
        item: 'Focus Sash',
        ability: 'As One (Spectrier)',
        level: 50,
        tera: 'fairy',
        evs: const {'hp': 4, 'special-attack': 252, 'speed': 252},
        ivs: const {'attack': 0},
        nature: 'Timid',
        moves: const ['Astral Barrage', 'Protect'],
      ),
      (
        species: 'Pichu',
        item: null,
        ability: null,
        level: 100,
        tera: null,
        evs: const {'hp': 0},
        ivs: const {'hp': 31},
        nature: null,
        moves: const [],
      ),
    ]);
    expect(text, '''
Calyrex-Shadow @ Focus Sash
Ability: As One (Spectrier)
Level: 50
Tera Type: Fairy
EVs: 4 HP / 252 SpA / 252 Spe
Timid Nature
IVs: 0 Atk
- Astral Barrage
- Protect

Pichu''');
  });

  test('o membro de forma fora do catálogo sai pelo nome da forma', () {
    final text = teamShowdownText(
      const Team(
        id: 1,
        name: 'T',
        versionGroup: 'scarlet-violet',
        members: [
          TeamMember(
            form: 999999,
            formRef: FormRef(
              id: 999999,
              name: 'missingno',
              pokeapiId: 999999,
              spriteUrl: '',
              shinySpriteUrl: '',
            ),
            item: 'made-up',
          ),
          TeamMember(form: 424242),
        ],
      ),
      teamCatalog(),
      teamMoves(),
    );
    expect(text, 'Missingno @ made-up\nLevel: 50\n\n\nLevel: 50');
  });
}
