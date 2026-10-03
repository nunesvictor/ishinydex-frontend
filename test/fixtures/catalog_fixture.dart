/// Um `catalog.json` pequeno, no formato do `exportcatalog` do backend.
///
/// Bulbasaur → Ivysaur → Venusaur (com a Mega), Eevee → Vaporeon/Espeon
/// (ramificação), Pichu (bebê), Mewtwo (lendário) e Nihilego (Ultra Beast).
library;

Map<String, dynamic> _form(
  int id,
  String name, {
  int? pokemon,
  String formName = '',
  bool isDefault = true,
  String group = 'red-blue',
  List<String> types = const ['normal'],
}) => {
  'id': id,
  'name': name,
  'formName': formName,
  'pokemon': pokemon ?? id,
  'formOrder': 1,
  'isDefault': isDefault,
  'isBattleOnly': false,
  'isMega': formName == 'mega',
  'versionGroup': group,
  'types': types,
  'sprite': 'pokemon/other/home/$id.png',
  'shinySprite': 'pokemon/other/home/shiny/$id.png',
};

Map<String, dynamic> _pokemon(
  int id,
  String species, {
  bool isDefault = true,
  List<String> abilities = const ['overgrow'],
}) => {
  'id': id,
  'name': species,
  'species': species,
  'isDefault': isDefault,
  'height': 7,
  'weight': 69,
  'types': ['normal'],
  'abilities': [
    for (final (i, a) in abilities.indexed)
      {'ability': a, 'slot': i + 1, 'isHidden': false},
  ],
  'stats': [
    {'stat': 'hp', 'base': 45, 'effort': 0},
    {'stat': 'special-attack', 'base': 65, 'effort': 1},
  ],
};

Map<String, dynamic> _species(
  String name,
  int number, {
  String? from,
  int genderRate = 1,
  bool baby = false,
  bool legendary = false,
}) => {
  'name': name,
  'nationalNumber': number,
  'generation': number > 151 ? 'generation-ii' : 'generation-i',
  'genderRate': genderRate,
  'captureRate': 45,
  'hatchCounter': 20,
  'isBaby': baby,
  'isLegendary': legendary,
  'isMythical': false,
  'evolvesFrom': from,
};

