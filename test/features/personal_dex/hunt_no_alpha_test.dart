import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/presentation/hunts_page.dart';

import '../../fixtures/catalog_fixture.dart';
import '../../helpers/helpers.dart';

// O motivo "Sem shiny alfa" nas Caçadas (#280, #348). Na fixture, Sword/Shield faz o
// papel dos jogos com alfa: Eevee, Vaporeon e Espeon podem ser alfa lá.

Catalog _catalog({bool alphas = true}) => Catalog.fromJson({
  ...catalogJson(),
  if (alphas)
    'alphaForms': [
      {
        'versionGroup': 'sword-shield',
        'forms': [133, 134, 196],
      },
    ],
}, spriteBase: Env.defaultSpritesBaseUrl);

/// Um shiny dex com Bulbasaur (vazio, sem alfa no jogo), Eevee (shiny, não
/// alfa), Vaporeon (vazio) e Espeon (shiny alfa).
Future<(FakeBackend, int)> _backend({bool alphas = true}) async {
  final backend = FakeBackend.fromCatalog(_catalog(alphas: alphas));
  final dexId = backend.addDex(name: 'Caça', isShinyDex: true);
  final box = backend.addBox(
    dexId: dexId,
    name: 'HOME 1',
    formIds: [1, 133, 134, 196],
  );
  final slots = await backend.fetchSlots(dexId: dexId, boxId: box);
  for (final (form, alpha) in [(133, false), (196, true)]) {
    await backend.deposit(
      slotId: slots.firstWhere((s) => s.form?.id == form).id,
      specimenId: backend.addSpecimen(
        formId: form,
        isShiny: true,
        isAlpha: alpha,
      ),
    );
  }
  return (backend, dexId);
}

Future<List<Hunt>> _hunts(
  FakeBackend backend,
  int dexId,
  HuntQuery query,
) async =>
    (await backend.fetchHunts(dexId, query, page: 1, pageSize: 50)).results;

List<String?> _names(List<Hunt> hunts) => [
  for (final h in hunts) h.slot.form?.name,
];

