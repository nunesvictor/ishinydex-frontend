import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/specimens_page.dart';

import '../../fixtures/catalog_fixture.dart';
import '../../helpers/helpers.dart';

/// O catálogo da fixture com dois OTs (Scarlet e Sword), um save de cada e
/// três espécimes: Eevee (OT Scarlet; nas pokédex de SwSh e SV), Bulbasaur
/// (OT Sword; só no BDSP) e Nihilego (OT Sword; em nenhuma).
Future<({FakeBackend backend, int eevee, int bulbasaur, int nihilego})>
_setUp() async {
  final catalog = Catalog.fromJson(
    catalogJson(),
    spriteBase: Env.defaultSpritesBaseUrl,
  );
  final backend = FakeBackend.fromCatalog(catalog);
  final scarlet = backend.addTrainer(
    name: 'Ash',
    trainerId: '1',
    version: 'scarlet',
  );
  final sword = backend.addTrainer(
    name: 'Ash',
    trainerId: '2',
    version: 'sword',
  );
  await backend.createSave(trainerId: scarlet);
  await backend.createSave(trainerId: sword);
  return (
    backend: backend,
    eevee: backend.addSpecimen(formId: 133, ot: scarlet),
    bulbasaur: backend.addSpecimen(formId: 1, ot: sword),
    nihilego: backend.addSpecimen(formId: 793, ot: sword),
  );
}

void main() {
  test('capturados em ("ou") e podem ir para ("e" entre os dois)', () async {
    final (:backend, :eevee, :bulbasaur, :nihilego) = await _setUp();
    // Só os três do teste (o catálogo de demonstração já traz outros).
    final mine = {eevee, bulbasaur, nihilego};
    Future<Set<int>> ids(SpecimenQuery query) async => {
      for (final s in (await backend.fetchSpecimens(
        query,
        page: 1,
        pageSize: 500,
      )).results)
        if (mine.contains(s.id)) s.id,
    };

    expect(await ids(const SpecimenQuery(otVersions: ['scarlet'])), {eevee});
    expect(await ids(const SpecimenQuery(otVersions: ['scarlet', 'sword'])), {
      eevee,
      bulbasaur,
      nihilego,
    });
    expect(await ids(const SpecimenQuery(fitVersions: ['sword'])), {eevee});
    expect(await ids(const SpecimenQuery(fitVersions: ['brilliant-diamond'])), {
      bulbasaur,
    });
    expect(
      await ids(
        const SpecimenQuery(otVersions: ['sword'], fitVersions: ['scarlet']),
      ),
      isEmpty,
    );
    expect(
      await ids(
        const SpecimenQuery(
          otVersions: ['scarlet', 'sword'],
          fitVersions: ['brilliant-diamond', 'scarlet'],
        ),
      ),
      {eevee, bulbasaur},
    );
    // Let's Go só recebe quem tem a marca dele.
    expect(
      await ids(const SpecimenQuery(fitVersions: ['lets-go-pikachu'])),
      isEmpty,
    );
    expect(
      const SpecimenQuery(
        otVersions: ['sword'],
        fitVersions: ['scarlet'],
      ).toQueryParameters(),
      {'ot_version': 'sword', 'fits_version': 'scarlet'},
    );
    expect(
      const SpecimenQuery(
        otVersions: ['sword'],
        shinyOnly: true,
        types: ['fire'],
      ).clearAdvanced(),
      const SpecimenQuery(otVersions: ['sword'], shinyOnly: true),
    );
  });

  test('o filtro em palavras', () {
    expect(gameFilterLabel(const SpecimenQuery()), isNull);
    expect(
      gameFilterLabel(
        const SpecimenQuery(
          otVersions: ['sword', 'shield', 'scarlet'],
          fitVersions: ['legends-za'],
        ),
      ),
      'capturados em Sword, Shield ou Scarlet e podem ir para Legends: Z-A',
    );
  });

  for (final size in [compactSize, expandedSize]) {
    testWidgets('chip Jogo: seções recolhíveis (${size.width.toInt()}px)', (
      tester,
    ) async {
      final (:backend, eevee: _, bulbasaur: _, nihilego: _) = await _setUp();
      await pumpFullApp(tester, size: size, backend: backend);
      await tester.tap(find.text('Espécimes').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Jogo'));
      await tester.pumpAndSettle();

      // As duas seções começam fechadas.
      expect(find.text('Capturados em'), findsOneWidget);
      expect(find.text('Podem ir para'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('game-section-0')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(CheckboxListTile),
          matching: find.text('Scarlet'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 marcado'), findsOneWidget);
      // Fechar a seção mantém o marcado.
      await tester.tap(find.byKey(const ValueKey('game-section-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Mostrar'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilterChip, 'Scarlet'), findsOneWidget);
      expect(find.textContaining('capturados em Scarlet'), findsOneWidget);

      // Reaberta, a seção com jogo marcado já vem aberta.
      await tester.tap(find.widgetWithText(FilterChip, 'Scarlet'));
      await tester.pumpAndSettle();
      expect(find.text('1 marcado'), findsOneWidget);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.ancestor(
                of: find.text('Scarlet'),
                matching: find.byType(CheckboxListTile),
              ),
            )
            .value,
        isTrue,
      );
      // A lista rola: o que está embaixo precisa aparecer antes do toque.
      Future<void> tapVisible(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tapVisible(find.byKey(const ValueKey('game-section-1')));
      await tapVisible(
        find
            .descendant(
              of: find.byType(CheckboxListTile),
              matching: find.text('Sword'),
            )
            .last,
      );
      await tester.tap(find.textContaining('Mostrar'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilterChip, 'Scarlet +1'), findsOneWidget);
      expect(
        find.textContaining('capturados em Scarlet e podem ir para Sword'),
        findsOneWidget,
      );

      // "Todos os jogos" limpa as duas seções.
      await tester.tap(find.widgetWithText(FilterChip, 'Scarlet +1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todos os jogos'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Mostrar'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilterChip, 'Jogo'), findsOneWidget);
    });
  }

  testWidgets('sem OT nem save, sem o chip', (tester) async {
    await pumpFullApp(tester, size: compactSize, backend: FakeBackend());
    await tester.tap(find.text('Espécimes').first);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilterChip, 'Jogo'), findsNothing);
  });
}
