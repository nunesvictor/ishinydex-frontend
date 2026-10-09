import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';

import '../../fixtures/catalog_fixture.dart';

const _base = 'https://sprites.example/sprites';

void main() {
  final catalog = Catalog.fromJson(catalogJson(), spriteBase: '$_base/');

  test('formato mais novo que o do app é recusado', () {
    expect(
      () => Catalog.fromJson(catalogJson(schemaVersion: 2), spriteBase: _base),
      throwsA(isA<FormatException>()),
    );
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

    expect(
      catalog.versions.first,
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
          game.entries.map((e) => e.description).join(', '),
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
