import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/utils/pokemon_types.dart';
import 'package:ishinydex/core/utils/type_chart.dart';
import 'package:ishinydex/features/teams/domain/models.dart';

/// Os stats, na ordem dos jogos (e do Showdown).
const teamStats = [
  'hp',
  'attack',
  'defense',
  'special-attack',
  'special-defense',
  'speed',
];

/// Os grupos de versões com Tera (#231).
const teraGroups = {'scarlet-violet'};

/// Os jogos sem habilidade: o Legends: Z-A.
const groupsWithoutAbilities = {'legends-za'};

/// Os jogos que o Showdown não tem, e o time não exporta: o Legends: Z-A.
const groupsWithoutExport = {'legends-za'};

/// Os tipos Tera: os 18 e o Stellar.
const List<String> teraTypes = [...pokemonTypes, 'stellar'];

/// Os jogos que não têm time: sem item segurado, habilidade e natureza
/// como hoje (a 1ª e a 2ª geração, o Let's Go e o Legends: Arceus). O DLC
/// do Z-A fica com o jogo.
const _groupsWithoutTeams = {
  'lets-go-pikachu-lets-go-eevee',
  'legends-arceus',
  'mega-dimension',
};

/// O grupo [group] aceita times: tem item segurado e é da 3ª geração em
/// diante. As DLCs ficam de fora (o time é do jogo).
bool groupHasTeams(String group, {required String? generation}) =>
    !_groupsWithoutTeams.contains(group) &&
    !group.startsWith('the-') &&
    switch (generation) {
      'generation-i' || 'generation-ii' || null => false,
      _ => true,
    };

/// O multiplicador da natureza no [stat]: 1,1 no que ela aumenta, 0,9 no
/// que diminui (o HP nunca muda).
double natureFactor(String stat, {String? increased, String? decreased}) =>
    increased == decreased
    ? 1
    : stat == increased
    ? 1.1
    : stat == decreased
    ? 0.9
    : 1;

/// O stat calculado como nos jogos (3ª geração em diante): [base], o IV, o
/// EV (que conta de 4 em 4) e o nível; fora o HP, a natureza ([factor]).
/// O Shedinja tem sempre 1 de HP ([alwaysOneHp]).
int statValue(
  String stat, {
  required int base,
  required int level,
  required int ev,
  required int iv,
  double factor = 1,
  bool alwaysOneHp = false,
}) {
  final core = (2 * base + iv + ev ~/ 4) * level ~/ 100;
  if (stat == 'hp') return alwaysOneHp ? 1 : core + level + 10;
  return ((core + 5) * factor).floor();
}

/// Quanto o EV do [stat] pode chegar, sem passar de 252 nem do total de
/// 510 do membro.
int maxEvFor(TeamMember member, String stat) {
  final others = member.evTotal - member.ev(stat);
  final left = TeamMember.maxEvTotal - others;
  return left < TeamMember.maxEv ? left : TeamMember.maxEv;
}

/// O nome da forma no Showdown (#231), a partir dos nomes da PokéAPI: a
/// espécie e, fora da forma padrão, a forma (`calyrex-shadow` →
/// `Calyrex-Shadow`). O Showdown lê o nome sem espaço nem pontuação; a
/// tabela corrige os que ele chama diferente.
String showdownSpecies({
  required String pokemon,
  required String species,
  required bool isDefault,
}) {
  if (_showdownNames[pokemon] case final name?) return name;
  final base = _showdownNames[species] ?? prettifyName(species);
  if (isDefault || !pokemon.startsWith('$species-')) return base;
  final forme = pokemon
      .substring(species.length + 1)
      .split('-')
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join('-');
  return '$base-$forme';
}

