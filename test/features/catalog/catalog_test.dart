import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/utils/origin_mark.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_labels.dart';

import '../../fixtures/catalog_fixture.dart';

const _base = 'https://sprites.example/sprites';

/// Os textos em pt-BR, sem montar uma tela.
final AppLocalizations _pt = lookupAppLocalizations(const Locale('pt'));

void main() {
  final catalog = Catalog.fromJson(catalogJson(), spriteBase: '$_base/');

  test('formato mais novo que o do app é recusado', () {
    expect(
      () => Catalog.fromJson(catalogJson(schemaVersion: 2), spriteBase: _base),
      throwsA(
        isA<DataFailure>().having(
          (f) => f.problem,
          'problem',
          const Problem.catalogTooNew(schema: 2, supported: 1),
        ),
      ),
    );
  });

  test('rótulos em cada idioma; catálogo antigo, sem labels', () {
    const grass = {'en': 'Grass', 'pt-BR': 'Planta'};
    const galar = {'en': 'Galar', 'pt-BR': 'Galar'};
    const random = {'en': 'Random encounter', 'pt-BR': 'Encontro aleatório'};
    // Cópia sem os tipos fixos dos literais, para acrescentar os labels.
    final json = jsonDecode(jsonEncode(catalogJson())) as Map<String, dynamic>;
    final choices = json['choices'] as Map<String, dynamic>;
    ((choices['type'] as List).first as Map<String, dynamic>)['labels'] = grass;
    (json['pokedexes'] as List).cast<Map<String, dynamic>>().firstWhere(
      (d) => d['name'] == 'galar',
    )['labels'] = galar;
    json['shinyMethods'] = [
      {
        'id': 'random',
        'label': 'Encontro aleatório',
        'labels': random,
        'units': ['encounters'],
        'versions': ['sword'],
      },
    ];
    final labeled = Catalog.fromJson(json, spriteBase: _base);

    expect(labeled.options.type.first.labels, grass);
    expect(labeled.options.type.last.labels, isEmpty);
    expect(labeled.pokedexesOf(133).first.entries.single.labels, galar);
    expect(labeled.shinyMethods.single.labels, random);
    // Catálogo antigo: só o label em pt-BR.
    expect(catalog.options.type.first.labels, isEmpty);
    expect(catalog.pokedexesOf(133).first.entries.single.labels, isEmpty);
  });

  test('versão, dex padrão, ids e shiny locks', () {
    expect(catalog.version, 'catalog-2026.10.03');
    expect(catalog.defaultDex.first, 1);
    expect(catalog.hasForm(10033), true);
    expect(catalog.hasForm(999), false);
    expect(catalog.formIds, contains(793));
    final lock = catalog.shinyLocks.single;
    expect(lock.caption, 'Mewtwo de evento');
    expect(lock.lockType, ShinyLockType.distroOnly);
    expect(lock.forms, [150]);
    expect((lock.active, lock.description), (true, ''));
  });

  test('FormRef com nº nacional e sprites resolvidos', () {
    expect(
      catalog.formRef(10033),
      const FormRef(
        id: 10033,
        name: 'venusaur-mega',
        formName: 'mega',
        pokeapiId: 10033,
        nationalNumber: 3,
        spriteUrl: '$_base/pokemon/other/home/10033.png',
        shinySpriteUrl: '$_base/pokemon/other/home/shiny/10033.png',
      ),
    );
    expect(catalog.itemSprite('poke-ball'), '$_base/items/poke-ball.png');
  });

  test('FormDetail como a API: tipos, espécie, estreia e outras formas', () {
    final detail = catalog.formDetail(1);
    expect(detail.types, [
      const FormType(
        slot: 1,
        type: 'grass',
        spriteUrl: '$_base/types/generation-viii/sword-shield/small/12.png',
      ),
      const FormType(slot: 2, type: 'poison'),
    ]);
    expect(detail.abilities.single.ability, 'overgrow');
    expect(detail.stats.map((s) => s.stat), ['hp', 'special-attack']);
    expect(
      (detail.genderRate, detail.captureRate, detail.hatchCounter),
      (1, 45, 20),
    );
    expect((detail.height, detail.weight), (7, 69));
    expect(detail.debutVersions, ['red', 'blue']);
    expect(detail.otherForms, isEmpty);
    expect(detail.isShinylocked || detail.isDistroOnly, false);
    expect(catalog.formDetail(3).otherForms.single.name, 'venusaur-mega');
  });

  group('métodos de evolução (#368)', () {
    final json = {
      ...catalogJson(),
      'evolutionMethods': {
        'edges': [
          {
            'from': 1,
            'to': 2,
            'methods': [
              {
                'versionGroup': 'red-blue',
                'default': true,
                'trigger': 'level-up',
                'minLevel': 16,
              },
            ],
          },
          // O Ivysaur → Venusaur Mega: a linha liga ao Venusaur comum, pelo
          // par de espécies.
          {
            'from': 2,
            'to': 10033,
            'methods': [
              {'versionGroup': 'x-y', 'default': true, 'trigger': 'trade'},
            ],
          },
          {
            'from': 133,
            'to': 134,
            'methods': [
              {
                'versionGroup': 'red-blue',
                'default': true,
                'trigger': 'use-item',
                'item': 'water-stone',
              },
              {
                'versionGroup': 'sword-shield',
                'default': false,
                'trigger': 'level-up',
                'heldItem': 'mystic-water',
                'knownMove': 'water-gun',
                'knownMoveType': 'water',
                'usedMove': 'surf',
                'minMoveCount': 20,
                'location': 'lake',
                'nearSpecialRock': true,
                'timeOfDay': 'night',
                'minHappiness': 160,
                'minAffection': 2,
                'minBeauty': 170,
                'gender': 'female',
                'region': 'galar',
                'relativePhysicalStats': 0,
                'allowedNatures': ['hardy'],
                'needsOverworldRain': true,
                'needsMultiplayer': true,
                'turnUpsideDown': true,
                'tradeSpecies': 'shelmet',
                'partySpecies': 'remoraid',
                'partyType': 'dark',
                'minSteps': 1000,
                'minDamageTaken': 49,
                'chance': 50,
              },
            ],
            'texts': {'en': 'Splash', 'pt-BR': 'Molhar'},
            'link': 'https://bulbapedia.bulbagarden.net/wiki/Vaporeon',
          },
          // De uma forma que não está no catálogo: ignorada.
          {'from': 99999, 'to': 2, 'methods': <Object>[]},
        ],
        'names': {
          'items': {'water-stone': 'Water Stone'},
          'moves': {'water-gun': 'Water Gun'},
          'locations': <String, String>{},
        },
      },
    };
    final withMethods = Catalog.fromJson(json, spriteBase: '$_base/');

    test('as ligações da linha, com os métodos de cada uma', () {
      final bulba = withMethods.formDetail(1).evolutionEdges;
      expect(bulba, [
        const EvolutionEdge(
          fromId: 1,
          toId: 2,
          methods: [
            EvolutionMethod(
              versionGroup: 'red-blue',
              versions: ['red', 'blue'],
              trigger: 'level-up',
              isDefault: true,
              minLevel: 16,
            ),
          ],
        ),
        // Pelo par de espécies, com as formas da linha.
        const EvolutionEdge(
          fromId: 2,
          toId: 3,
          methods: [
            EvolutionMethod(
              versionGroup: 'x-y',
              versions: ['x', 'y'],
              trigger: 'trade',
              isDefault: true,
            ),
          ],
        ),
      ]);
      // A mesma linha em qualquer forma dela.
      expect(withMethods.formDetail(3).evolutionEdges, bulba);
    });

    test('nomes em inglês, sprite do item, frase e link', () {
      final edges = withMethods.formDetail(133).evolutionEdges;
      final vapor = edges.first;
      expect((vapor.fromId, vapor.toId), (133, 134));
      expect(vapor.texts, {'en': 'Splash', 'pt-BR': 'Molhar'});
      expect(vapor.link, 'https://bulbapedia.bulbagarden.net/wiki/Vaporeon');
      final (stone, other) = (vapor.methods.first, vapor.methods.last);
      expect(stone.item, 'Water Stone');
      expect(stone.itemSpriteUrl, '$_base/items/water-stone.png');
      expect(
        other,
        const EvolutionMethod(
          versionGroup: 'sword-shield',
          versions: ['sword', 'shield'],
          trigger: 'level-up',
          // Sem nome no catálogo: pelo slug.
          heldItem: 'Mystic Water',
          knownMove: 'Water Gun',
          knownMoveType: 'water',
          usedMove: 'Surf',
          minMoveCount: 20,
          location: 'Lake',
          nearSpecialRock: true,
          timeOfDay: 'night',
          minHappiness: 160,
          minAffection: 2,
          minBeauty: 170,
          gender: 'female',
          region: 'galar',
          relativePhysicalStats: 0,
          allowedNatures: ['hardy'],
          needsOverworldRain: true,
          needsMultiplayer: true,
          turnUpsideDown: true,
          tradeSpecies: 'Shelmet',
          partySpecies: 'Remoraid',
          partyType: 'dark',
          minSteps: 1000,
          minDamageTaken: 49,
          chance: 50,
        ),
      );
      // O Espeon, sem métodos no catálogo: a ligação sem eles.
      expect(edges.last, const EvolutionEdge(fromId: 133, toId: 196));
    });

    test('catálogo antigo: as ligações, sem métodos', () {
      expect(catalog.formDetail(1).evolutionEdges, const [
        EvolutionEdge(fromId: 1, toId: 2),
        EvolutionEdge(fromId: 2, toId: 3),
      ]);
      expect(catalog.formDetail(150).evolutionEdges, isEmpty);
    });

    test('a ligação curada sem a espécie de origem: da forma anterior', () {
      // O Vaporeon de Galar → Espeon (só para o teste): o Espeon vem do
      // Eevee, que não está na linha.
      final regional = Catalog.fromJson({
        ...json,
        'formEvolutions': {
          'evolutions': [
            [10600, 196],
          ],
          'withoutEvolution': <int>[],
        },
      }, spriteBase: '$_base/');
      expect(regional.formDetail(196).evolutionEdges, const [
        EvolutionEdge(fromId: 10600, toId: 196),
      ]);
    });
  });

  test('golpes (#36): o arquivo, os grupos e os Pokémon da forma', () {
    expect(catalog.movesFile, isNull);
    final withMoves = Catalog.fromJson({
      ...catalogJson(),
      'movesFile': 'moves-2026.10.03.json',
    }, spriteBase: _base);
    expect(withMoves.movesFile, 'moves-2026.10.03.json');
    expect(catalog.versionsOfGroup('x-y'), ['x', 'y']);
    expect(catalog.versionsOfGroup('nope'), isEmpty);
    expect(catalog.versionGroupOrder('x-y'), 15);
    expect(catalog.versionGroupOrder('nope'), 0);
    expect(catalog.versionGroupGeneration('scarlet-violet'), 'generation-ix');
    expect(catalog.versionGroupOf('violet'), 'scarlet-violet');
    // A forma e, sem golpes próprios, a padrão da espécie.
    expect(catalog.movesPokemonIds(10033), [10033, 3]);
    expect(catalog.movesPokemonIds(3), [3]);
    expect(catalog.movesPokemonIds(999), isEmpty);
  });

  test('formas regionais: a linha pelas evoluções curadas (#252)', () {
    // Como o Meowth de Galar (que só vira Perrserker) e o Farfetch'd comum
    // (que não vira Sirfetch'd): no catálogo de teste, o Eevee só vira
    // Espeon, e o Vaporeon de Galar não evolui nem vem de outro.
    final regional = Catalog.fromJson({
      ...catalogJson(),
      'formEvolutions': {
        'evolutions': [
          [1, 2],
          [2, 3],
          [133, 196],
        ],
        'withoutEvolution': [10600],
      },
    }, spriteBase: '$_base/');
    List<List<String>> names(int id) => [
      for (final stage in regional.formDetail(id).evolutionChain)
        [for (final f in stage) f.name],
    ];
    // O caminho da forma: de onde ela vem e o que vem dela.
    expect(names(2), [
      ['bulbasaur'],
      ['ivysaur'],
      ['venusaur'],
    ]);
    expect(names(196), [
      ['eevee'],
      ['espeon'],
    ]);
    expect(names(133), [
      ['eevee'],
      ['espeon'],
    ]);
    expect(names(10600), isEmpty);
    // Fora das arestas: pela espécie, como antes.
    expect(names(134), [
      ['eevee'],
      ['vaporeon', 'espeon'],
    ]);
    // A regra do "evoluiu fora do HOME" também.
    expect(regional.evolvesFromForm(196), 133);
    expect(regional.evolvesFromForm(10600), isNull);
    expect(regional.evolvesFromForm(1), isNull);
    expect(regional.evolvesFromForm(134), 133);
  });

  test('linha evolutiva em estágios, com ramificação e sem a Mega', () {
    List<List<String>> names(int id) => [
      for (final stage in catalog.formDetail(id).evolutionChain)
        [for (final f in stage) f.name],
    ];
    expect(names(10033), [
      ['bulbasaur'],
      ['ivysaur'],
      ['venusaur'],
    ]);
    expect(names(196), [
      ['eevee'],
      ['vaporeon', 'espeon'],
    ]);
    expect(names(150), isEmpty);
    expect(catalog.evolvesFromForm(3), 2);
    expect(catalog.evolvesFromForm(1), isNull);
  });

  test('categoria, gênero e geração', () {
    expect(catalog.category(150), SpeciesCategory.legendary);
    expect(catalog.category(793), SpeciesCategory.ultraBeast);
    expect(catalog.category(172), SpeciesCategory.baby);
    expect(catalog.category(1), SpeciesCategory.regular);
    expect(catalog.genderRate(793), -1);
    expect(catalog.generation(172), 'generation-ii');
  });

  test('opções e versões em ordem de lançamento, com saves e marcas', () {
    final options = catalog.options;
    expect(options.pokeball.single.spriteUrl, '$_base/items/poke-ball.png');
    expect(options.nature.first.increased, 'special-attack');
    expect(options.nature.last.increased, isNull);
    expect(options.type.last.spriteUrl, isNull);
    expect(options.originMark.last.value, 'none');
    expect(options.language.single.value, 'pt-br');
    expect(options.gender, hasLength(3));
    expect(options.generation.single.label, 'Geração I');

    // O GO (#360), sem grupo de versão, vem antes de tudo.
    expect(
      catalog.versions.first,
      const GameVersion(
        name: goVersion,
        versionGroup: goVersion,
        generation: '',
      ),
    );
    expect(
      catalog.versions[1],
      const GameVersion(
        name: 'red',
        versionGroup: 'red-blue',
        generation: 'generation-i',
      ),
    );
    expect(catalog.versions.last.name, 'the-teal-mask-scarlet');
    expect(catalog.transferVersions, {
      'scarlet',
      'violet',
      'sword',
      'shield',
      'brilliant-diamond',
      'shining-pearl',
    });
    expect(catalog.originMarkOf('scarlet'), 'paldea');
    expect(catalog.originMarkOf('emerald'), isNull);
    expect(catalog.originMarkOf(null), isNull);
  });

  group('jogos do HOME', () {
    String games(int formId) => [
      for (final game in catalog.pokedexesOf(formId))
        [
          game.versions.join('/'),
          game.entries.map((e) => _pt.pokedexEntry(e, e.label)).join(', '),
        ].join(': '),
    ].join(' | ');

    test('pokédex de cada jogo, em ordem de lançamento', () {
      expect(catalog.hasPokedexes, isTrue);
      expect(
        games(133),
        'sword/shield: Galar nº 5 | scarlet/violet: Paldea nº 1',
      );
      // Pokédex especial (sem número) e de DLC.
      expect(games(150), 'sword/shield: Aventura Dinamax (DLC)');
      expect(
        games(172),
        'brilliant-diamond/shining-pearl: Nacional nº 172 | '
        'scarlet/violet: Kitakami nº 10 (DLC)',
      );
      expect(games(793), isEmpty);
      // O detalhe da forma traz as mesmas.
      expect(
        catalog.formDetail(196).pokedexes.single.versionGroup,
        'scarlet-violet',
      );
      // Exclusivo de versão: a versão em que a forma aparece (#202).
      expect(catalog.formDetail(196).pokedexes.single.exclusiveTo, ['scarlet']);
      expect(catalog.pokedexesOf(133).first.exclusiveTo, isEmpty);
      // O shiny lock por jogo (#313): o Eevee só em Scarlet.
      final eevee = {
        for (final g in catalog.pokedexesOf(133)) g.versionGroup: g,
      };
      expect(eevee['scarlet-violet']!.shinyLockedIn, ['scarlet']);
      expect(eevee['sword-shield']!.shinyLockedIn, isEmpty);
    });

    test('versões na ordem da série, com o par na ordem do grupo', () {
      final names = [for (final v in catalog.versions) v.name];
      expect(names.indexOf('sun'), lessThan(names.indexOf('moon')));
      expect(names.indexOf('sword'), lessThan(names.indexOf('shield')));
      expect(names.indexOf('moon'), lessThan(names.indexOf('sword')));
      expect(
        ['violet', 'shield', 'nenhum', 'sword', 'sun']
          ..sort(catalog.compareVersions),
        ['sun', 'sword', 'shield', 'violet', 'nenhum'],
      );
    });

    test('forma lançada depois do jogo fica de fora; a de DLC, não', () {
      // Pichu da DLC de Scarlet/Violet: não no BDSP (anterior), sim em SV.
      expect(games(10500), 'scarlet/violet: Kitakami nº 10 (DLC)');
    });

    test('caçável: na pokédex e sem ser exclusiva da outra versão', () {
      expect(catalog.huntableVersions(133), [
        'sword',
        'shield',
        'scarlet',
        'violet',
      ]);
      expect(catalog.huntableVersions(196), ['scarlet']);
      expect(catalog.huntableVersions(134), ['sword', 'shield', 'violet']);
      expect(catalog.huntableVersions(150), ['sword']);
      expect(catalog.huntableVersions(1), [
        'brilliant-diamond',
        'shining-pearl',
      ]);
      expect(catalog.huntableVersions(793), isEmpty);
      // Num jogo só (o save da caçada).
      expect(catalog.huntableIn(196, 'scarlet'), isTrue);
      expect(catalog.huntableIn(196, 'violet'), isFalse);
      expect(catalog.huntableIn(133, 'shield'), isTrue);
      expect(catalog.huntableIn(793, 'sword'), isFalse);
      expect(catalog.huntableIn(196, 'red'), isTrue);
    });

    test('OT: a forma, ou uma pré-evolução, na pokédex do jogo', () {
      // Espeon não está no BDSP, nem o Eevee.
      expect(catalog.originFits(196, 'brilliant-diamond'), isFalse);
      // Em Sword não está, mas o Eevee está: evoluiu depois.
      expect(catalog.originFits(196, 'sword'), isTrue);
      expect(catalog.originFits(134, 'sword'), isTrue);
      // Exclusivos não contam (Vaporeon de Scarlet: evento).
      expect(catalog.originFits(134, 'scarlet'), isTrue);
      // Jogos sem pokédex no catálogo, ou sem OT: sem aviso.
      expect(catalog.originFits(196, 'red'), isTrue);
      expect(catalog.originFits(196, null), isTrue);
    });

    test('forma regional: só nos jogos em que aparece', () {
      List<String> groups(int id) => [
        for (final game in catalog.pokedexesOf(id)) game.versionGroup,
      ];
      // A espécie está em Paldea, mas a forma de Galar não aparece lá.
      expect(groups(134), ['sword-shield', 'scarlet-violet']);
      expect(groups(10600), ['sword-shield']);
    });

    test('shiny lock por versão', () {
      expect(catalog.lockedVersions(133), {'scarlet'});
      expect(catalog.lockedVersions(1), isEmpty);
    });

    test('save: a própria forma na pokédex do jogo', () {
      expect(catalog.inGame(133, 'sword'), isTrue);
      // Espeon evolui em Sword, mas não está na pokédex dele.
      expect(catalog.inGame(196, 'sword'), isFalse);
      expect(catalog.inGame(196, 'red'), isTrue);
    });

    test('FRLG (só ida): caçável e com marca GBA, mas não é save', () {
      final json = catalogJson();
      (json['versionGroups'] as List).add({
        'name': 'firered-leafgreen',
        'generation': 'generation-iii',
        'order': 7,
        'versions': ['firered', 'leafgreen'],
        'originMark': 'gba',
      });
      for (final v in ['firered', 'leafgreen']) {
        (json['versions'] as List).add({
          'name': v,
          'versionGroup': 'firered-leafgreen',
          'receivesFromHome': false,
        });
      }
      (json['pokedexes'] as List).add({
        'name': 'kanto',
        'label': 'Kanto',
        'versionGroups': ['firered-leafgreen'],
        'dlc': null,
        'entries': [
          ['bulbasaur', 1],
        ],
      });
      final frlg = Catalog.fromJson(json, spriteBase: _base);

      expect(frlg.transferVersions, isNot(contains('firered')));
      expect(frlg.huntableVersions(1), [
        'firered',
        'leafgreen',
        'brilliant-diamond',
        'shining-pearl',
      ]);
      expect(frlg.pokedexesOf(1).first.versions, ['firered', 'leafgreen']);
      expect(frlg.inGame(1, 'firered'), isTrue);
      expect(frlg.inGame(133, 'firered'), isFalse);
    });

    test('USUM (só ida pelo Bank): caçável e com marca de Alola', () {
      final json = catalogJson();
      (json['versionGroups'] as List).add({
        'name': 'ultra-sun-ultra-moon',
        'generation': 'generation-vii',
        'order': 18,
        'versions': ['ultra-sun', 'ultra-moon'],
        'originMark': 'alola',
      });
      for (final v in ['ultra-sun', 'ultra-moon']) {
        (json['versions'] as List).add({
          'name': v,
          'versionGroup': 'ultra-sun-ultra-moon',
          'receivesFromHome': false,
        });
      }
      (json['pokedexes'] as List).add({
        'name': 'updated-alola',
        'label': 'Alola (USUM)',
        'versionGroups': ['ultra-sun-ultra-moon'],
        'dlc': null,
        'entries': [
          ['eevee', 150],
        ],
      });
      final usum = Catalog.fromJson(json, spriteBase: _base);

      expect(usum.transferVersions, isNot(contains('ultra-sun')));
      expect(usum.huntableVersions(133), contains('ultra-moon'));
      expect(usum.inGame(133, 'ultra-sun'), isTrue);
      expect(usum.inGame(1, 'ultra-sun'), isFalse);
      expect(OriginMark.fromVersion('ultra-sun'), OriginMark.alola);
    });

    test('catálogo antigo: sem pokédex nem exclusivos', () {
      final old = Catalog.fromJson(
        catalogJson()
          ..remove('pokedexes')
          ..remove('versionExclusives')
          ..remove('gameForms')
          ..remove('gameShinyLocks'),
        spriteBase: _base,
      );
      expect(old.hasPokedexes, isFalse);
      expect(old.pokedexesOf(133), isEmpty);
      expect(old.huntableVersions(133), isEmpty);
      expect(old.formDetail(133).pokedexes, isEmpty);
      expect(old.originFits(196, 'brilliant-diamond'), isTrue);
      expect(old.lockedVersions(133), isEmpty);
    });
  });
}
