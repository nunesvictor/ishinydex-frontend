import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/widgets/game_icon.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/presentation/hunts_page.dart';
import 'package:ishinydex/features/specimens/domain/home_cutoff.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

import '../../fixtures/api_fixtures.dart';
import '../../fixtures/catalog_fixture.dart';
import '../../helpers/helpers.dart';

// O Faltam agrupado pela box do dex (#282): a busca das boxes, o cabeçalho
// com o mapa e o item de duas linhas.

/// Um shiny dex em duas boxes: HOME 1 com Bulbasaur, Ivysaur (shiny no
/// slot), Venusaur e Eevee; HOME 2 com Vaporeon e Espeon.
Future<(FakeBackend, int)> _backend() async {
  final backend = FakeBackend.fromCatalog(
    Catalog.fromJson(catalogJson(), spriteBase: Env.defaultSpritesBaseUrl),
  );
  final dexId = backend.addDex(name: 'Caça', isShinyDex: true);
  final first = backend.addBox(
    dexId: dexId,
    name: 'HOME 1',
    formIds: [1, 2, 3, 133],
  );
  backend.addBox(dexId: dexId, name: 'HOME 2', formIds: [134, 196]);
  final ivysaur = (await backend.fetchSlots(
    dexId: dexId,
    boxId: first,
  )).firstWhere((s) => s.form?.id == 2);
  await backend.deposit(
    slotId: ivysaur.id,
    specimenId: backend.addSpecimen(formId: 2, isShiny: true),
  );
  return (backend, dexId);
}

void main() {
  group('fetchHuntBoxes', () {
    test('a contagem e o mapa de cada box, na ordem da lista', () async {
      final (backend, dexId) = await _backend();
      final boxes = await backend.fetchHuntBoxes(dexId, const HuntQuery());
      expect(
        [for (final b in boxes) (b.box.name, b.count)],
        [('HOME 1', 3), ('HOME 2', 2)],
      );
      expect(boxes.first.cells.take(5), [
        HuntCell.listed,
        HuntCell.done,
        HuntCell.listed,
        HuntCell.listed,
        HuntCell.empty,
      ]);
      expect(boxes.first.cells, hasLength(30));

      // A lista paginada segue a mesma ordem.
      final hunts = (await backend.fetchHunts(
        dexId,
        const HuntQuery(),
        page: 1,
        pageSize: 50,
      )).results;
      expect(
        [for (final h in hunts) h.slot.box.name],
        ['HOME 1', 'HOME 1', 'HOME 1', 'HOME 2', 'HOME 2'],
      );
    });

    test('o que falta fora dos filtros fica só no contorno', () async {
      final (backend, dexId) = await _backend();
      final boxes = await backend.fetchHuntBoxes(
        dexId,
        const HuntQuery(search: 'venusaur'),
      );
      // HOME 2 fica sem item: a box some.
      expect(boxes, hasLength(1));
      expect(boxes.single.count, 1);
      expect(boxes.single.cells.take(4), [
        HuntCell.hidden,
        HuntCell.done,
        HuntCell.listed,
        HuntCell.hidden,
      ]);
    });
  });

  for (final size in [compactSize, expandedSize]) {
    final px = '${size.width.toInt()}px';

    testWidgets('cabeçalho por box, preso no topo, e "Abrir box" ($px)', (
      tester,
    ) async {
      final (backend, dexId) = await _backend();
      await pumpFullApp(tester, size: size, backend: backend);
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
          .read(routerProvider)
          .go(Routes.hunts(dexId: dexId));
      await tester.pumpAndSettle();

      Finder header(String text) =>
          find.textContaining(text, findRichText: true);
      expect(header('HOME 1'), findsOne);
      expect(header('3 faltam'), findsOne);
      expect(header('2 faltam'), findsOne);
      expect(find.byType(HuntBoxMap), findsNWidgets(2));

      // Rolando, o cabeçalho da box fica no topo da lista.
      final list = find.byType(CustomScrollView);
      final top = tester.getTopLeft(list).dy;
      await tester.drag(list, const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(HuntBoxHeader).first).dy, top);

      await tester.tap(find.text('Abrir box').first);
      await tester.pumpAndSettle();
      expect(
        ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
            .read(routerProvider)
            .state
            .uri
            .path,
        Routes.huntsDex(dexId),
      );
    });
  }

  group('item', () {
    const versions = [
      'sword',
      'shield',
      'brilliant-diamond',
      'shining-pearl',
      'scarlet',
      'violet',
      'x',
      'y',
      'sun',
    ];
    final hunt = Hunt.parse({
      ...missingSlotJson,
      'form': {
        ...formRefJson,
        'name': 'alcremie-rainbow-swirl-strawberry-sweet',
      },
      'reasons': ['no_shiny'],
      'shiny_lock': null,
    }).copyWith(versions: versions);

    Future<void> pump(WidgetTester tester, double width) => pumpWidgetApp(
      tester,
      Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: HuntTile(hunt: hunt, onTap: () {}),
          ),
        ),
      ),
      size: width > compactSize.width ? expandedSize : compactSize,
      overrides: [
        savesProvider.overrideWith(
          (ref) async => [
            for (final (i, v) in versions.indexed)
              Save(
                id: i + 1,
                trainer: Trainer(
                  id: i + 1,
                  name: 'Ash',
                  trainerId: '$i',
                  version: v,
                ),
              ),
          ],
        ),
        // Todos os jogos com corte: a etiqueta do HOME aparece.
        homeCutoffProvider.overrideWithValue(
          (version) => HomeCutoff(
            until: DateTime.utc(2027, 2, 26, 3),
            now: DateTime(2026, 10, 22),
          ),
        ),
      ],
    );

    const name = 'Alcremie Rainbow Swirl Strawberry Sweet';

    testWidgets('no celular: nome em duas linhas e onde caçar embaixo', (
      tester,
    ) async {
      await pump(tester, 360);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // O nome quebra em duas linhas (a fonte dos testes tem 16 px).
      expect(tester.getSize(find.text(name)).height, greaterThan(24));
      // Até 6 jogos lado a lado, depois "+3".
      expect(find.byType(GameIcon), findsNWidgets(6));
      expect(find.text('+3'), findsOne);
      // O divisor separa os jogos da etiqueta do HOME.
      expect(find.byType(VerticalDivider), findsOne);
      final tag = find.byKey(const ValueKey('home-tag'));
      expect(
        tester.getTopLeft(tag).dy,
        greaterThan(tester.getBottomLeft(find.text(name)).dy - 1),
      );
    });

    testWidgets('no PC: tudo numa linha', (tester) async {
      await pump(tester, 1000);
      await tester.pumpAndSettle();
      expect(find.byType(VerticalDivider), findsNothing);
      final tag = find.byKey(const ValueKey('home-tag'));
      expect(
        tester.getCenter(tag).dy,
        closeTo(tester.getCenter(find.text(name)).dy, 2),
      );
      expect(
        tester.getTopLeft(tag).dx,
        greaterThan(tester.getTopRight(find.text(name)).dx),
      );
    });
  });
}
