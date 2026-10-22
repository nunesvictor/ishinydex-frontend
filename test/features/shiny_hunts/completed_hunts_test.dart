import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/network/paginated.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/widgets/game_icon.dart';
import 'package:ishinydex/core/widgets/mark_icons.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/shiny_hunts/presentation/completed_hunts.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

import '../../fixtures/catalog_fixture.dart';
import '../../helpers/helpers.dart';

// A aba Concluídas das Caçadas (#297).

Map<String, dynamic> _method(String id, String en, String pt) => {
  'id': id,
  'label': pt,
  'labels': {'en': en, 'pt-BR': pt},
  'units': ['resets', 'encounters', 'hours'],
  'versions': ['sword', 'scarlet'],
};

/// Mewtwo (Sword, 3.200 resets em 18 dias), Eevee alfa (Scarlet, sem
/// contagem), Espeon (Scarlet, em horas), Nihilego (Sword, sem data de
/// captura) e um Pichu sem caçada.
FakeBackend _backend({bool hunts = true}) {
  final backend = FakeBackend.fromCatalog(
    Catalog.fromJson({
      ...catalogJson(),
      'shinyMethods': [
        _method('soft-reset', 'Soft reset', 'Soft reset'),
        _method('random', 'Random encounter', 'Encontro aleatório'),
      ],
    }, spriteBase: Env.defaultSpritesBaseUrl),
  );
  final ash = backend.addTrainer(name: 'Ash', trainerId: '1', version: 'sword');
  final red = backend.addTrainer(
    name: 'Red',
    trainerId: '2',
    version: 'scarlet',
  );
  backend.addSpecimen(formId: 172, isShiny: true, ot: ash);
  if (!hunts) return backend;
  backend
    ..addSpecimen(
      formId: 150,
      isShiny: true,
      ot: ash,
      capturedAt: DateTime(2026, 10, 10),
      hunt: HuntRecord(
        method: 'soft-reset',
        count: 3200,
        unit: 'resets',
        startedAt: DateTime(2026, 9, 22),
      ),
    )
    ..addSpecimen(
      formId: 133,
      isShiny: true,
      isAlpha: true,
      ot: red,
      capturedAt: DateTime(2026, 9, 20),
      hunt: const HuntRecord(method: 'random', unit: 'encounters'),
    )
    ..addSpecimen(
      formId: 196,
      isShiny: true,
      ot: red,
      capturedAt: DateTime(2026, 9, 13),
      hunt: const HuntRecord(method: 'soft-reset', count: 1800, unit: 'hours'),
    )
    ..addSpecimen(
      formId: 793,
      isShiny: true,
      ot: ash,
      hunt: const HuntRecord(method: 'soft-reset', count: 1022, unit: 'resets'),
    );
  return backend;
}

/// Um backend com 25 caçadas (duas páginas) que falha quando pedido: a 1ª
/// página uma vez, a 2ª uma vez (e depois volta encolhida) e a busca
/// "erro" uma vez.
class _Flaky extends FakeBackend {
  _Flaky() {
    addForm(id: 1, name: 'bulbasaur');
    for (var day = 1; day <= 25; day++) {
      addSpecimen(
        formId: 1,
        isShiny: true,
        nickname: 'B$day',
        capturedAt: DateTime(2026, 9, day),
        hunt: const HuntRecord(count: 10, unit: 'encounters'),
      );
    }
  }

  bool failFirst = false;
  var _second = 0;
  bool _searchFailed = false;

  @override
  Future<Paginated<Specimen>> fetchSpecimens(
    SpecimenQuery query, {
    required int page,
    required int pageSize,
  }) async {
    const failure = DataFailure(Problem.invalidData());
    if (page == 1 && failFirst) {
      failFirst = false;
      throw failure;
    }
    if (query.search == 'erro' && !_searchFailed) {
      _searchFailed = true;
      throw failure;
    }
    final result = await super.fetchSpecimens(
      query,
      page: page,
      pageSize: pageSize,
    );
    if (page != 2) return result;
    _second++;
    if (_second == 1) throw failure;
    // A lista encolheu entre as páginas: só um item na 2ª.
    return Paginated(
      count: result.count,
      results: result.results.take(1).toList(),
    );
  }
}

