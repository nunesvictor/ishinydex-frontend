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
    expect(catalog.versions.last.name, 'violet');
    expect(catalog.transferVersions, {'scarlet', 'violet'});
    expect(catalog.originMarkOf('scarlet'), 'paldea');
    expect(catalog.originMarkOf('emerald'), isNull);
    expect(catalog.originMarkOf(null), isNull);
  });
}
