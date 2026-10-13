import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/shiny_hunts/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/domain/shiny_odds.dart';
import 'package:ishinydex/features/shiny_hunts/shiny_hunt_providers.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

import '../fixtures/catalog_fixture.dart';
import '../helpers/helpers.dart';

void main() {
  test('catálogo: as regras de odds por método e jogo', () {
    final catalog = Catalog.fromJson({
      ...catalogJson(),
      'shinyOdds': [
        {
          'method': 'random',
          'versions': ['scarlet', 'violet'],
          'kind': 'rolls',
          'base': 4096,
          'rolls': 1,
          'charm': 2,
          'modifiers': <Object>[],
          'charmExceptForms': <Object>[],
        },
      ],
    }, spriteBase: Env.defaultSpritesBaseUrl);
    expect(catalog.oddsRule('random', 'violet')?.charm, 2);
    expect(catalog.oddsRule('random', 'sword'), isNull);
    expect(catalog.oddsRule('sr', 'scarlet'), isNull);
    // Catálogo antigo: sem regras.
    expect(
      Catalog.fromJson(
        catalogJson(),
        spriteBase: Env.defaultSpritesBaseUrl,
      ).shinyOdds,
      isEmpty,
    );
  });

  test(
    'caçada e registro: os campos das odds voltam pelos registros',
    () async {
      final backend = FakeBackend.seeded();
      final hunt = await backend.saveShinyHunt(
        const ShinyHunt(
          id: 0,
          form: 1,
          modifiers: {'sparkling': 2},
          chain: 3,
          bestChain: 9,
          miss: 0.5,
          estimated: true,
        ),
      );
      final plain = await backend.saveShinyHunt(
        const ShinyHunt(id: 0, form: 2),
      );
      final records = backend.records['shinyHunts']!;
      // A caçada sem odds fica como antes (sem as chaves novas).
      expect(
        records.firstWhere((h) => h['id'] == plain.id).keys,
        isNot(contains('miss')),
      );
      final copy = FakeBackend.seeded()..replaceRecords(backend.records);
      final back = (await copy.fetchShinyHunts()).firstWhere(
        (h) => h.id == hunt.id,
      );
      expect(back.modifiers, {'sparkling': 2});
      expect(
        (back.chain, back.bestChain, back.miss, back.estimated),
        (3, 9, 0.5, true),
      );

      await expectLater(
        backend.saveShinyHunt(hunt.copyWith(chain: 10)),
        throwsA(isA<ValidationFailure>()),
      );
      await expectLater(
        backend.saveShinyHunt(hunt.copyWith(chain: -1)),
        throwsA(isA<ValidationFailure>()),
      );

      // O registro do espécime guarda as odds do fim.
      final id = (await backend.fetchSlot(1)).specimen!.id;
      final specimen = await backend.fetchSpecimen(id);
      await backend.update(
        id,
        SpecimenDraft.fromSpecimen(specimen).copyWith(
          isShiny: true,
          hunt: const HuntRecord(
            method: 'random',
            count: 312,
            unit: 'encounters',
            odds: 273.53,
            multiple: 0.6,
            bestChain: 38,
          ),
        ),
      );
      final again = FakeBackend.seeded()..replaceRecords(backend.records);
      final record = (await again.fetchSpecimen(id)).hunt!;
      expect(
        (record.odds, record.multiple, record.bestChain),
        (273.53, 0.6, 38),
      );
    },
  );

  test('provider: a regra do jogo do save e o Charm dele', () async {
    final backend = FakeBackend.seeded();
    await backend.updateSave(1, hasShinyCharm: true);
    const rule = OddsRule(
      method: 'random',
      versions: {'scarlet'},
      kind: OddsKind.rolls,
      charm: 2,
    );
    final container = createContainer(
      overrides: [
        fakeBackendProvider.overrideWithValue(backend),
        oddsRuleProvider.overrideWithValue(
          (method, save) =>
              method == 'random' && save?.trainer.version == 'scarlet'
              ? rule
              : null,
        ),
      ],
    );
    await container.read(savesProvider.future);
    final odds = container.read(huntOddsProvider);
    expect(odds(const ShinyHunt(id: 1, form: 1, save: 1, method: 'random')), (
      rule: rule,
      hasCharm: true,
    ));
    expect(
      odds(const ShinyHunt(id: 1, form: 1, save: 1, method: 'sr')),
      isNull,
    );
    expect(odds(const ShinyHunt(id: 1, form: 1, method: 'random')), isNull);

    // Sem override: vem do catálogo do backend (sem catálogo, nada).
    final plain = createContainer(
      overrides: [fakeBackendProvider.overrideWithValue(FakeBackend())],
    );
    expect(plain.read(oddsRuleProvider)('random', null), isNull);
  });
}
