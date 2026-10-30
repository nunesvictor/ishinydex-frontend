/// Um pacote de golpes pequeno (o formato do `moves-AAAA.MM.DD.json`,
/// backend#134), para o Bulbasaur (Pokémon 1) do `catalogJson`.
Map<String, dynamic> movesJson() => {
  'schemaVersion': 1,
  'version': 'catalog-2026.10.03',
  'moves': [
    {
      'name': 'leech-seed',
      'label': 'Leech Seed',
      'type': 'grass',
      'category': 'status',
      'power': null,
      'accuracy': 90,
      'pp': 10,
      'priority': 0,
      'target': 'selected-pokemon',
      'effect': 'Drains HP.',
    },
    {
      'name': 'petal-dance',
      'label': 'Petal Dance',
      'type': 'grass',
      'category': 'special',
      'power': 120,
      'accuracy': 100,
      'pp': 10,
      'priority': 0,
      'target': 'random-opponent',
      'effect': '',
    },
    {
      'name': 'seed-bomb',
      'label': 'Seed Bomb',
      'type': 'grass',
      'category': 'physical',
      'power': 80,
      'accuracy': 100,
      'pp': 15,
      'priority': 0,
      'target': 'selected-pokemon',
      'effect': 'Hits.',
    },
    {
      'name': 'tackle',
      'label': 'Tackle',
      'type': 'normal',
      'category': 'physical',
      'power': 40,
      'accuracy': 100,
      'pp': 35,
      'priority': 0,
      'target': 'selected-pokemon',
      'effect': 'Hits.',
      // Antes do Sun/Moon (no X/Y), 50 de poder; antes do Scarlet/Violet,
      // 45 (vale o mais próximo).
      'past': [
        {
          'versionGroup': 'scarlet-violet',
          'power': 45,
          'accuracy': null,
          'pp': null,
          'type': null,
        },
        {
          'versionGroup': 'sun-moon',
          'power': 50,
          'accuracy': null,
          'pp': null,
          'type': null,
        },
      ],
    },
    {
      'name': 'vine-whip',
      'label': 'Vine Whip',
      'type': 'grass',
      'category': 'physical',
      'power': 45,
      'accuracy': 100,
      'pp': 25,
    },
  ],
  // O Champions não está no catálogo de teste: o nome pelo grupo.
  'versionGroups': ['x-y', 'scarlet-violet', 'champions'],
  'methods': [
    'level-up',
    'machine',
    'egg',
    'tutor',
    'light-ball-egg',
    'form-change',
    'zygarde-cube',
    'stadium-surfing-pikachu',
    'train',
    'xd-purification',
  ],
  'learnsets': {
    // Bulbasaur: no X/Y, o Tackle; no Scarlet/Violet, um de cada modo.
    '1': {
      '0': [3, 0, 1, 2, 1, 0],
      '1': [
        ...[4, 0, 3], // Vine Whip, Nv. 3
        ...[3, 0, 1], // Tackle, Nv. 1
        ...[0, 0, 1], // Leech Seed, Nv. 1 (empata com o Tackle: pelo nome)
        ...[2, 1, 0], // Seed Bomb, TM
        ...[3, 1, 0], // Tackle, TM
        ...[0, 2, 0], // Leech Seed, ovo
        ...[1, 3, 0], // Petal Dance, tutor
        ...[1, 8, 0], // Petal Dance, treino
      ],
      '2': [3, 8, 0],
    },
    // Venusaur: uma TM sem item no pacote.
    '3': {
      '1': [4, 1, 0],
    },
  },
  'machines': {
    'x-y': {'2': 'tm86'},
    'scarlet-violet': {'2': 'tm71', '3': 'tm1'},
  },
};
