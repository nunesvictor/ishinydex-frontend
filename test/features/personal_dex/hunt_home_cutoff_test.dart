import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/clock.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/hunt_filters.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

import '../../fixtures/catalog_fixture.dart';
import '../../helpers/helpers.dart';

final _until = DateTime.utc(2027, 2, 26, 3);
final _before = DateTime.utc(2026, 10, 20, 12);
final _after = DateTime.utc(2027, 3, 2);

/// A fixture com Sun/Moon fechando no HOME e uma pokédex de Alola: o
/// Nihilego só está nela (só no 3DS); o Eevee também está em Galar e Paldea.
Catalog _catalog() {
  final json = catalogJson();
  return Catalog.fromJson({
    ...json,
    'versions': [
      for (final v in (json['versions'] as List).cast<Map<String, dynamic>>())
        if (v['versionGroup'] == 'sun-moon')
          {...v, 'homeUntil': '2027-02-26T03:00:00Z'}
        else
          v,
    ],
    'pokedexes': [
      ...json['pokedexes'] as List,
      {
        'name': 'original-alola',
        'label': 'Alola',
        'versionGroups': ['sun-moon'],
        'dlc': null,
        'entries': [
          ['eevee', 1],
          ['nihilego', 2],
        ],
      },
    ],
  }, spriteBase: Env.defaultSpritesBaseUrl);
}

/// Um shiny dex com o dex padrão inteiro faltando.
(FakeBackend, int) _backend({DateTime? now}) {
  final catalog = _catalog();
  final backend = FakeBackend.fromCatalog(catalog)..now = () => now ?? _before;
  final dexId = backend.addDex(name: 'Caça', isShinyDex: true);
  backend.addBox(dexId: dexId, name: 'Caça 1', formIds: catalog.defaultDex);
  return (backend, dexId);
}

Future<List<String>> _names(
  FakeBackend backend,
  int dexId,
  HomeCutoffFilter filter,
) async => [
  for (final hunt in (await backend.fetchHunts(
    dexId,
    HuntQuery(homeCutoff: filter),
    page: 1,
    pageSize: 50,
  )).results)
    hunt.slot.form!.name,
];

Future<void> _openHunts(
  WidgetTester tester, {
  required Size size,
  AppLanguage language = AppLanguage.pt,
}) async {
  final (backend, dexId) = _backend();
  await pumpFullApp(
    tester,
    size: size,
    backend: backend,
    language: language,
    overrides: [clockProvider.overrideWithValue(() => _before)],
  );
  ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
      .read(routerProvider)
      .go(Routes.hunts(dexId: dexId));
  await tester.pumpAndSettle();
}

/// O chip da opção [label] na folha de filtros.
Finder _option(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip));

void main() {
  test('backend: só no 3DS, também no 3DS e depois do corte', () async {
    final (backend, dexId) = _backend();
    expect(await _names(backend, dexId, HomeCutoffFilter.only), ['nihilego']);
    expect(await _names(backend, dexId, HomeCutoffFilter.also), [
      'eevee',
      'nihilego',
    ]);
    expect(
      await _names(backend, dexId, HomeCutoffFilter.all),
      hasLength(greaterThan(2)),
    );

    final (closed, closedId) = _backend(now: _after);
    expect(await _names(closed, closedId, HomeCutoffFilter.only), isEmpty);
    expect(await _names(closed, closedId, HomeCutoffFilter.also), isEmpty);
  });

  test('backend sem catálogo: nada fecha', () async {
    final backend = FakeBackend.seeded();
    final dex = (await backend.fetchDexes()).firstWhere((d) => d.isShinyDex);
    expect(await _names(backend, dex.id, HomeCutoffFilter.also), isEmpty);
  });

  test('nextHomeCutoffProvider: a data até o corte; depois, nenhuma', () {
    DateTime? read(DateTime now, {Catalog? catalog}) => createContainer(
      overrides: [
        fakeBackendProvider.overrideWithValue(FakeBackend(catalog: catalog)),
        clockProvider.overrideWithValue(() => now),
      ],
    ).read(nextHomeCutoffProvider);

    expect(read(_before, catalog: _catalog()), _until);
    expect(read(_after, catalog: _catalog()), isNull);
    expect(read(_before), isNull);
  });

  for (final size in [compactSize, expandedSize]) {
    final px = '${size.width.toInt()}px';

    testWidgets('Fecha no HOME: escolher, aplicar e tirar o chip (#316, $px)', (
      tester,
    ) async {
      await _openHunts(tester, size: size);
      expect(find.text('Bulbasaur'), findsOneWidget);

      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Fecha no HOME · '), findsOneWidget);
      // Cada opção com a contagem; Todos vem marcado e sem explicação.
      expect(
        find.descendant(of: _option('Só no 3DS'), matching: find.text('1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _option('Também no 3DS'), matching: find.text('2')),
        findsOneWidget,
      );
      expect(tester.widget<ChoiceChip>(_option('Todos')).selected, isTrue);
      expect(find.textContaining('nenhum outro jogo tem'), findsNothing);

      await tester.tap(_option('Também no 3DS'));
      await tester.pumpAndSettle();
      expect(find.textContaining('mesmo que também em outro'), findsOneWidget);
      await tester.tap(_option('Só no 3DS'));
      await tester.pumpAndSettle();
      expect(find.textContaining('nenhum outro jogo tem'), findsOneWidget);
      await tester.tap(find.text('Mostrar resultados'));
      await tester.pumpAndSettle();

      expect(find.text('Nihilego'), findsOneWidget);
      expect(find.text('Bulbasaur'), findsNothing);
      final chip = find.widgetWithText(InputChip, 'Só no 3DS');
      expect(chip, findsOneWidget);

      await tester.tap(
        find.descendant(of: chip, matching: find.byTooltip('Remover filtro')),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, 'Só no 3DS'), findsNothing);
      expect(find.text('Bulbasaur'), findsOneWidget);
    });
  }

  testWidgets('Fecha no HOME em inglês', (tester) async {
    await _openHunts(tester, size: compactSize, language: AppLanguage.en);
    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Leaves HOME · '), findsOneWidget);
    await tester.tap(_option('Only on 3DS'));
    await tester.pumpAndSettle();
    expect(find.textContaining('no other game has it'), findsOneWidget);
  });

  testWidgets('depois do corte, a escolha some', (tester) async {
    final (backend, dexId) = _backend(now: _after);
    await pumpFullApp(
      tester,
      backend: backend,
      overrides: [clockProvider.overrideWithValue(() => _after)],
    );
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
        .read(routerProvider)
        .go(Routes.hunts(dexId: dexId));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Fecha no HOME'), findsNothing);
  });

  testWidgets('depois do corte, um filtro que ficou ligado ainda se desliga, '
      'sem data e sem contagem', (tester) async {
    await pumpWidgetApp(
      tester,
      const Scaffold(
        body: HuntFiltersPanel(
          initial: HuntQuery(homeCutoff: HomeCutoffFilter.only),
        ),
      ),
      overrides: [
        fakeBackendProvider.overrideWithValue(FakeBackend(catalog: _catalog())),
        clockProvider.overrideWithValue(() => _after),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('Fecha no HOME'), findsOneWidget);
    await tester.tap(_option('Todos'));
    await tester.pumpAndSettle();
    expect(find.text('Fecha no HOME'), findsNothing);
  });
}