void main() {
  test('o catálogo diz em que jogos a forma pode ser alfa', () {
    final catalog = _catalog();
    expect(catalog.hasAlphaForms, isTrue);
    expect(catalog.alphaVersions(133).toSet(), {'sword', 'shield'});
    expect(catalog.alphaVersions(1), isEmpty);
    // Catálogo antigo, sem a chave.
    expect(_catalog(alphas: false).hasAlphaForms, isFalse);
    expect(_catalog(alphas: false).alphaVersions(133), isEmpty);
  });

  group('fetchHunts', () {
    test('desligado, um shiny que não é alfa já está completo', () async {
      final (backend, dexId) = await _backend();
      final hunts = await _hunts(backend, dexId, const HuntQuery());
      expect(_names(hunts), ['bulbasaur', 'vaporeon']);
      // O α não aparece em quem entra só por "Sem shiny".
      expect(hunts.every((h) => !h.reasons.contains(HuntReason.noAlpha)), true);
      final boxes = await backend.fetchHuntBoxes(dexId, const HuntQuery());
      expect(boxes.single.cells.take(4), [
        HuntCell.listed,
        HuntCell.done,
        HuntCell.listed,
        HuntCell.done,
      ]);
    });

    test(
      'só "Sem shiny alfa": quem pode ser alfa e não tem um shiny alfa',
      () async {
        final (backend, dexId) = await _backend();
        const query = HuntQuery(reasons: [HuntReason.noAlpha]);
        final hunts = await _hunts(backend, dexId, query);
        expect(_names(hunts), ['eevee', 'vaporeon']);
        // Só pelo alfa, onde caçar são os jogos com alfa.
        expect(hunts.first.versions.toSet(), {'sword', 'shield'});
        expect(hunts.first.reasons, [HuntReason.noAlpha]);
        final boxes = await backend.fetchHuntBoxes(dexId, query);
        // O Bulbasaur falta, mas fora do filtro; o Espeon alfa está completo.
        expect(boxes.single.cells.take(4), [
          HuntCell.hidden,
          HuntCell.listed,
          HuntCell.listed,
          HuntCell.done,
        ]);
      },
    );

    test('com "Sem shiny" junto, os jogos são todos', () async {
      final (backend, dexId) = await _backend();
      final hunts = await _hunts(
        backend,
        dexId,
        const HuntQuery(reasons: [HuntReason.noShiny, HuntReason.noAlpha]),
      );
      final vaporeon = hunts.firstWhere((h) => h.slot.form?.name == 'vaporeon');
      expect(vaporeon.reasons, [HuntReason.noShiny, HuntReason.noAlpha]);
      expect(vaporeon.versions, containsAll(['violet', 'sword']));
    });

    test('um alfa que não é shiny também entra (#348)', () async {
      final (backend, dexId) = await _backend();
      final slots = await backend.fetchSlots(
        dexId: dexId,
        boxId: (await backend.fetchBoxes(dexId)).single.id,
      );
      await backend.deposit(
        slotId: slots.firstWhere((s) => s.form?.id == 134).id,
        specimenId: backend.addSpecimen(formId: 134, isAlpha: true),
      );
      final hunts = await _hunts(
        backend,
        dexId,
        const HuntQuery(reasons: [HuntReason.noAlpha]),
      );
      expect(_names(hunts), ['eevee', 'vaporeon']);
      expect(hunts.last.reasons, [HuntReason.noShiny, HuntReason.noAlpha]);
    });

    test('com o filtro Jogo, só quem pode ser alfa naquele jogo', () async {
      final (backend, dexId) = await _backend();
      Future<List<String?>> names(List<String> versions) async => _names(
        await _hunts(
          backend,
          dexId,
          HuntQuery(reasons: const [HuntReason.noAlpha], versions: versions),
        ),
      );
      expect(await names(['scarlet']), isEmpty);
      expect(await names(['sword']), ['eevee', 'vaporeon']);
    });

    test('catálogo antigo: o motivo não pega nada', () async {
      final (backend, dexId) = await _backend(alphas: false);
      final hunts = await _hunts(
        backend,
        dexId,
        const HuntQuery(reasons: [HuntReason.noAlpha]),
      );
      expect(hunts, isEmpty);
    });
  });

  Future<void> open(WidgetTester tester, FakeBackend backend, int dexId) async {
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
        .read(routerProvider)
        .go(Routes.hunts(dexId: dexId));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is Tooltip && (w.message ?? '').startsWith('Motivos'),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in [compactSize, expandedSize]) {
    final px = '${size.width.toInt()}px';

    testWidgets('ligar "Sem shiny alfa" no menu e o α no item ($px)', (
      tester,
    ) async {
      final (backend, dexId) = await _backend();
      await pumpFullApp(tester, size: size, backend: backend);
      await open(tester, backend, dexId);
      expect(
        find.text(
          'Pode ser alfa em algum jogo, e o slot não tem um shiny alfa',
        ),
        findsOne,
      );
      await tester.tap(find.text('Sem shiny alfa'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('3 para caçar'), findsOne);
      final eevee = find.ancestor(
        of: find.text('Eevee'),
        matching: find.byType(HuntTile),
      );
      expect(
        find.descendant(of: eevee, matching: find.byTooltip('Sem shiny alfa')),
        findsOne,
      );
    });
  }

  testWidgets('no alfa que não é shiny, só o ✦̸ (#348)', (tester) async {
    final (backend, dexId) = await _backend();
    final slots = await backend.fetchSlots(
      dexId: dexId,
      boxId: (await backend.fetchBoxes(dexId)).single.id,
    );
    await backend.deposit(
      slotId: slots.firstWhere((s) => s.form?.id == 134).id,
      specimenId: backend.addSpecimen(formId: 134, isAlpha: true),
    );
    await pumpFullApp(tester, size: compactSize, backend: backend);
    await open(tester, backend, dexId);
    await tester.tap(find.text('Sem shiny alfa'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    final vaporeon = find.ancestor(
      of: find.text('Vaporeon'),
      matching: find.byType(HuntTile),
    );
    expect(
      find.descendant(of: vaporeon, matching: find.byTooltip('Não shiny')),
      findsOne,
    );
    expect(
      find.descendant(of: vaporeon, matching: find.byTooltip('Sem shiny alfa')),
      findsNothing,
    );
  });

  testWidgets('em inglês', (tester) async {
    final (backend, dexId) = await _backend();
    await pumpFullApp(tester, backend: backend, language: AppLanguage.en);
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
        .read(routerProvider)
        .go(Routes.hunts(dexId: dexId));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is Tooltip && (w.message ?? '').startsWith('Reasons'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No shiny alpha'), findsOne);
    expect(
      find.text('Can be alpha in some game, and the slot has no shiny alpha'),
      findsOne,
    );
  });

  testWidgets('catálogo antigo: o motivo some do menu', (tester) async {
    final (backend, dexId) = await _backend(alphas: false);
    await pumpFullApp(tester, backend: backend);
    await open(tester, backend, dexId);
    expect(find.text('Sem shiny'), findsWidgets);
    expect(find.text('Sem shiny alfa'), findsNothing);
  });
}
