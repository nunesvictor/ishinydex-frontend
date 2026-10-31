import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/moves/domain/moves_data.dart';

import '../../fixtures/catalog_fixture.dart';
import '../../fixtures/moves_fixture.dart';

/// O catálogo de teste com o que o team builder usa (#231): os stats e as
/// duas habilidades do Bulbasaur (a 2ª oculta), os itens seguráveis do
/// Scarlet/Violet (o Leftovers sem sprite) e do X/Y, e o arquivo dos golpes.
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
  return Catalog.fromJson({
    ...json,
    'pokemon': pokemon,
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
      },
    },
  }, spriteBase: 'https://sprites/');
}

FakeBackend teamBackend([Catalog? catalog]) =>
    FakeBackend.fromCatalog(catalog ?? teamCatalog());

MovesData teamMoves() => MovesData.fromJson(movesJson());
