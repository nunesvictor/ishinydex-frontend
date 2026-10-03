import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/network/paginated.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/mark_icons.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/hunts_page.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/api_fixtures.dart';
import '../../helpers/helpers.dart';
import '../../helpers/mocks.dart';

Future<void> _go(WidgetTester tester, String location) async {
  ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
      .read(routerProvider)
      .go(location);
  await tester.pumpAndSettle();
}

/// Abre o shiny dex da semente e toca em "Caçadas".
Future<void> _openHunts(WidgetTester tester) async {
  await _go(tester, Routes.dex(1));
  await tester.tap(find.byTooltip('Caçadas'));
  await tester.pumpAndSettle();
}

Finder _chip(String label) => find.widgetWithText(FilterChip, label);

/// Abre o menu "Motivos" e toca no motivo [label]; se o menu continuar
/// aberto (os motivos simples não o fecham), fecha tocando no chip.
Future<void> _tapReason(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Motivos'));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(CheckboxMenuButton),
      matching: find.textContaining(label),
    ),
  );
  await tester.pumpAndSettle();
  if (find.byType(CheckboxMenuButton).evaluate().isNotEmpty) {
    await tester.tap(find.byTooltip('Motivos'));
    await tester.pumpAndSettle();
  }
}

/// Escolhe a situação [label] no menu "Situação".
Future<void> _pickSituation(
  WidgetTester tester,
  String chip,
  String label,
) async {
  await tester.tap(_chip(chip));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(RadioMenuButton<HuntSituation>),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [compactSize, expandedSize]) {
    final px = '${size.width.toInt()}px';

    testWidgets('lista o que falta e leva ao slot ($px)', (tester) async {
      await pumpFullApp(tester, size: size);
      await _openHunts(tester);

      // Semente: 19 formas sem espécime no shiny dex.
      expect(find.text('19 para caçar'), findsOneWidget);
      expect(find.text('Venusaur'), findsOneWidget);
      // Nº da dex, posição na box e motivo.
      expect(find.text('#0003 · HOME 1 · L1 C3 · Faltando'), findsOneWidget);

      await tester.tap(find.text('Venusaur'));
      await tester.pumpAndSettle();
      // O dex abre na box, com o painel do slot (sheet no compacto).
      expect(find.text('HOME 1 · linha 1, coluna 3'), findsOneWidget);
      if (size == compactSize) {
        expect(find.byType(BottomSheet), findsOneWidget);
        await tester.tapAt(const Offset(200, 20));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('19 para caçar'), findsOneWidget);
    });

    testWidgets('filtros de escopo na folha ($px)', (tester) async {
      await pumpFullApp(tester, size: size);
      await _openHunts(tester);

      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(_chip('Lendário'));
      await tester.tap(_chip('I'));
      await tester.tap(_chip('Fogo'));
      await tester.tap(find.text('Incluir shiny impossível'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mostrar resultados'));
      await tester.pumpAndSettle();

      // A semente não tem lendários.
      expect(find.text('Nada para caçar com estes filtros.'), findsOneWidget);
      for (final label in [
        'Lendário',
        'Geração I',
        'Fogo',
        'Com shiny impossível',
      ]) {
        expect(find.widgetWithText(InputChip, label), findsOneWidget);
      }
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(InputChip, 'Lendário'),
          matching: find.byTooltip('Remover filtro'),
        ),
      );
      await tester.pumpAndSettle();
      // Sobrou fogo, gen I: Charizard (forma 6) está vazio.
      expect(find.text('1 para caçar'), findsOneWidget);
      expect(find.text('Charizard'), findsOneWidget);

      // "Limpar" zera o escopo; fechar sem aplicar não muda nada.
      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limpar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mostrar resultados'));
      await tester.pumpAndSettle();
      expect(find.text('19 para caçar'), findsOneWidget);
      expect(find.byType(InputChip), findsNothing);
      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(_chip('Mítico'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('19 para caçar'), findsOneWidget);
    });
  }

  testWidgets('motivos: GO, pokébola e o último não sai', (tester) async {
    await pumpFullApp(tester, size: compactSize);
    await _openHunts(tester);

    await _tapReason(tester, 'Shiny do GO');
    expect(find.text('25 para caçar'), findsOneWidget);
    expect(_chip('Sem shiny +1'), findsOneWidget);
    await _tapReason(tester, 'Sem shiny');
    expect(find.text('6 para caçar'), findsOneWidget);
    expect(_chip('Shiny do GO'), findsOneWidget);
    // O GO aparece como a marca de origem no título, como no inventário.
    expect(
      find.descendant(of: find.byType(HuntTile), matching: find.byType(GoIcon)),
      findsWidgets,
    );
    // Único motivo marcado: não dá para desmarcar.
    await _tapReason(tester, 'Shiny do GO');
    expect(find.text('6 para caçar'), findsOneWidget);

    // Pokébola: cancelar ou não escolher nenhuma não liga o motivo.
    await _tapReason(tester, 'Pokébola fora das escolhidas');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await _tapReason(tester, 'Pokébola fora das escolhidas');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('6 para caçar'), findsOneWidget);

    await _tapReason(tester, 'Pokébola fora das escolhidas');
    await tester.tap(find.text('Poké Ball'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    // GO (6) + shinies em Dream Ball (20), com 3 nos dois.
    expect(find.text('23 para caçar'), findsOneWidget);
    expect(find.textContaining('Outra pokébola'), findsWidgets);
    await tester.tap(find.byTooltip('Motivos'));
    await tester.pumpAndSettle();
    expect(find.text('Pokébola fora de: Poké Ball'), findsOneWidget);
    await tester.tap(find.byTooltip('Motivos'));
    await tester.pumpAndSettle();

    await _tapReason(tester, 'Shiny do GO');
    expect(find.text('20 para caçar'), findsOneWidget);
    // Agora a pokébola é o único motivo: não sai.
    await _tapReason(tester, 'Pokébola fora de');
    expect(find.text('20 para caçar'), findsOneWidget);
    await _tapReason(tester, 'Sem shiny');
    await _tapReason(tester, 'Pokébola fora de');
    expect(find.text('19 para caçar'), findsOneWidget);
  });

  for (final size in [compactSize, expandedSize]) {
    testWidgets('situação: faltando e registrados (${size.width.toInt()}px)', (
      tester,
    ) async {
      await pumpFullApp(tester, size: size);
      await _openHunts(tester);
      await _tapReason(tester, 'Shiny do GO');
      expect(find.text('25 para caçar'), findsOneWidget);

      // Os 19 slots vazios e os 6 shinies do GO já registrados.
      await _pickSituation(tester, 'Situação', 'Faltando');
      expect(find.text('19 para caçar'), findsOneWidget);
      await _pickSituation(tester, 'Faltando', 'Registrados');
      expect(find.text('6 para caçar'), findsOneWidget);
      await _pickSituation(tester, 'Registrados', 'Todos');
      expect(find.text('25 para caçar'), findsOneWidget);
      expect(_chip('Situação'), findsOneWidget);
    });
  }

  testWidgets('busca espera parar de digitar', (tester) async {
    await pumpFullApp(tester, size: compactSize);
    await _openHunts(tester);

    await tester.enterText(find.byType(TextField), 'venu');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('19 para caçar'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('1 para caçar'), findsOneWidget);
  });

  testWidgets('shiny lock com cadeado; dex normal sem "Caçadas"', (
    tester,
  ) async {
    final fake = FakeBackend()
      ..addForm(id: 1, name: 'keldeo', shinyLock: ShinyLockType.distroOnly);
    final dex = fake.addDex(name: 'Shiny', isShinyDex: true);
    final normal = fake.addDex(name: 'Normal');
    fake
      ..addBox(dexId: dex, name: 'HOME 1', formIds: [1])
      ..addBox(dexId: normal, name: 'HOME 2', formIds: [1]);
    await pumpFullApp(tester, size: compactSize, backend: fake);

    await _go(tester, Routes.dex(normal));
    expect(find.byTooltip('Caçadas'), findsNothing);
    await _go(tester, Routes.dex(dex));
    await tester.tap(find.byTooltip('Caçadas'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byTooltip('Só por distribuição'), findsOneWidget);
  });

  group('lista (repositório simulado)', () {
    late MockPersonalDexRepository repository;

    setUpAll(() => registerFallbackValue(const HuntQuery()));
    setUp(() => repository = MockPersonalDexRepository());

    Hunt hunt(int id, {List<HuntReason>? reasons, bool free = false}) =>
        Hunt.parse({
          ...missingSlotJson,
          if (free) 'form': null,
          'id': id,
          'reasons': [
            for (final r in reasons ?? const [HuntReason.noShiny]) r.param,
          ],
          'shiny_lock': null,
        });

    void answer(int page, Future<Paginated<Hunt>> Function() result) => when(
      () => repository.fetchHunts(
        any(),
        any(),
        page: page,
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) => result());

    Future<void> pump(WidgetTester tester) => pumpWidgetApp(
      tester,
      const HuntsPage(dexId: 1),
      overrides: [
        personalDexRepositoryProvider.overrideWithValue(repository),
        specimenOptionsProvider.overrideWith((ref) => const SpecimenOptions()),
      ],
    );

    testWidgets('item no estilo do inventário: espécime com apelido', (
      tester,
    ) async {
      answer(
        1,
        () async => Paginated(
          count: 1,
          results: [
            Hunt.parse({
              ...missingSlotJson,
              'specimen': {
                'id': 5,
                'nickname': 'Vovó',
                'form_name': 'rattata-alola',
                'is_shiny': true,
                'is_alpha': true,
                'is_from_go': true,
                'gender': 'female',
                'pokeball': 'dream-ball',
                'pokeball_sprite_url': 'http://x/dream-ball.png',
              },
              'reasons': ['from_go', 'pokeball'],
              'shiny_lock': null,
            }),
          ],
        ),
      );
      await pump(tester);
      await tester.pumpAndSettle();

      Finder inTile(Finder finder) =>
          find.descendant(of: find.byType(HuntTile), matching: finder);
      expect(inTile(find.text('Vovó')), findsOneWidget);
      expect(inTile(find.text(femaleEmoji)), findsOneWidget);
      for (final icon in [ShinyIcon, AlphaIcon, GoIcon]) {
        expect(inTile(find.byType(icon)), findsOneWidget);
      }
      expect(
        inTile(
          find.byWidgetPredicate(
            (w) =>
                w is PokemonSprite &&
                w.url == 'http://x/dream-ball.png' &&
                w.semanticLabel == 'Dream Ball',
          ),
        ),
        findsOneWidget,
      );
      // Com apelido, a espécie vai para a linha de baixo; "Do GO" não
      // repete o emoji do título.
      expect(
        inTile(
          find.text('Rattata Alola · #10193 · HOME 1 · L4 C2 · Outra pokébola'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('erro na 1ª página tem "Tentar novamente"', (tester) async {
      var fail = true;
      answer(1, () async {
        if (fail) throw const ServerFailure();
        return Paginated(count: 1, results: [hunt(1)]);
      });
      await pump(tester);
      await tester.pumpAndSettle();
      expect(find.text('Tentar novamente'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text('1 para caçar'), findsOneWidget);
    });

    testWidgets('páginas seguintes: carregando, erro, encolheu e refresh', (
      tester,
    ) async {
      // A 1ª página promete 22 itens, mas a 2ª chega com só 1.
      answer(
        1,
        () async => Paginated(
          count: 22,
          next: 'page=2',
          results: [
            for (var i = 0; i < huntPageSize; i++)
              hunt(
                i + 1,
                reasons: i == 0 ? const [HuntReason.pokeball] : null,
                free: i == 1,
              ),
          ],
        ),
      );
      final second = Completer<Paginated<Hunt>>();
      var secondCalls = 0;
      answer(2, () {
        secondCalls++;
        return secondCalls == 1
            ? second.future
            : Future.value(Paginated(count: 22, results: [hunt(99)]));
      });
      await pump(tester);
      await tester.pumpAndSettle();
      // Motivo pokébola sem espécime e slot sem forma.
      expect(find.textContaining('Outra pokébola'), findsWidgets);

      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsWidgets);
      second.completeError(const ServerFailure());
      await tester.pumpAndSettle();
      expect(
        find.text('Não foi possível carregar mais caçadas.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('hunt-99')), findsOneWidget);

      await tester.fling(find.byType(ListView), const Offset(0, 3000), 3000);
      await tester.pumpAndSettle();
      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      verify(
        () => repository.fetchHunts(
          any(),
          any(),
          page: 1,
          pageSize: any(named: 'pageSize'),
        ),
      ).called(greaterThan(1));
    });
  });
}
