/// A tabela de tipos da geração 6 em diante (com Fairy), conferida com a
/// Bulbapedia ("Type", 2026-10). É estática: não precisa do catálogo.
///
/// Para cada tipo de ataque, os tipos de defesa que recebem 2×, ½× e 0×;
/// os que não aparecem recebem 1×. Habilidades (Levitate, Thick Fat...),
/// Tera e Stellar ficam de fora (#230).
library;

/// Os 18 tipos, na ordem dos jogos.
const pokemonTypes = [
  'normal',
  'fire',
  'water',
  'electric',
  'grass',
  'ice',
  'fighting',
  'poison',
  'ground',
  'flying',
  'psychic',
  'bug',
  'rock',
  'ghost',
  'dragon',
  'dark',
  'steel',
  'fairy',
];

typedef _Row = ({List<String> double, List<String> half, List<String> none});

const Map<String, _Row> _chart = {
  'normal': (double: [], half: ['rock', 'steel'], none: ['ghost']),
  'fire': (
    double: ['grass', 'ice', 'bug', 'steel'],
    half: ['fire', 'water', 'rock', 'dragon'],
    none: [],
  ),
  'water': (
    double: ['fire', 'ground', 'rock'],
    half: ['water', 'grass', 'dragon'],
    none: [],
  ),
  'electric': (
    double: ['water', 'flying'],
    half: ['electric', 'grass', 'dragon'],
    none: ['ground'],
  ),
  'grass': (
    double: ['water', 'ground', 'rock'],
    half: ['fire', 'grass', 'poison', 'flying', 'bug', 'dragon', 'steel'],
    none: [],
  ),
  'ice': (
    double: ['grass', 'ground', 'flying', 'dragon'],
    half: ['fire', 'water', 'ice', 'steel'],
    none: [],
  ),
  'fighting': (
    double: ['normal', 'ice', 'rock', 'dark', 'steel'],
    half: ['poison', 'flying', 'psychic', 'bug', 'fairy'],
    none: ['ghost'],
  ),
  'poison': (
    double: ['grass', 'fairy'],
    half: ['poison', 'ground', 'rock', 'ghost'],
    none: ['steel'],
  ),
  'ground': (
    double: ['fire', 'electric', 'poison', 'rock', 'steel'],
    half: ['grass', 'bug'],
    none: ['flying'],
  ),
  'flying': (
    double: ['grass', 'fighting', 'bug'],
    half: ['electric', 'rock', 'steel'],
    none: [],
  ),
  'psychic': (
    double: ['fighting', 'poison'],
    half: ['psychic', 'steel'],
    none: ['dark'],
  ),
  'bug': (
    double: ['grass', 'psychic', 'dark'],
    half: ['fire', 'fighting', 'poison', 'flying', 'ghost', 'steel', 'fairy'],
    none: [],
  ),
  'rock': (
    double: ['fire', 'ice', 'flying', 'bug'],
    half: ['fighting', 'ground', 'steel'],
    none: [],
  ),
  'ghost': (double: ['psychic', 'ghost'], half: ['dark'], none: ['normal']),
  'dragon': (double: ['dragon'], half: ['steel'], none: ['fairy']),
  'dark': (
    double: ['psychic', 'ghost'],
    half: ['fighting', 'dark', 'fairy'],
    none: [],
  ),
  'steel': (
    double: ['ice', 'rock', 'fairy'],
    half: ['fire', 'water', 'electric', 'steel'],
    none: [],
  ),
  'fairy': (
    double: ['fighting', 'dragon', 'dark'],
    half: ['fire', 'poison', 'steel'],
    none: [],
  ),
};

/// O multiplicador de um golpe do tipo [attack] num Pokémon do tipo
/// [defense] (um tipo só). Sem [withFairy] (até a 5ª geração), o Steel
/// também resistia a Ghost e Dark.
double effectiveness(String attack, String defense, {bool withFairy = true}) {
  if (!withFairy &&
      defense == 'steel' &&
      (attack == 'ghost' || attack == 'dark')) {
    return 0.5;
  }
  final row = _chart[attack];
  if (row == null) return 1;
  if (row.none.contains(defense)) return 0;
  if (row.double.contains(defense)) return 2;
  if (row.half.contains(defense)) return 0.5;
  return 1;
}

/// Quanto cada tipo de ataque causa num Pokémon com os [types] (um ou dois):
/// os multiplicadores de cada tipo se multiplicam (Ice contra
/// Dragon/Ground: 2 × 2 = 4). Tipos fora da tabela não contam.
Map<String, double> defenseMultipliers(List<String> types) {
  final known = types.where(_chart.containsKey).toList();
  return {
    for (final attack in pokemonTypes)
      attack: known.fold(1, (m, t) => m * effectiveness(attack, t)),
  };
}

/// Os tipos que recebem 2× de um golpe do tipo [type] (o STAB).
List<String> superEffectiveAgainst(String type) => [
  for (final defense in pokemonTypes)
    if (effectiveness(type, defense) == 2) defense,
];

/// O tipo está na tabela (o Stellar e os desconhecidos, não).
bool isChartType(String type) => _chart.containsKey(type);