const _showdownNames = {
  // Espécies com hífen, ponto ou acento no nome.
  'ho-oh': 'Ho-Oh',
  'porygon-z': 'Porygon-Z',
  'jangmo-o': 'Jangmo-o',
  'hakamo-o': 'Hakamo-o',
  'kommo-o': 'Kommo-o',
  'wo-chien': 'Wo-Chien',
  'chien-pao': 'Chien-Pao',
  'ting-lu': 'Ting-Lu',
  'chi-yu': 'Chi-Yu',
  'nidoran-f': 'Nidoran-F',
  'nidoran-m': 'Nidoran-M',
  'mr-mime': 'Mr. Mime',
  'mime-jr': 'Mime Jr.',
  'mr-rime': 'Mr. Rime',
  'type-null': 'Type: Null',
  'farfetchd': 'Farfetch’d',
  'sirfetchd': 'Sirfetch’d',
  'flabebe': 'Flabébé',
  // Formas que o Showdown chama diferente da PokéAPI.
  'meowstic-female': 'Meowstic-F',
  'indeedee-female': 'Indeedee-F',
  'basculegion-female': 'Basculegion-F',
  'oinkologne-female': 'Oinkologne-F',
  'necrozma-dusk': 'Necrozma-Dusk-Mane',
  'necrozma-dawn': 'Necrozma-Dawn-Wings',
  'tauros-paldea-combat-breed': 'Tauros-Paldea-Combat',
  'tauros-paldea-blaze-breed': 'Tauros-Paldea-Blaze',
  'tauros-paldea-aqua-breed': 'Tauros-Paldea-Aqua',
  'maushold-family-of-four': 'Maushold-Four',
  'maushold-family-of-three': 'Maushold',
  'squawkabilly-blue-plumage': 'Squawkabilly-Blue',
  'squawkabilly-yellow-plumage': 'Squawkabilly-Yellow',
  'squawkabilly-white-plumage': 'Squawkabilly-White',
  'ogerpon-wellspring-mask': 'Ogerpon-Wellspring',
  'ogerpon-hearthflame-mask': 'Ogerpon-Hearthflame',
  'ogerpon-cornerstone-mask': 'Ogerpon-Cornerstone',
  'darmanitan-galar-standard': 'Darmanitan-Galar',
  'greninja-battle-bond': 'Greninja-Bond',
  'rockruff-own-tempo': 'Rockruff-Dusk',
  'zygarde-10': 'Zygarde-10%',
  'zygarde-10-power-construct': 'Zygarde-10%',
  'zygarde-50-power-construct': 'Zygarde',
  'pikachu-original-cap': 'Pikachu-Original',
  'pikachu-hoenn-cap': 'Pikachu-Hoenn',
  'pikachu-sinnoh-cap': 'Pikachu-Sinnoh',
  'pikachu-unova-cap': 'Pikachu-Unova',
  'pikachu-kalos-cap': 'Pikachu-Kalos',
  'pikachu-alola-cap': 'Pikachu-Alola',
  'pikachu-partner-cap': 'Pikachu-Partner',
  'pikachu-world-cap': 'Pikachu-World',
};

/// O nome de uma habilidade em inglês, do nome da PokéAPI
/// (`as-one-spectrier` → "As One (Spectrier)").
String abilityLabel(String ability) =>
    _abilityLabels[ability] ?? prettifyName(ability);

const _abilityLabels = {
  'as-one-spectrier': 'As One (Spectrier)',
  'as-one-glastrier': 'As One (Glastrier)',
};

/// Um membro pronto para o texto do Showdown: os nomes já em inglês.
typedef ShowdownSet = ({
  String species,
  String? item,
  String? ability,
  int level,
  String? tera,
  Map<String, int> evs,
  Map<String, int> ivs,
  String? nature,
  List<String> moves,
});

const _statAbbreviations = {
  'hp': 'HP',
  'attack': 'Atk',
  'defense': 'Def',
  'special-attack': 'SpA',
  'special-defense': 'SpD',
  'speed': 'Spe',
};

/// O time no formato de texto do Showdown (Teambuilder → Import from
/// text): um bloco por membro, separados por uma linha em branco. O nível
/// 100, os EVs 0 e os IVs 31 ficam de fora, como no próprio Showdown.
String showdownText(List<ShowdownSet> sets) => [
  for (final s in sets)
    [
      if (s.item case final item?) '${s.species} @ $item' else s.species,
      if (s.ability case final ability?) 'Ability: $ability',
      if (s.level != 100) 'Level: ${s.level}',
      if (s.tera case final tera?) 'Tera Type: ${typeLabel(tera)}',
      if (_spread(s.evs, skip: 0) case final evs?) 'EVs: $evs',
      if (s.nature case final nature?) '$nature Nature',
      if (_spread(s.ivs, skip: TeamMember.maxIv) case final ivs?) 'IVs: $ivs',
      for (final move in s.moves) '- $move',
    ].join('\n'),
].join('\n\n');

String? _spread(Map<String, int> values, {required int skip}) {
  final parts = [
    for (final stat in teamStats)
      if (values[stat] case final value? when value != skip)
        '$value ${_statAbbreviations[stat]}',
  ];
  return parts.isEmpty ? null : parts.join(' / ');
}