Future<void> _open(WidgetTester tester, FakeBackend backend, Size size) async {
  await pumpFullApp(
    tester,
    size: size,
    backend: backend,
    // O PNG do card (#243): nos testes, um falso.
    overrides: [
      pngCapturerProvider.overrideWithValue(
        (_, _) async => Uint8List.fromList([1]),
      ),
    ],
  );
  ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
      .read(routerProvider)
      .go(Routes.hunts());
  await tester.pumpAndSettle();
  final tab = find.descendant(
    of: find.byType(TabBar),
    matching: find.text('Concluídas'),
  );
  await tester.ensureVisible(tab);
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

List<String> _names(WidgetTester tester) => [
  for (final tile in tester.widgetList<CompletedHuntTile>(
    find.byType(CompletedHuntTile),
  ))
    tile.specimen.displayName,
];

void main() {
  group('FakeBackend', () {
    test(
      'só com registro, do mais recente ao sem data, e por método',
      () async {
        final backend = _backend();
        Future<List<String>> names(SpecimenQuery query) async => [
          for (final s in (await backend.fetchSpecimens(
            query,
            page: 1,
            pageSize: 50,
          )).results)
            s.displayName,
        ];
        expect(await names(completedHuntsQuery), [
          'Mewtwo',
          'Eevee',
          'Espeon',
          'Nihilego',
        ]);
        expect(
          await names(completedHuntsQuery.copyWith(huntMethods: ['random'])),
          ['Eevee'],
        );
        expect(
          completedHuntsQuery
              .copyWith(huntMethods: ['random', 'soft-reset'])
              .toQueryParameters(),
          {
            'has_hunt': true,
            'hunt_method': 'random,soft-reset',
            'ordering': '-captured_at',
          },
        );
      },
    );
  });

  for (final size in [compactSize, expandedSize]) {
    final px = '${size.width.toInt()}px';

    testWidgets('a lista, o número da aba e abrir o espécime ($px)', (
      tester,
    ) async {
      await _open(tester, _backend(), size);
      expect(huntsTab('Concluídas', '4'), findsOne);
      expect(find.text('4 caçadas'), findsOne);
      expect(_names(tester), ['Mewtwo', 'Eevee', 'Espeon', 'Nihilego']);
      Finder inTile(String name, Finder finder) => find.descendant(
        of: find.ancestor(
          of: find.text(name),
          matching: find.byType(CompletedHuntTile),
        ),
        matching: finder,
      );
      // Método e contagem; a duração e a data.
      expect(
        inTile(
          'Mewtwo',
          find.textContaining('3.200 resets', findRichText: true),
        ),
        findsOne,
      );
      expect(inTile('Mewtwo', find.textContaining('18 dias')), findsOne);
      expect(inTile('Mewtwo', find.byType(GameIcon)), findsOne);
      // Sem contagem, só o método; o alfa ao lado do nome.
      expect(
        inTile('Eevee', find.text('Encontro aleatório', findRichText: true)),
        findsOne,
      );
      expect(inTile('Eevee', find.byType(AlphaIcon)), findsOne);
      expect(
        inTile('Espeon', find.textContaining('30 h', findRichText: true)),
        findsOne,
      );
      expect(inTile('Nihilego', find.text('sem data de captura')), findsOne);

      await tester.tap(find.text('Mewtwo'));
      await tester.pumpAndSettle();
      expect(
        ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
            .read(routerProvider)
            .state
            .uri
            .path,
        startsWith(Routes.specimens),
      );
    });
  }

  testWidgets('Jogo: a folha com vários jogos e a contagem', (tester) async {
    await _open(tester, _backend(), compactSize);
    await tester.tap(find.text('Jogo'));
    await tester.pumpAndSettle();
    expect(find.text('Jogo do treinador original (OT)'), findsOne);
    await tester.tap(find.text('Scarlet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mostrar 2 resultados'));
    await tester.pumpAndSettle();
    expect(find.text('2 caçadas em Scarlet'), findsOne);
    expect(_names(tester), ['Eevee', 'Espeon']);
    expect(find.byTooltip('Jogo: Scarlet'), findsOne);
  });

  testWidgets('Método: vários de uma vez, num menu de marcar', (tester) async {
    await _open(tester, _backend(), compactSize);
    await tester.tap(find.text('Método'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxMenuButton, 'Soft reset'));
    await tester.pumpAndSettle();
    expect(_names(tester), ['Mewtwo', 'Espeon', 'Nihilego']);
    await tester.tap(
      find.widgetWithText(CheckboxMenuButton, 'Encontro aleatório'),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Método: Soft reset e Encontro aleatório'), findsOne);
    await tester.tap(find.widgetWithText(CheckboxMenuButton, 'Soft reset'));
    await tester.pumpAndSettle();
    expect(_names(tester), ['Eevee']);
  });

  testWidgets('a busca sem resultado e o card para compartilhar', (
    tester,
  ) async {
    await _open(tester, _backend(), compactSize);
    await tester.tap(find.byTooltip('Compartilhar').first);
    await tester.pumpAndSettle();
    expect(find.text('Compartilhar a caçada'), findsOne);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma caçada com estes filtros.'), findsOne);
  });

  testWidgets('sem caçada concluída, como uma chega aqui', (tester) async {
    await _open(tester, _backend(hunts: false), compactSize);
    expect(find.text('Nenhuma caçada concluída ainda'), findsOne);
    expect(find.textContaining('Encontrei!'), findsOne);
  });

  testWidgets('páginas, erros, busca com espera e puxar para atualizar', (
    tester,
  ) async {
    final backend = _Flaky()..failFirst = true;
    await _open(tester, backend, compactSize);
    // A 1ª página falhou: tentar de novo.
    expect(find.text('Tentar novamente'), findsOne);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(huntsTab('Concluídas', '25'), findsOne);
    expect(find.text('25 caçadas'), findsOne);

    // A 2ª página falha uma vez; depois volta com um item só.
    final list = find.byType(ListView).last;
    await tester.drag(list, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar mais espécimes.'), findsOne);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('B5'), findsOne);
    expect(find.text('B4'), findsNothing);

    // Puxar para atualizar.
    await tester.drag(list, const Offset(0, 3000));
    await tester.pumpAndSettle();
    await tester.fling(list, const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(find.text('B25'), findsOne);

    // A busca espera parar de digitar; a 1ª vez, falha.
    await tester.enterText(find.byType(TextField), 'erro');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOne);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma caçada com estes filtros.'), findsOne);
  });
}
