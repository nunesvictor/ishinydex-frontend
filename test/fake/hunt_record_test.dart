import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

import '../fixtures/catalog_fixture.dart';
import '../helpers/helpers.dart';

Catalog _catalog({bool withMethods = true}) => Catalog.fromJson({
  ...catalogJson(),
  if (withMethods)
    'shinyMethods': [
      {
        'id': 'sr',
        'label': 'Soft reset',
        'units': ['resets', 'hours'],
        'versions': ['sword'],
      },
      {
        'id': 'random',
        'label': 'Encontro aleatório',
        'units': ['encounters', 'hours'],
        'versions': ['sword', 'scarlet'],
      },
    ],
}, spriteBase: Env.defaultSpritesBaseUrl);

void main() {
  final day = DateTime(2026, 9, 14);
  final hunt = HuntRecord(
    method: 'sr',
    count: 4213,
    unit: 'resets',
    startedAt: DateTime(2026, 6, 12),
    postUrl: 'https://reddit.com/r/ShinyPokemon/1',
  );

  test('catálogo: métodos do jogo do OT, todos ou nenhum (GO)', () {
    final catalog = _catalog();
    List<String> ids(String? v, {bool go = false}) => [
      for (final m in catalog.shinyMethodsFor(v, fromGo: go)) m.id,
    ];
    expect(ids('scarlet'), ['random']);
    expect(ids('sword'), ['sr', 'random']);
    expect(ids(null), ['sr', 'random']);
    expect(ids('red'), ['sr', 'random']);
    expect(ids('sword', go: true), isEmpty);
    expect(_catalog(withMethods: false).shinyMethods, isEmpty);

    final container = createContainer(
      overrides: [
        fakeBackendProvider.overrideWithValue(FakeBackend.fromCatalog(catalog)),
      ],
    );
    expect(container.read(shinyMethodsProvider)('scarlet').single.id, 'random');
    final empty = createContainer(
      overrides: [fakeBackendProvider.overrideWithValue(FakeBackend())],
    );
    expect(empty.read(shinyMethodsProvider)('scarlet'), isEmpty);
    expect(
      () => empty.read(openLinkProvider)('https://x'),
      throwsUnsupportedError,
    );
  });

  test('guarda, valida e volta pelos registros', () async {
    final backend = FakeBackend.fromCatalog(_catalog());
    final form = _catalog().formIds.first;
    SpecimenDraft draft(HuntRecord? h, {bool shiny = true}) => SpecimenDraft(
      form: form,
      ability: '',
      isShiny: shiny,
      capturedAt: day,
      hunt: h,
    );

    final saved = await backend.create(draft(hunt));
    expect(saved.hunt, hunt);
    // Fora de shiny ou em branco (só o início): não guarda.
    expect((await backend.create(draft(hunt, shiny: false))).hunt, isNull);
    expect(
      (await backend.create(draft(HuntRecord(startedAt: day)))).hunt,
      isNull,
    );
    // Link vazio vira nulo.
    expect(
      (await backend.create(draft(const HuntRecord(count: 3, postUrl: ''))))
          .hunt,
      const HuntRecord(count: 3),
    );

    Future<void> fails(HuntRecord h, String field) => expectLater(
      backend.create(draft(h)),
      throwsA(
        isA<ValidationFailure>().having((f) => f.fieldErrors.keys, 'campos', [
          field,
        ]),
      ),
    );
    await fails(const HuntRecord(method: 'masuda'), 'huntMethod');
    await fails(const HuntRecord(count: 0), 'huntCount');
    await fails(const HuntRecord(method: 'sr', unit: 'eggs'), 'huntUnit');
    await fails(
      HuntRecord(count: 1, startedAt: DateTime(2026, 9, 15)),
      'huntStartedAt',
    );
    await fails(const HuntRecord(postUrl: 'ftp://x'), 'huntPostUrl');
    await fails(const HuntRecord(postUrl: 'http://[x'), 'huntPostUrl');

    // Editar troca o registro; ida e volta pelos registros.
    final edited = await backend.update(
      saved.id,
      draft(hunt.copyWith(count: 5000)),
    );
    expect(edited.hunt?.count, 5000);
    final copy = FakeBackend.fromCatalog(_catalog())
      ..replaceRecords(backend.records);
    expect((await copy.fetchSpecimen(saved.id)).hunt, edited.hunt);

    // Deixar de ser shiny (edição em lote) apaga o registro.
    await backend.bulkUpdate(
      ids: [saved.id],
      changes: const SpecimenChanges(isShiny: SetTo(false)),
    );
    expect((await backend.fetchSpecimen(saved.id)).hunt, isNull);
  });

  test('textos: contagem, horas e duração', () {
    expect(huntCountLabel(4213, 'resets'), '4.213 resets');
    expect(huntCountLabel(12, null), '12');
    expect(huntCountLabel(3, 'laps'), '3 laps');
    expect(huntCountLabel(2310, 'hours'), '38 h 30 min');
    expect(huntCountLabel(120, 'hours'), '2 h');
    expect(huntCountLabel(45, 'hours'), '45 min');
    expect(huntDuration(day, day), 'menos de um dia');
    expect(huntDuration(day, DateTime(2026, 9, 15)), '1 dia');
    expect(huntDuration(day, DateTime(2026, 9, 26)), '12 dias');
    expect(huntDuration(DateTime(2026, 6, 12), day), '3 meses');
    expect(huntDuration(DateTime(2026, 8, 10), day), '1 mês');
    expect(huntDuration(DateTime(2024, 6, 12), day), '2 anos');
    expect(huntDuration(DateTime(2025, 6, 12), day), '1 ano');
    expect(const HuntRecord(postUrl: '').isBlank, isTrue);
    expect(const HuntRecord(postUrl: 'x').isBlank, isFalse);
    expect(HuntRecord.fromJson(hunt.toJson()), hunt);
    expect(
      SpecimenDraft(form: 1, hunt: hunt).toRequestJson()['hunt'],
      hunt.toJson(),
    );
  });
}
