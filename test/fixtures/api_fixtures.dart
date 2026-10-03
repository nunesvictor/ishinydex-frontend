// Respostas reais da API do ishinydex-backend (capturadas em 2026-09-28).

const formRefJson = <String, dynamic>{
  'id': 1218,
  'name': 'rattata-alola',
  'form_name': 'alola',
  'pokeapi_id': 10193,
  'sprite_url':
      'http://localhost:8008/media/sprites/pokemon/other/home/10091.png',
  'shiny_sprite_url':
      'http://localhost:8008/media/sprites/pokemon/other/home/shiny/10091.png',
};

const dexJson = <String, dynamic>{
  'id': 1,
  'name': 'Shiny Living Dex',
  'is_shiny_dex': true,
  'force_new_box': true,
  'total': 1227,
  'registered': 1158,
};

const dexPageJson = <String, dynamic>{
  'count': 1,
  'next': null,
  'previous': null,
  'results': [dexJson],
};

const boxesJson = <dynamic>[
  {'id': 1, 'name': 'HOME 1', 'position': 1, 'total': 30, 'registered': 28},
  {'id': 2, 'name': 'HOME 2', 'position': 2, 'total': 30, 'registered': 30},
];

const registeredSlotJson = <String, dynamic>{
  'id': 1,
  'box': {'id': 1, 'name': 'HOME 1', 'position': 1},
  'row': 0,
  'col': 0,
  'personal_dex': 1,
  'form': {
    'id': 1,
    'name': 'bulbasaur',
    'form_name': '',
    'pokeapi_id': 1,
    'sprite_url':
        'http://localhost:8008/media/sprites/pokemon/other/home/1.png',
    'shiny_sprite_url':
        'http://localhost:8008/media/sprites/pokemon/other/home/shiny/1.png',
  },
  'specimen': {
    'id': 1,
    'nickname': null,
    'form_name': 'bulbasaur',
    'is_shiny': true,
    'is_alpha': false,
    'pokeball': null,
    'pokeball_sprite_url': null,
  },
  'is_shiny_display': true,
};

const missingSlotJson = <String, dynamic>{
  'id': 20,
  'box': {'id': 1, 'name': 'HOME 1', 'position': 1},
  'row': 3,
  'col': 1,
  'personal_dex': 1,
  'form': formRefJson,
  'specimen': null,
  'is_shiny_display': true,
};

const specimenJson = <String, dynamic>{
  'id': 1,
  'form_ref': {
    'id': 1,
    'name': 'bulbasaur',
    'form_name': '',
    'pokeapi_id': 1,
    'sprite_url':
        'http://localhost:8008/media/sprites/pokemon/other/home/1.png',
    'shiny_sprite_url':
        'http://localhost:8008/media/sprites/pokemon/other/home/shiny/1.png',
  },
  'pokeball_sprite_url': null,
  'slot': 1,
  'form_name': 'bulbasaur',
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
  'observation': '',
  'created_at': '2026-08-05T12:20:09.432083-03:00',
  'updated_at': '2026-08-05T12:24:58.437319-03:00',
  'form': 1,
  'ot': 7,
  'origin_version': 'scarlet',
  'origin_mark': 'paldea',
};

const specimenPageJson = <String, dynamic>{
  'count': 1,
  'next': null,
  'previous': null,
  'results': [specimenJson],
};

const formDetailJson = <String, dynamic>{
  'id': 1,
  'name': 'bulbasaur',
  'form_name': '',
  'pokeapi_id': 1,
  'sprite_url': 'http://localhost:8008/media/sprites/pokemon/other/home/1.png',
  'shiny_sprite_url':
      'http://localhost:8008/media/sprites/pokemon/other/home/shiny/1.png',
  'types': [
    {'slot': 1, 'type': 'grass'},
    {'slot': 2, 'type': 'poison'},
  ],
  'abilities': [
    {'slot': 1, 'ability': 'overgrow', 'is_hidden': false},
    {'slot': 3, 'ability': 'chlorophyll', 'is_hidden': true},
  ],
  'is_shinylocked': false,
  'is_distro_only': false,
};

const optionsJson = <String, dynamic>{
  'language': [
    {'value': 'pt-br', 'label': 'Português brasileiro'},
  ],
  'gender': [
    {'value': 'male', 'label': 'Macho'},
  ],
  'nature': [
    {'value': 'adamant', 'label': 'Adamant'},
  ],
  'pokeball': [
    {
      'value': 'poke-ball',
      'label': 'Poké Ball',
      'sprite_url': 'http://localhost:8008/media/sprites/items/poke-ball.png',
    },
  ],
  'origin_mark': [
    {'value': 'paldea', 'label': 'SV'},
    {'value': 'go', 'label': 'GO'},
    {'value': 'none', 'label': 'Sem marca de origem'},
  ],
};

const trainerPageJson = <String, dynamic>{
  'count': 1,
  'next': null,
  'previous': null,
  'results': [
    {'id': 12, 'name': 'Ash', 'trainer_id': '123456', 'version': 'ultra-moon'},
  ],
};

/// `GET /shiny-locks/{id}/` (shape de `docs/plans/frontend-api.md` no
/// backend).
const shinyLockJson = <String, dynamic>{
  'id': 25,
  'caption': 'Treasures of Ruin',
  'description': null,
  'lock_type': 'distro-only',
  'active': true,
  'forms': [formRefJson],
};
