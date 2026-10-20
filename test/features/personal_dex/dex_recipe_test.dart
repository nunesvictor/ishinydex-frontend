import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';

import '../../fixtures/catalog_fixture.dart';

/// O catálogo de teste com formas regionais e alternativas no padrão:
/// Bulbasaur → Ivysaur → Venusaur, Eevee → Vaporeon/Espeon, o Vaporeon de
/// Galar (regional, não evolui), Pichu (não evolui no fixture) e o Pichu
/// "teal" (alternativo).
Catalog _catalog({List<int>? defaultDex}) => Catalog.fromJson({
  ...catalogJson(),
  'defaultDex':
      defaultDex ?? [1, 2, 3, 133, 134, 10600, 196, 150, 172, 10500, 793],
  'formEvolutions': {
    'evolutions': [
      [133, 134],
      [133, 196],
    ],
    'withoutEvolution': [10600],
  },
}, spriteBase: Env.defaultSpritesBaseUrl);

void main() {
  group('DexRecipe', () {
    test('os atalhos e o "Personalizado"', () {
      expect(const DexRecipe().preset, DexPreset.livingFormLite);
      for (final preset in DexPreset.values) {
        expect(DexRecipe.of(preset).preset, preset);
        // Todos os atalhos levam as regionais.
        expect(DexRecipe.of(preset).regional, isTrue);
      }
      expect(DexRecipe.of(DexPreset.living).alternateForms, isFalse);
      expect(DexRecipe.of(DexPreset.finalFormForm).preEvolutions, isFalse);
      expect(const DexRecipe(regional: false).preset, isNull);
    });

    test('ida e volta em JSON', () {
      final recipe = DexRecipe.of(DexPreset.finalForm);
      expect(DexRecipe.fromJson(recipe.toJson()), recipe);
      // Chave ausente: o padrão (o Living Form Lite).
      expect(DexRecipe.fromJson(const {}), const DexRecipe());
    });
  });

  group('Catalog.dexForms (#34)', () {
    final catalog = _catalog();

    test('com as três chaves, o conjunto padrão inteiro', () {
      expect(catalog.dexForms(const DexRecipe()), catalog.defaultDex);
    });

    test('sem as regionais, sai o Vaporeon de Galar', () {
      expect(catalog.dexForms(const DexRecipe(regional: false)), [
        1,
        2,
        3,
        133,
        134,
        196,
        150,
        172,
        10500,
        793,
      ]);
    });

    test('sem as pré-evoluções (Final Form): só o que não evolui mais', () {
      // Saem o Bulbasaur e o Ivysaur (pela espécie) e o Eevee (pelas
      // arestas curadas); o Vaporeon de Galar não evolui e fica.
      expect(catalog.dexForms(const DexRecipe(preEvolutions: false)), [
        3,
        134,
        10600,
        196,
        150,
        172,
        10500,
        793,
      ]);
    });

    test('sem as formas alternativas: uma por espécie, mais as regionais', () {
      expect(catalog.dexForms(const DexRecipe(alternateForms: false)), [
        1,
        2,
        3,
        133,
        134,
        10600,
        196,
        150,
        172,
        793,
      ]);
      expect(catalog.dexForms(DexRecipe.of(DexPreset.finalForm)), [
        3,
        134,
        10600,
        196,
        150,
        172,
        793,
      ]);
    });

    test('espécie sem a forma padrão no conjunto: fica a primeira', () {
      // Como o Minior, cuja forma padrão (a casca vermelha) não entra.
      final withoutBase = _catalog(defaultDex: [1, 10500, 793]);
      expect(withoutBase.dexForms(const DexRecipe(alternateForms: false)), [
        1,
        10500,
        793,
      ]);
    });
  });

  group('FakeBackend', () {
    final catalog = _catalog();

    test('a prévia e o dex seguem a receita, que fica no dex', () async {
      final backend = FakeBackend.local(catalog);
      final finalForm = DexRecipe.of(DexPreset.finalForm);
      final preview = await backend.previewNewDex(
        recipe: finalForm,
        forceNewBox: false,
      );
      expect(preview.forms, 7);

      final dex = await backend.createDex(
        name: 'Final',
        isShinyDex: true,
        forceNewBox: false,
        recipe: finalForm,
      );
      expect(dex.recipe, finalForm);
      final box = (await backend.fetchBoxes(dex.id)).single;
      final slots = await backend.fetchSlots(dexId: dex.id, boxId: box.id);
      expect(
        [for (final s in slots) s.form?.id].whereType<int>(),
        catalog.dexForms(finalForm),
      );

      // A receita vai para o arquivo de dados e volta.
      final record = (backend.records['dexes']!).single;
      expect(record['recipe'], finalForm.toJson());
      final restored = FakeBackend.local(catalog, records: backend.records);
      expect((await restored.fetchDex(dex.id)).recipe, finalForm);
    });

    test('dex de antes do #34: sem receita no arquivo', () async {
      final backend = FakeBackend.local(catalog);
      final dex = await backend.createDex(
        name: 'Shiny',
        isShinyDex: true,
        forceNewBox: false,
      );
      final records = {
        ...backend.records,
        'dexes': [
          for (final d in backend.records['dexes']!) {...d}..remove('recipe'),
        ],
      };
      final restored = FakeBackend.local(catalog, records: records);
      expect((await restored.fetchDex(dex.id)).recipe, isNull);
      expect(restored.records['dexes']!.single.containsKey('recipe'), isFalse);
    });
  });
}