Map<String, dynamic> catalogJson({int schemaVersion = 1}) => {
  'schemaVersion': schemaVersion,
  'version': 'catalog-2026.10.03',
  'generatedAt': '2026-10-03T10:00:00+00:00',
  'spritesRepository': 'https://github.com/PokeAPI/sprites',
  'forms': [
    _form(1, 'bulbasaur', types: ['grass', 'poison']),
    _form(2, 'ivysaur'),
    _form(3, 'venusaur'),
    _form(
      10033,
      'venusaur-mega',
      formName: 'mega',
      isDefault: false,
      group: 'x-y',
    ),
    _form(133, 'eevee'),
    _form(134, 'vaporeon', types: ['water']),
    _form(196, 'espeon', group: 'gold-silver'),
    _form(150, 'mewtwo'),
    _form(172, 'pichu', group: 'gold-silver'),
    _form(793, 'nihilego', group: 'sun-moon'),
  ],
  'pokemon': [
    _pokemon(1, 'bulbasaur'),
    _pokemon(2, 'ivysaur'),
    _pokemon(3, 'venusaur'),
    _pokemon(10033, 'venusaur', isDefault: false),
    _pokemon(133, 'eevee'),
    _pokemon(134, 'vaporeon'),
    _pokemon(196, 'espeon'),
    _pokemon(150, 'mewtwo'),
    _pokemon(172, 'pichu'),
    _pokemon(793, 'nihilego', abilities: ['beast-boost']),
  ],
  'species': [
    _species('bulbasaur', 1),
    _species('ivysaur', 2, from: 'bulbasaur'),
    _species('venusaur', 3, from: 'ivysaur'),
    _species('eevee', 133),
    _species('vaporeon', 134, from: 'eevee'),
    _species('espeon', 196, from: 'eevee'),
    _species('mewtwo', 150, genderRate: -1, legendary: true),
    _species('pichu', 172, baby: true),
    _species('nihilego', 793, genderRate: -1),
  ],
  'versionGroups': [
    {
      'name': 'scarlet-violet',
      'generation': 'generation-ix',
      'order': 25,
      'versions': ['scarlet', 'violet'],
      'originMark': 'paldea',
    },
    {
      'name': 'red-blue',
      'generation': 'generation-i',
      'order': 1,
      'versions': ['red', 'blue'],
      'originMark': 'game-boy',
    },
    {
      'name': 'gold-silver',
      'generation': 'generation-ii',
      'order': 3,
      'versions': ['gold', 'silver'],
      'originMark': 'game-boy',
    },
    {
      'name': 'x-y',
      'generation': 'generation-vi',
      'order': 15,
      'versions': ['x', 'y'],
      'originMark': 'kalos',
    },
    {
      'name': 'sun-moon',
      'generation': 'generation-vii',
      'order': 17,
      'versions': ['sun', 'moon'],
      'originMark': 'alola',
    },
    {
      'name': 'emerald',
      'generation': 'generation-iii',
      'order': 6,
      'versions': ['emerald'],
      'originMark': null,
    },
  ],
  'versions': [
    {
      'name': 'scarlet',
      'versionGroup': 'scarlet-violet',
      'receivesFromHome': true,
    },
    {
      'name': 'violet',
      'versionGroup': 'scarlet-violet',
      'receivesFromHome': true,
    },
    {'name': 'red', 'versionGroup': 'red-blue', 'receivesFromHome': false},
    {'name': 'blue', 'versionGroup': 'red-blue', 'receivesFromHome': false},
    {'name': 'gold', 'versionGroup': 'gold-silver', 'receivesFromHome': false},
    {
      'name': 'silver',
      'versionGroup': 'gold-silver',
      'receivesFromHome': false,
    },
    {'name': 'x', 'versionGroup': 'x-y', 'receivesFromHome': false},
    {'name': 'y', 'versionGroup': 'x-y', 'receivesFromHome': false},
    {'name': 'sun', 'versionGroup': 'sun-moon', 'receivesFromHome': false},
    {'name': 'moon', 'versionGroup': 'sun-moon', 'receivesFromHome': false},
    {'name': 'emerald', 'versionGroup': 'emerald', 'receivesFromHome': false},
  ],
  'defaultDex': [1, 2, 3, 133, 134, 196, 150, 172, 793],
  'choices': {
    'language': [
      {'value': 'pt-br', 'label': 'Português brasileiro'},
    ],
    'gender': [
      {'value': 'male', 'label': 'Macho'},
      {'value': 'female', 'label': 'Fêmea'},
      {'value': 'genderless', 'label': 'Sem gênero'},
    ],
    'nature': [
      {
        'value': 'modest',
        'label': 'Modest',
        'increased': 'special-attack',
        'decreased': 'attack',
      },
      {
        'value': 'hardy',
        'label': 'Hardy',
        'increased': null,
        'decreased': null,
      },
    ],
    'pokeball': [
      {
        'value': 'poke-ball',
        'label': 'Poké Ball',
        'sprite': 'items/poke-ball.png',
      },
    ],
    'type': [
      {
        'value': 'grass',
        'label': 'Planta',
        'sprite': 'types/generation-viii/sword-shield/small/12.png',
      },
      {'value': 'poison', 'label': 'Venenoso', 'sprite': null},
    ],
    'generation': [
      {'value': 'generation-i', 'label': 'Geração I'},
    ],
    'origin_mark': [
      {'value': 'game-boy', 'label': 'GB'},
      {'value': 'none', 'label': 'Sem marca de origem'},
    ],
  },
  'shinyLocks': [
    {
      'caption': 'Mewtwo de evento',
      'description': '',
      'lockType': 'distro-only',
      'active': true,
      'forms': [150],
    },
  ],
};
