import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/moves/domain/moves_data.dart';

import '../../fixtures/catalog_fixture.dart';
import '../../fixtures/moves_fixture.dart';

/// O catálogo de teste com o que o team builder usa (#231): os stats e as
/// duas habilidades do Bulbasaur (a 2ª oculta), o Venusaur e mais cinco
/// formas como Water/Ground,
/// os itens seguráveis do Scarlet/Violet (o Leftovers sem sprite), do X/Y e
/// do Z-A, e o arquivo dos golpes.
Catalog teamCatalog() {
  final json = catalogJson();
  final pokemon = [
    for (final p in json['pokemon'] as List)
      Map<String, dynamic>.of(p as Map<String, dynamic>),
  ];
  pokemon.first
    ..['abilities'] = [
      {'ability': 'overgrow', 'slot': 1, 'isHidden': false},
      {'ability': 'chlorophyll', 'slot': 3, 'isHidden': true},
    ]
    ..['stats'] = [
      {'stat': 'hp', 'base': 45, 'effort': 0},
      {'stat': 'attack', 'base': 49, 'effort': 0},
      {'stat': 'defense', 'base': 49, 'effort': 0},
      {'stat': 'special-attack', 'base': 65, 'effort': 1},
      {'stat': 'special-defense', 'base': 65, 'effort': 0},
      {'stat': 'speed', 'base': 45, 'effort': 0},
    ];
  // O Venusaur como Water/Ground: fecha o buraco de Fire de dois Bulbasaur
  // e leva 4× de Grass (#374).
  final forms = [
    for (final f in json['forms'] as List)
      Map<String, dynamic>.of(f as Map<String, dynamic>),
  ];
  // Mais cinco Water/Ground no Scarlet/Violet (o "mais 2" das formas
  // sugeridas).
  for (final f in forms) {
    if (_waterGround.contains(f['id'])) f['types'] = ['water', 'ground'];
  }
  return Catalog.fromJson({
    ...json,
    'forms': forms,
    'pokemon': pokemon,
    // O Legends: Z-A, sem habilidade, Tera nem exportação.
    'versionGroups': [
      ...json['versionGroups'] as List,
      {
        'name': 'legends-za',
        'generation': 'generation-ix',
        'order': 30,
        'versions': ['legends-za'],
        'originMark': null,
      },
    ],
    'versions': [
      ...json['versions'] as List,
      {
        'name': 'legends-za',
        'versionGroup': 'legends-za',
        'receivesFromHome': false,
      },
    ],
    'movesFile': 'moves-2026.10.03.json',
    'heldItems': {
      'items': [
        {
          'name': 'focus-sash',
          'label': 'Focus Sash',
          'sprite': 'items/focus-sash.png',
        },
        {'name': 'leftovers', 'label': 'Leftovers', 'sprite': null},
      ],
      'versionGroups': {
        'scarlet-violet': [0, 1],
        'x-y': [1],
        'legends-za': [0],
      },
    },
  }, spriteBase: 'https://sprites/');
}

/// O Venusaur e as formas que viram Water/Ground no team builder.
const _waterGround = {2, 3, 133, 134, 172, 196};

FakeBackend teamBackend([Catalog? catalog]) =>
    FakeBackend.fromCatalog(catalog ?? teamCatalog());

/// Os golpes de teste, com o Bulbasaur (Tackle por nível e Seed Bomb por
/// TM) e o Venusaur (Vine Whip por TM) no Legends: Z-A, e as formas
/// Water/Ground com o Vine Whip no Scarlet/Violet.
MovesData teamMoves() {
  final json = movesJson();
  final learnsets = Map<String, dynamic>.of(
    json['learnsets'] as Map<String, dynamic>,
  );
  learnsets['1'] = {
    ...learnsets['1'] as Map<String, dynamic>,
    '3': [3, 0, 1, 2, 1, 0],
  };
  learnsets['3'] = {
    ...learnsets['3'] as Map<String, dynamic>,
    '3': [4, 1, 0],
  };
  for (final id in _waterGround.difference({3})) {
    learnsets['$id'] = {
      '1': [4, 1, 0],
    };
  }
  return MovesData.fromJson({
    ...json,
    'versionGroups': [...json['versionGroups'] as List, 'legends-za'],
    'learnsets': learnsets,
  });
}
