// O arquivo de vitrine dos prints do README (ishinydex#251): dados
// inventados, montados pelas regras do próprio app sobre o catálogo real.
// Não roda na suíte (fica fora de test/); o tool/screens/capture.sh do
// repositório principal chama:
//
//   CATALOG=<catalog.json> OUT=<arquivo> flutter test tool/showcase
//
// A base é a da demonstração (o treinador Ash, o shiny dex e o Living Dex
// com espécimes); por cima, caçadas em andamento e os times dos mocks da
// v2.20.0. Nada vem da coleção de alguém.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/local/data/local_data_storage.dart';
import 'package:ishinydex/features/local/data/local_store.dart';
import 'package:ishinydex/features/shiny_hunts/domain/models.dart';
import 'package:ishinydex/features/teams/domain/models.dart';

void main() {
  test('arquivo de vitrine', () async {
    final env = Platform.environment;
    final catalog = Catalog.fromJson(
      jsonDecode(File(env['CATALOG']!).readAsStringSync())
          as Map<String, dynamic>,
      spriteBase:
          'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites',
    );
    final backend = FakeBackend.fromCatalog(catalog);
    int form(String name) =>
        catalog.formIds.firstWhere((id) => catalog.formRef(id).name == name);

    // Caçadas em andamento: as de diferença sutil e grande da #381.
    final sword = await backend.createTrainer(
      name: 'Ash',
      trainerId: '333333',
      version: 'sword',
    );
    final swordSave = await backend.createSave(trainerId: sword.id);
    final pearl = await backend.createTrainer(
      name: 'Dawn',
      trainerId: '444444',
      version: 'brilliant-diamond',
    );
    final pearlSave = await backend.createSave(trainerId: pearl.id);
    await backend.saveShinyHunt(
      ShinyHunt(
        id: 0,
        form: form('zapdos'),
        save: swordSave.id,
        method: 'dynamax-adventures',
        unit: 'runs',
        count: 37,
        startedAt: DateTime(2026, 10, 28),
      ),
    );
    await backend.saveShinyHunt(
      ShinyHunt(
        id: 0,
        form: form('phione'),
        save: pearlSave.id,
        method: 'masuda',
        unit: 'eggs',
        count: 1284,
        startedAt: DateTime(2026, 10, 12),
      ),
    );

    // Os times dos mocks da v2.20.0 (#231 e o Z-A).
    TeamMember member(
      String name, {
      required List<String> moves,
      String? ability,
      String? item,
      String? nature,
      String? tera,
      Map<String, int> evs = const {},
      Map<String, int> ivs = const {},
    }) => TeamMember(
      form: form(name),
      ability: ability,
      item: item,
      nature: nature,
      tera: tera,
      moves: moves,
      evs: evs,
      ivs: ivs,
    );
    const special = {'hp': 4, 'special-attack': 252, 'speed': 252};
    const physical = {'hp': 4, 'attack': 252, 'speed': 252};
    await backend.saveTeam(
      Team(
        id: 0,
        name: 'Regulation G',
        versionGroup: 'scarlet-violet',
        members: [
          member(
            'calyrex-shadow',
            ability: 'as-one-spectrier',
            item: 'focus-sash',
            nature: 'timid',
            tera: 'fairy',
            evs: special,
            ivs: {'attack': 0},
            moves: ['astral-barrage', 'psyshock', 'nasty-plot', 'protect'],
          ),
          member(
            'ogerpon-cornerstone-mask',
            ability: 'sturdy',
            item: 'cornerstone-mask',
            nature: 'jolly',
            tera: 'rock',
            evs: {'attack': 252, 'special-defense': 4, 'speed': 252},
            moves: ['ivy-cudgel', 'horn-leech', 'follow-me', 'spiky-shield'],
          ),
          member(
            'urshifu-rapid-strike',
            ability: 'unseen-fist',
            item: 'assault-vest',
            nature: 'jolly',
            tera: 'water',
            evs: physical,
            moves: ['surging-strikes', 'close-combat', 'aqua-jet', 'u-turn'],
          ),
          member(
            'incineroar',
            ability: 'intimidate',
            item: 'sitrus-berry',
            nature: 'careful',
            tera: 'ghost',
            evs: {'hp': 252, 'defense': 4, 'special-defense': 252},
            moves: ['fake-out', 'flare-blitz', 'knock-off', 'parting-shot'],
          ),
          member(
            'amoonguss',
            ability: 'regenerator',
            item: 'leftovers',
            nature: 'relaxed',
            tera: 'water',
            evs: {'hp': 252, 'defense': 252, 'special-defense': 4},
            ivs: {'speed': 0},
            moves: ['spore', 'rage-powder', 'pollen-puff', 'protect'],
          ),
          member(
            'flutter-mane',
            ability: 'protosynthesis',
            item: 'booster-energy',
            nature: 'timid',
            tera: 'fairy',
            evs: special,
            moves: ['moonblast', 'shadow-ball', 'dazzling-gleam', 'protect'],
          ),
        ],
      ),
    );
    await backend.saveTeam(
      Team(
        id: 0,
        name: 'Lumiose Megas',
        versionGroup: 'legends-za',
        members: [
          member(
            'floette-eternal',
            item: 'floettite',
            nature: 'modest',
            evs: special,
            moves: ['light-of-ruin', 'moonblast', 'energy-ball', 'calm-mind'],
          ),
          member(
            'charizard',
            item: 'charizardite-y',
            nature: 'timid',
            evs: special,
            moves: ['fire-blast', 'air-slash', 'solar-beam', 'protect'],
          ),
          member(
            'starmie',
            item: 'starminite',
            nature: 'timid',
            evs: special,
            moves: ['hydro-pump', 'psychic', 'ice-beam', 'recover'],
          ),
          member(
            'dragonite',
            item: 'dragoninite',
            nature: 'adamant',
            evs: physical,
            moves: ['extreme-speed', 'dragon-claw', 'earthquake', 'fire-punch'],
          ),
          member(
            'garchomp',
            item: 'garchompite',
            nature: 'jolly',
            evs: physical,
            moves: ['earthquake', 'dragon-claw', 'stone-edge', 'swords-dance'],
          ),
          member(
            'lucario',
            item: 'lucarionite',
            nature: 'timid',
            evs: special,
            moves: ['aura-sphere', 'flash-cannon', 'dark-pulse', 'nasty-plot'],
          ),
        ],
      ),
    );

    // O arquivo de dados, como o "Exportar" do app, com a data fixa.
    final store = LocalStore(
      InMemoryLocalDataStorage(),
      now: () => DateTime.utc(2026, 11, 1, 12),
    );
    File(env['OUT']!).writeAsStringSync(
      jsonEncode(store.file(backend.records, catalog: catalog.version)),
    );
  });
}
