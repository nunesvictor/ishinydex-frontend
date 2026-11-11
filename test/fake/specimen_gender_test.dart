import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';

import '../fixtures/catalog_fixture.dart';

/// O catálogo com a Oinkologne: a PokéAPI dá à espécie `genderRate` 0 (só
/// macho), e a forma fêmea é outra (`oinkologne-female`).
Catalog _catalog() {
  final json = catalogJson();
  Map<String, dynamic> form(int id, String name, {required bool main}) => {
    ...(json['forms'] as List).first as Map<String, dynamic>,
    'id': id,
    'name': name,
    'formName': main ? '' : 'female',
    'pokemon': id,
    'isDefault': main,
  };
  Map<String, dynamic> pokemon(int id, {required bool main}) => {
    ...(json['pokemon'] as List).first as Map<String, dynamic>,
    'id': id,
    'name': main ? 'oinkologne-male' : 'oinkologne-female',
    'species': 'oinkologne',
    'isDefault': main,
  };
  return Catalog.fromJson({
    ...json,
    'forms': [
      ...json['forms'] as List,
      form(916, 'oinkologne-male', main: true),
      form(10254, 'oinkologne-female', main: false),
    ],
    'pokemon': [
      ...json['pokemon'] as List,
      pokemon(916, main: true),
      pokemon(10254, main: false),
    ],
    'species': [
      ...json['species'] as List,
      {
        ...(json['species'] as List).first as Map<String, dynamic>,
        'name': 'oinkologne',
        'nationalNumber': 916,
        'genderRate': 0,
        'evolvesFrom': null,
      },
    ],
  }, spriteBase: Env.defaultSpritesBaseUrl);
}

Matcher _impossible = throwsA(
  isA<ValidationFailure>().having((f) => f.fieldErrors['gender'], 'gender', [
    const Problem.impossibleGender(1),
  ]),
);

void main() {
  final catalog = _catalog();

  test('formas de um gênero só: o gênero da forma, não o da espécie', () {
    expect(catalog.genderRate(10254), 8);
    expect(catalog.formDetail(10254).genderRate, 8);
    expect(catalog.genderRate(916), 0);
    expect(catalog.genderRate(1), 1);
    expect(catalog.genderRate(150), -1);
  });

  test('criar e editar recusam um gênero impossível (#390)', () async {
    final backend = FakeBackend.fromCatalog(catalog);
    await expectLater(
      backend.create(const SpecimenDraft(form: 10254, gender: 'male')),
      _impossible,
    );
    await expectLater(
      backend.create(const SpecimenDraft(form: 150, gender: 'female')),
      _impossible,
    );
    final sow = await backend.create(
      const SpecimenDraft(form: 10254, gender: 'female'),
    );
    expect(sow.gender, 'female');
    await expectLater(
      backend.update(sow.id, const SpecimenDraft(form: 10254, gender: 'male')),
      _impossible,
    );
    // Sem gênero, ou vazio, continua valendo.
    expect(
      (await backend.update(sow.id, const SpecimenDraft(form: 10254))).gender,
      isNull,
    );
    expect(
      (await backend.create(const SpecimenDraft(form: 1, gender: ''))).gender,
      '',
    );
  });
}
