import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/species_info.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

import '../../fixtures/api_fixtures.dart';
import '../../fixtures/catalog_fixture.dart';
import '../../helpers/helpers.dart';

// O que o jogo só aceita pelo HOME e só se caça por ovo (#314). Na fixture,
// o Bulbasaur faz o papel do Phione: fora das pokédex de Scarlet/Violet.

Map<String, dynamic> _method(String id, List<String> units) => {
  'id': id,
  'label': id,
  'labels': {'en': id, 'pt-BR': id},
  'units': units,
  'versions': ['scarlet', 'violet'],
};

Catalog _catalog({bool eggs = true}) => Catalog.fromJson({
  ...catalogJson(),
  'shinyMethods': [
    _method('random', ['encounters', 'hours']),
    _method('masuda', ['eggs', 'hours']),
  ],
  if (eggs)
    'homeEggs': [
      {
        'versionGroup': 'scarlet-violet',
        'forms': [1],
      },
    ],
}, spriteBase: Env.defaultSpritesBaseUrl);

void main() {
  test('o jogo entra na Pokédex dos jogos, sem entrada, e só por ovo', () {
    final catalog = _catalog();
    final sv = catalog
        .pokedexesOf(1)
        .where((g) => g.versionGroup == 'scarlet-violet')
        .single;
    expect(sv.viaHomeEgg, isTrue);
    expect(sv.entries, isEmpty);
    expect(sv.versions, ['scarlet', 'violet']);
    expect(catalog.inGame(1, 'scarlet'), isTrue);
    expect(catalog.huntableVersions(1), containsAll(['scarlet', 'violet']));
    expect(catalog.onlyByEgg(1, 'scarlet'), isTrue);
    expect(catalog.onlyByEgg(133, 'scarlet'), isFalse);
    // Só os métodos que contam ovos; para as outras formas, todos.
    expect(
      [for (final m in catalog.shinyMethodsFor('scarlet', formId: 1)) m.id],
      ['masuda'],
    );
    expect(catalog.shinyMethodsFor('scarlet', formId: 133), hasLength(2));
    expect(catalog.shinyMethodsFor('scarlet'), hasLength(2));
  });

  test('catálogo antigo, sem a chave: nada muda', () {
    final catalog = _catalog(eggs: false);
    expect(
      catalog.pokedexesOf(1).where((g) => g.versionGroup == 'scarlet-violet'),
      isEmpty,
    );
    expect(catalog.onlyByEgg(1, 'scarlet'), isFalse);
  });

  testWidgets('a Pokédex dos jogos explica: pelo HOME, por ovo', (
    tester,
  ) async {
    final form = FormDetail.fromJson(formDetailJson).copyWith(
      pokedexes: const [
        GamePokedex(
          versionGroup: 'scarlet-violet',
          versions: ['scarlet', 'violet'],
          entries: [],
          viaHomeEgg: true,
        ),
      ],
    );
    await pumpWidgetApp(
      tester,
      Scaffold(
        body: SingleChildScrollView(child: SpeciesInfo(form: form)),
      ),
      overrides: [savesProvider.overrideWith((ref) async => <Save>[])],
    );
    await tester.pumpAndSettle();
    expect(find.text('Pelo HOME, por ovo'), findsOne);
    expect(find.text('Scarlet / Violet'), findsOne);
  });
}
