import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/network/paginated.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/widgets/mark_icons.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/personal_dex/data/last_dex_storage.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/hunts_page.dart';
import 'package:ishinydex/features/shiny_hunts/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/presentation/hunt_lists.dart';
import 'package:ishinydex/features/specimens/domain/home_cutoff.dart';
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

/// Abre a aba Caçadas no shiny dex da semente.
Future<void> _openHunts(WidgetTester tester) =>
    _go(tester, Routes.hunts(dexId: 1));

/// O chip pelo texto; com valores marcados, ele só mostra os ícones e se
/// acha pelo tooltip (#219).
Finder _chip(String label) {
  final byText = find.widgetWithText(FilterChip, label);
  return byText.evaluate().isEmpty ? find.byTooltip(label) : byText;
}

/// O chip Motivos: o tooltip diz os motivos marcados.
final Finder _motivos = find.byWidgetPredicate(
  (w) => w is Tooltip && (w.message ?? '').startsWith('Motivos'),
);

/// Abre o menu "Motivos" e toca no motivo [label]; se o menu continuar
/// aberto (os motivos simples não o fecham), fecha tocando no chip.
Future<void> _tapReason(WidgetTester tester, String label) async {
  await tester.tap(_motivos);
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(CheckboxMenuButton),
      matching: find.textContaining(label),
    ),
  );
  await tester.pumpAndSettle();
  if (find.byType(CheckboxMenuButton).evaluate().isNotEmpty) {
    await tester.tap(_motivos);
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

    testWidgets('em inglês: abas, contagem e filtros ($px)', (tester) async {
      await pumpFullApp(tester, size: size, language: AppLanguage.en);
      await _go(tester, Routes.hunts(dexId: 1));
      expect(find.text('Hunts'), findsWidgets);
      expect(find.text('19 to hunt'), findsOneWidget);
      // Agrupado por box (#282), com o cabeçalho de cada uma.
      expect(find.text('Open box'), findsWidgets);
      expect(huntsTab('Active', '0'), findsOneWidget);
      // A aba com o mesmo total da lista (#277).
      expect(huntsTab('Missing', '19'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
      expect(find.text('Include unobtainable shiny'), findsOneWidget);
      expect(find.text('Show results'), findsOneWidget);
    });

    testWidgets('lista o que falta e leva ao slot ($px)', (tester) async {
      await pumpFullApp(tester, size: size);
      await _openHunts(tester);

      // Semente: 19 formas sem espécime no shiny dex.
      expect(find.text('19 para caçar'), findsOneWidget);
      expect(huntsTab('Faltam', '19'), findsOneWidget);
      expect(find.text('Venusaur'), findsOneWidget);
      // Sem subtítulo (#282): o nº da dex, a posição e "Faltando" saíram; a
      // box vai para o cabeçalho.
      expect(find.textContaining('#0003'), findsNothing);
      expect(find.byType(HuntBoxHeader), findsWidgets);

      await tester.tap(find.text('Venusaur'));
      await tester.pumpAndSettle();
      // O dex abre na box, com o painel do slot (sheet no compacto).
      expect(find.text('HOME 1 · L1 C3 · 3 de 30'), findsOneWidget);
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
    // O número da aba acompanha os filtros (#277).
    expect(huntsTab('Faltam', '25'), findsOneWidget);
    expect(_chip('Motivos: sem shiny e shiny do GO'), findsOneWidget);
    await _tapReason(tester, 'Sem shiny');
    expect(find.text('6 para caçar'), findsOneWidget);
    expect(_chip('Motivos: shiny do GO'), findsOneWidget);
    // "Do GO" não vira ícone: o item mostra a forma, não o espécime (#282).
    expect(
      find.descendant(of: find.byType(HuntTile), matching: find.byType(GoIcon)),
      findsNothing,
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
    expect(find.byTooltip('Outra pokébola'), findsWidgets);
    await tester.tap(_motivos);
    await tester.pumpAndSettle();
    expect(find.text('Pokébola fora de: Poké Ball'), findsOneWidget);
    await tester.tap(_motivos);
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
      await _pickSituation(tester, 'Situação: Faltando', 'Registrados');
      expect(find.text('6 para caçar'), findsOneWidget);
      await _pickSituation(tester, 'Situação: Registrados', 'Todos');
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

    // Enter: busca na hora, sem esperar (#202).
    await tester.enterText(find.byType(TextField), '');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump();
    expect(find.text('19 para caçar'), findsOneWidget);
  });

  testWidgets('shiny lock com cadeado; um dex normal não vale no Faltam', (
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

    // Pedido um dex normal, o Faltam usa o shiny dex.
    await _go(tester, Routes.hunts(dexId: normal));
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byTooltip('Só por distribuição'), findsOneWidget);
  });

  group('lista (repositório simulado)', () {
    late MockPersonalDexRepository repository;

    setUpAll(() => registerFallbackValue(const HuntQuery()));
    setUp(() {
      repository = MockPersonalDexRepository();
      // O Faltam só abre num shiny dex (#246).
      when(repository.fetchDexes).thenAnswer(
        (_) async => const [
          PersonalDex(
            id: 1,
            name: 'Shiny',
            total: 1,
            registered: 0,
            isShinyDex: true,
          ),
        ],
      );
    });

    Hunt hunt(
      int id, {
      List<HuntReason>? reasons,
      bool free = false,
      bool registered = false,
    }) => Hunt.parse({
      ...registered ? registeredSlotJson : missingSlotJson,
      if (free) 'form': null,
      'id': id,
      'reasons': [
        for (final r in reasons ?? const [HuntReason.noShiny]) r.param,
      ],
      'shiny_lock': null,
    });

    /// A página [page]; a 1ª também dá a box única, com o total dela.
    void answer(int page, Future<Paginated<Hunt>> Function() result) {
      when(
        () => repository.fetchHunts(
          any(),
          any(),
          page: page,
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) => result());
      if (page == 1) {
        when(() => repository.fetchHuntBoxes(any(), any())).thenAnswer(
          (_) async => [
            (
              box: const BoxRef(id: 1, name: 'HOME 1', position: 1),
              count: (await result()).count,
              cells: List.filled(30, HuntCell.listed),
            ),
          ],
        );
      }
    }

    Future<void> pump(WidgetTester tester, {FakeBackend? hunts}) =>
        pumpWidgetApp(
          tester,
          const HuntsPage(dexId: 1),
          hunts: hunts,
          overrides: [
            personalDexRepositoryProvider.overrideWithValue(repository),
            lastDexStorageProvider.overrideWithValue(InMemoryLastDexStorage()),
            specimenOptionsProvider.overrideWith(
              (ref) => const SpecimenOptions(),
            ),
          ],
        );

    testWidgets('abas e caçada por item: começar leva a Ativas; o selo', (
      tester,
    ) async {
      answer(1, () async => Paginated(count: 1, results: [hunt(20)]));
      final backend = FakeBackend.seeded()
        ..addForm(id: 1218, name: 'rattata-alola');
      await pump(tester, hunts: backend);
      await tester.pumpAndSettle();
      expect(huntsTab('Ativas', '0'), findsOne);
      // Desistir na folha: fica em Faltam.
      await tester.tap(find.byTooltip('Começar caçada'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(HuntCards), findsNothing);
      await tester.tap(find.byTooltip('Começar caçada'));
      await tester.pumpAndSettle();
      expect(find.text('Começar caçada'), findsWidgets);
      await tester.tap(find.text('Começar'));
      await tester.pumpAndSettle();
      // Começou: vai para Ativas.
      expect(huntsTab('Ativas', '1'), findsOne);
      expect(find.byType(HuntCards), findsOne);
      expect(find.byType(StartHuntButton), findsOne);
      await tester.tap(huntsTab('Pausadas', '0'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nenhuma caçada pausada'), findsOne);
      await tester.tap(huntsTab('Faltam', '1'));
      await tester.pumpAndSettle();
      // O selo no lugar do botão leva a Ativas.
      expect(find.byKey(const ValueKey('hunt-badge')), findsOne);
      await tester.tap(find.byTooltip('Caçada em andamento'));
      await tester.pumpAndSettle();
      expect(find.byType(HuntCards), findsOne);

      // Um cronômetro rodando: começar fica desabilitado em Faltam.
      final created = (await backend.fetchShinyHunts()).single;
      await backend.saveShinyHunt(created.copyWith(paused: true));
      await backend.saveShinyHunt(
        ShinyHunt(id: 0, form: 2, runningSince: DateTime(2026)),
      );
      await tester.pumpWidget(const SizedBox());
      await pump(tester, hunts: backend);
      await tester.pumpAndSettle();
      // Com caçada em andamento, a tela abre em Ativas (#279).
      expect(find.byType(HuntCards), findsOne);
      await tester.tap(find.text('Faltam'));
      await tester.pumpAndSettle();
      final start = find.widgetWithIcon(IconButton, Icons.track_changes);
      expect(tester.widget<IconButton>(start).onPressed, isNull);
    });

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
      // O item é da forma (#282): sem apelido, pokébola, gênero nem marcas.
      expect(inTile(find.text('Rattata Alola')), findsOneWidget);
      expect(inTile(find.text('Vovó')), findsNothing);
      for (final icon in [ShinyIcon, AlphaIcon, GoIcon]) {
        expect(inTile(find.byType(icon)), findsNothing);
      }
      // Os motivos fora do padrão viram ícone; o GO, não.
      expect(inTile(find.byTooltip('Outra pokébola')), findsOneWidget);
      expect(inTile(find.textContaining('#10193')), findsNothing);
    });

    testWidgets('Faltam: etiqueta do HOME só quando todos os jogos têm corte', (
      tester,
    ) async {
      const ash = Trainer(id: 9, name: 'Ash', trainerId: '1', version: 'x');
      const red = Trainer(
        id: 8,
        name: 'Red',
        trainerId: '2',
        version: 'scarlet',
      );
      answer(
        1,
        () async => Paginated(
          count: 2,
          results: [
            hunt(20).copyWith(versions: ['x', 'y']),
            hunt(21).copyWith(versions: ['x', 'scarlet']),
          ],
        ),
      );
      await pumpWidgetApp(
        tester,
        const HuntsPage(dexId: 1),
        overrides: [
          personalDexRepositoryProvider.overrideWithValue(repository),
          lastDexStorageProvider.overrideWithValue(InMemoryLastDexStorage()),
          specimenOptionsProvider.overrideWith(
            (ref) => const SpecimenOptions(),
          ),
          savesProvider.overrideWith(
            (ref) async => const [
              Save(id: 1, trainer: ash),
              Save(id: 2, trainer: red),
              Save(
                id: 3,
                trainer: Trainer(
                  id: 7,
                  name: 'Ash',
                  trainerId: '3',
                  version: 'y',
                ),
              ),
            ],
          ),
          homeCutoffProvider.overrideWithValue(
            (version) => version == 'x' || version == 'y'
                ? HomeCutoff(
                    until: version == 'x'
                        ? DateTime.utc(2027, 2, 26, 3)
                        : DateTime.utc(2027, 2, 27, 3),
                    now: DateTime(2027, 3),
                  )
                : null,
          ),
        ],
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('hunt-20')),
          matching: find.byKey(const ValueKey('home-tag')),
        ),
        findsOne,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('hunt-21')),
          matching: find.byKey(const ValueKey('home-tag')),
        ),
        findsNothing,
      );
    });

    testWidgets('erro na 1ª página tem "Tentar novamente"', (tester) async {
      var fail = true;
      answer(1, () async {
        if (fail) throw const DataFailure(Problem.invalidData());
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

    testWidgets('erro nas boxes tem "Tentar novamente"', (tester) async {
      answer(1, () async => Paginated(count: 1, results: [hunt(1)]));
      var fail = true;
      when(() => repository.fetchHuntBoxes(any(), any())).thenAnswer((_) async {
        if (fail) throw const DataFailure(Problem.invalidData());
        return [
          (
            box: const BoxRef(id: 1, name: 'HOME 1', position: 1),
            count: 1,
            cells: List.filled(30, HuntCell.listed),
          ),
        ];
      });
      await pump(tester);
      await tester.pumpAndSettle();
      expect(find.text('1 para caçar'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.byType(HuntTile), findsOneWidget);
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
                registered: i == 2,
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
      expect(find.byTooltip('Outra pokébola'), findsWidgets);
      // Com espécime, o "sem shiny" diz que ele não é shiny.
      expect(find.byTooltip('Não shiny'), findsOneWidget);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsWidgets);
      second.completeError(const DataFailure(Problem.invalidData()));
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

      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 3000),
        3000,
      );
      await tester.pumpAndSettle();
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 400),
        1000,
      );
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
