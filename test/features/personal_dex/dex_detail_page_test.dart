import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/network/paginated.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/widgets/mark_icons.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/personal_dex/data/last_dex_storage.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/domain/personal_dex_repository.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/dex_detail_page.dart';
import 'package:ishinydex/features/personal_dex/presentation/hunts_page.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/base_stats_chart.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/box_grid.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/box_list_panel.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/slot_detail_panel.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/slot_navigation.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/slot_search.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/slot_tile.dart';
import 'package:ishinydex/features/shiny_hunts/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/presentation/hunt_lists.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_form_page.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';
import '../../helpers/mocks.dart';

/// Repositório que delega ao fake, mas pode falhar sob demanda.
class _FlakyRepository implements PersonalDexRepository {
  _FlakyRepository(this.inner);

  final FakeBackend inner;
  int dexFailures = 0;
  int boxFailures = 0;
  int slotFailures = 0;

  /// Quando definido, substitui as gerações do fake.
  List<GenerationProgress>? generations;

  /// Quando definidas, editar/apagar o dex falham com elas.
  AppFailure? updateFailure;
  AppFailure? deleteFailure;

  /// Quando definidas, retirar, depositar (o "Desfazer") e o depósito
  /// automático falham com elas.
  AppFailure? withdrawFailure;
  AppFailure? depositFailure;
  AppFailure? linkFailure;

  @override
  Future<PersonalDex> updateDex(
    int dexId, {
    required String name,
    required bool isShinyDex,
  }) async {
    if (updateFailure case final failure?) throw failure;
    return await inner.updateDex(dexId, name: name, isShinyDex: isShinyDex);
  }

  @override
  Future<void> deleteDex(int dexId) async {
    if (deleteFailure case final failure?) throw failure;
    await inner.deleteDex(dexId);
  }

  @override
  Future<List<PersonalDex>> fetchDexes() => inner.fetchDexes();

  @override
  Future<PersonalDex> fetchDex(int dexId) async {
    if (dexFailures-- > 0) throw const NotFoundFailure();
    return await inner.fetchDex(dexId);
  }

  @override
  Future<List<BoxSummary>> fetchBoxes(int dexId) async {
    if (boxFailures-- > 0) throw const ServerFailure();
    return await inner.fetchBoxes(dexId);
  }

  @override
  Future<List<Slot>> fetchSlots({
    required int dexId,
    required int boxId,
  }) async {
    if (slotFailures-- > 0) throw const NetworkFailure();
    return await inner.fetchSlots(dexId: dexId, boxId: boxId);
  }

  @override
  Future<List<GenerationProgress>> fetchGenerations(int dexId) async =>
      generations ?? await inner.fetchGenerations(dexId);

  @override
  Future<Paginated<Hunt>> fetchHunts(
    int dexId,
    HuntQuery query, {
    required int page,
    required int pageSize,
  }) => inner.fetchHunts(dexId, query, page: page, pageSize: pageSize);

  @override
  Future<Slot> fetchSlot(int slotId) => inner.fetchSlot(slotId);

  @override
  Future<DexPreview> previewNewDex({required bool forceNewBox}) =>
      inner.previewNewDex(forceNewBox: forceNewBox);

  @override
  Future<PersonalDex> createDex({
    required String name,
    required bool isShinyDex,
    required bool forceNewBox,
  }) => inner.createDex(
    name: name,
    isShinyDex: isShinyDex,
    forceNewBox: forceNewBox,
  );

  @override
  Future<List<Slot>> searchSlots({
    required int dexId,
    required String search,
  }) => inner.searchSlots(dexId: dexId, search: search);

  @override
  Future<Slot> deposit({required int slotId, required int specimenId}) async {
    if (depositFailure case final failure?) throw failure;
    return await inner.deposit(slotId: slotId, specimenId: specimenId);
  }

  @override
  Future<Slot> withdraw(int slotId) async {
    if (withdrawFailure case final failure?) throw failure;
    return await inner.withdraw(slotId);
  }

  @override
  Future<List<Slot>> fetchSlotsByForms({
    required int dexId,
    required List<int> formIds,
  }) => inner.fetchSlotsByForms(dexId: dexId, formIds: formIds);

  @override
  Future<LinkResult> linkSpecimens(
    int dexId, {
    bool strict = false,
    bool dryRun = false,
  }) async {
    if (linkFailure case final failure?) throw failure;
    return await inner.linkSpecimens(dexId, strict: strict, dryRun: dryRun);
  }
}

Future<void> openShinyDex(WidgetTester tester) async {
  await tester.tap(find.text('Shiny Living Dex'));
  await tester.pumpAndSettle();
}

Finder slot(int id) => find.byKey(ValueKey('slot-$id'));

/// Progresso por geração fica no menu ⋮ da AppBar.
Future<void> openProgress(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Mais opções'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Progresso por geração'));
  await tester.pumpAndSettle();
}

/// Rola o formulário do specimen até o fim (onde fica o "Salvar") e salva.
Future<void> saveSpecimenForm(WidgetTester tester) async {
  // Um campo de texto focado rolaria a lista de volta para mostrar o cursor.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.drag(
    find.descendant(
      of: find.byType(SpecimenForm),
      matching: find.byType(ListView),
    ),
    const Offset(0, -2000),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Salvar'));
  await tester.pumpAndSettle();
}

void main() {
  group('layout expandido', () {
    testWidgets('lista de boxes, seleção e detalhe (tela larga)', (
      tester,
    ) async {
      await pumpFullApp(tester, size: largeSize);
      await openShinyDex(tester);
      expect(
        find.text('Selecione um slot para ver os detalhes.'),
        findsOneWidget,
      );
      expect(find.text('HOME 2'), findsOneWidget);
      expect(find.byType(SlotTile), findsNWidgets(30));

      await tester.tap(slot(1));
      await tester.pumpAndSettle();
      expect(find.text('Registrado'), findsOneWidget);
      // Selo 💢 nos alfas da box (formas 1, 11, 16 e 26) + o do cabeçalho
      // do detalhe (sem chips de Shiny, Alfa ou pokébola).
      expect(find.byType(AlphaIcon), findsNWidgets(5));
      expect(find.text('Alfa'), findsNothing);
      expect(ballSprite('Poke Ball'), findsOneWidget);
      expect(find.text('Editar espécime'), findsOneWidget);
      // Detalhes da forma (tipos e habilidades do fake).
      expect(find.text('Normal'), findsOneWidget);
      expect(
        find.text('Habilidades: Run Away · Keen Eye (oculta)'),
        findsOneWidget,
      );
      // As ações secundárias ficam em "Mais ações".
      expect(find.byTooltip('Mais ações'), findsOneWidget);
      expect(find.text('Depositar'), findsNothing);

      await tester.tap(find.text('HOME 2'));
      await tester.pumpAndSettle();
      expect(find.text('HOME 2 · 19/28'), findsOneWidget);
      expect(
        find.text('Selecione um slot para ver os detalhes.'),
        findsOneWidget,
      );
      // Fim da geração: a box continua com 30 células, 2 delas vazias.
      expect(find.byType(SlotTile), findsNWidgets(28));
      expect(find.byType(EmptySlotTile), findsNWidgets(2));
    });

    testWidgets('lista de boxes recolhível', (tester) async {
      await pumpFullApp(tester);
      await openShinyDex(tester);
      // Em 1400px a lista começa oculta; a grade usa a largura.
      expect(find.byType(BoxListPanel), findsNothing);
      // Célula maior que o antigo limite de 120px.
      expect(
        tester.getSize(find.byType(SlotTile).first).width,
        greaterThan(120),
      );
      await tester.tap(find.byTooltip('Mostrar lista de boxes'));
      await tester.pumpAndSettle();
      expect(find.byType(BoxListPanel), findsOneWidget);
      await tester.tap(find.byTooltip('Ocultar lista de boxes'));
      await tester.pumpAndSettle();
      expect(find.byType(BoxListPanel), findsNothing);
    });

    testWidgets('libertar exige confirmação e deixa o slot faltante', (
      tester,
    ) async {
      final backend = await pumpFullApp(tester);
      await openShinyDex(tester);
      await tester.tap(slot(1));
      await tester.pumpAndSettle();
      // Ação destrutiva: na folha "Mais ações", por último, na cor de erro.
      await tester.tap(find.byTooltip('Mais ações'));
      await tester.pumpAndSettle();
      final release = find.widgetWithText(ListTile, 'Libertar');
      expect(
        tester
            .widget<Text>(
              find.descendant(of: release, matching: find.text('Libertar')),
            )
            .style
            ?.color,
        Theme.of(tester.element(release)).colorScheme.error,
      );

      await tester.tap(release);
      await tester.pumpAndSettle();
      expect(find.text('Libertar Bulbasaur?'), findsOneWidget);
      expect(find.textContaining('não pode ser desfeita'), findsOneWidget);
      // Cancelar não faz nada.
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Registrado'), findsOneWidget);

      await tapMoreAction(tester, 'Libertar');
      await tester.tap(find.widgetWithText(TextButton, 'Libertar'));
      await tester.pumpAndSettle();
      expect(find.text('Espécime libertado.'), findsOneWidget);
      expect(find.text('Faltante'), findsOneWidget);
      expect(find.text('HOME 1 · 19/30'), findsOneWidget);
      // O cadastro foi apagado, não só desvinculado.
      expect(await backend.fetchAvailable(1), isEmpty);
    });

    testWidgets('painel do slot destaca a habilidade do espécime', (
      tester,
    ) async {
      final backend = FakeBackend.seeded();
      final specimen = await backend.fetchSpecimen(1);
      await backend.update(
        1,
        SpecimenDraft.fromSpecimen(specimen).copyWith(ability: 'keen-eye'),
      );
      await pumpFullApp(tester, backend: backend);
      await openShinyDex(tester);
      await tester.tap(slot(1));
      await tester.pumpAndSettle();
      expect(
        find.text('Habilidades: Run Away · ✓ Keen Eye (oculta)'),
        findsOneWidget,
      );
    });

    testWidgets('editar espécime pelo formulário', (tester) async {
      await pumpFullApp(tester);
      await openShinyDex(tester);
      await tester.tap(slot(1));
      await tester.pumpAndSettle();

      // Voltar sem salvar não muda nada.
      await tester.tap(find.text('Editar espécime'));
      await tester.pumpAndSettle();
      expect(find.byType(SpecimenForm), findsOneWidget);
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.text('Espécime atualizado.'), findsNothing);

      await tester.tap(find.text('Editar espécime'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Bulba');
      await saveSpecimenForm(tester);
      expect(find.text('Espécime atualizado.'), findsOneWidget);
      expect(find.text('Bulba'), findsOneWidget);
    });

    testWidgets('depositar pelo diálogo', (tester) async {
      await pumpFullApp(tester);
      await openShinyDex(tester);
      await tester.tap(slot(3));
      await tester.pumpAndSettle();
      expect(find.text('Faltante'), findsOneWidget);
      await tester.tap(find.text('Depositar'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await tester.tap(find.text('Saur'));
      await tester.pumpAndSettle();
      // Saur não é shiny: pede confirmação.
      await tester.tap(find.widgetWithText(TextButton, 'Depositar'));
      await tester.pumpAndSettle();
      expect(find.text('Specimen depositado.'), findsOneWidget);
      expect(find.text('Registrado'), findsOneWidget);
    });

    testWidgets('filtro de faltantes e navegação por setas/menu', (
      tester,
    ) async {
      await pumpFullApp(tester);
      await openShinyDex(tester);
      await tester.tap(find.byTooltip('Destacar faltantes'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Mostrar todos'), findsOneWidget);

      await tester.tap(find.byTooltip('Próxima box'));
      await tester.pumpAndSettle();
      expect(find.text('HOME 2 · 19/28'), findsOneWidget);
      await tester.tap(find.byTooltip('Box anterior'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Escolher box'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('HOME 2 · 19/28').last);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('falha ao libertar mostra a mensagem', (tester) async {
      final specimens = MockSpecimenRepository();
      when(() => specimens.release(any()))
          .thenThrow(ValidationFailure(const {}, detail: 'Não pode.'));
      await pumpFullApp(
        tester,
        overrides: [specimenRepositoryProvider.overrideWithValue(specimens)],
      );
      await openShinyDex(tester);
      await tester.tap(slot(1));
      await tester.pumpAndSettle();
      await tapMoreAction(tester, 'Libertar');
      await tester.tap(find.widgetWithText(TextButton, 'Libertar'));
      await tester.pumpAndSettle();
      expect(find.text('Não pode.'), findsOneWidget);
      expect(find.text('Registrado'), findsOneWidget);
    });

    testWidgets('erros de boxes e slots com retry', (tester) async {
      final repository = _FlakyRepository(FakeBackend.seeded())
        ..boxFailures = 1
        ..slotFailures = 1;
      await pumpFullApp(
        tester,
        overrides: [
          personalDexRepositoryProvider.overrideWithValue(repository),
        ],
      );
      await openShinyDex(tester);
      expect(find.text(const ServerFailure().message), findsOneWidget);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text(const NetworkFailure().message), findsOneWidget);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.byType(SlotTile), findsNWidgets(30));
    });

    testWidgets('dex sem boxes', (tester) async {
      final backend = FakeBackend()..addDex(name: 'Vazio');
      await pumpFullApp(tester, backend: backend);
      await tester.tap(find.text('Vazio'));
      await tester.pumpAndSettle();
      expect(find.text('Este dex ainda não tem boxes.'), findsOneWidget);
    });

    testWidgets('erro ao carregar o dex com retry', (tester) async {
      final repository = _FlakyRepository(FakeBackend.seeded())
        ..dexFailures = 1;
      await pumpFullApp(
        tester,
        overrides: [
          personalDexRepositoryProvider.overrideWithValue(repository),
        ],
      );
      await openShinyDex(tester);
      expect(find.text(const NotFoundFailure().message), findsOneWidget);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.byType(SlotTile), findsNWidgets(30));
    });
  });

  group('troca de PersonalDex', () {
    for (final size in [compactSize, expandedSize]) {
      testWidgets('abre o último dex e troca pelo AppBar '
          '(${size.width.toInt()}px)', (tester) async {
        final lastDex = InMemoryLastDexStorage(2);
        await pumpFullApp(tester, size: size, lastDex: lastDex);
        // Entrou direto no último dex usado (o seed tem 1 espécime dele
        // num save: conta como registrado e aparece como "fora").
        expect(find.text('HOME 3 · 20/30 · 1 fora'), findsOneWidget);
        // Progresso do dex embaixo do nome, na AppBar.
        expect(find.text('20 de 30 registrados · 66%'), findsOneWidget);

        await tester.tap(find.byTooltip('Trocar PersonalDex'));
        await tester.pumpAndSettle();
        // O dex atual aparece marcado e desabilitado.
        final current = tester.widget<MenuItemButton>(
          find.byKey(const ValueKey('switch-dex-2')),
        );
        expect(current.onPressed, isNull);
        expect(find.text('39/58'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('switch-dex-1')));
        await tester.pumpAndSettle();
        expect(find.text('HOME 1 · 20/30'), findsOneWidget);
        expect(await lastDex.read(), 1);

        // Tocar de novo no título fecha o menu.
        await tester.tap(find.byTooltip('Trocar PersonalDex'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Trocar PersonalDex'));
        await tester.pumpAndSettle();
        expect(find.text('Ver todos'), findsNothing);

        await tester.tap(find.byTooltip('Trocar PersonalDex'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ver todos'));
        await tester.pumpAndSettle();
        expect(find.byType(GridView), findsOneWidget);
        expect(find.text('Living Dex'), findsOneWidget);
      });
    }
  });

  group('progresso por geração', () {
    /// Dex com as gerações I (HOME A) e II (HOME B).
    FakeBackend twoGenerations() {
      final backend = FakeBackend()
        ..addForm(id: 1, name: 'bulbasaur')
        ..addForm(id: 152, name: 'chikorita');
      final dex = backend.addDex(name: 'Dex');
      backend
        ..addBox(dexId: dex, name: 'HOME A', formIds: const [1])
        ..addBox(dexId: dex, name: 'HOME B', formIds: const [152]);
      return backend;
    }

    for (final size in [compactSize, expandedSize]) {
      testWidgets('tocar numa geração leva à primeira box dela '
          '(${size.width.toInt()}px)', (tester) async {
        await pumpFullApp(tester, size: size, backend: twoGenerations());
        await tester.tap(find.text('Dex'));
        await tester.pumpAndSettle();
        expect(find.text('HOME A · 0/1'), findsOneWidget);

        await openProgress(tester);
        expect(find.text('Geração I'), findsOneWidget);
        await tester.tap(find.text('Geração II'));
        await tester.pumpAndSettle();
        expect(find.text('HOME B · 0/1'), findsOneWidget);

        // Fechar sem escolher mantém a box.
        await openProgress(tester);
        await tester.tap(find.byType(CloseButton));
        await tester.pumpAndSettle();
        expect(find.text('HOME B · 0/1'), findsOneWidget);
      });
    }

    testWidgets('box que não está na lista é ignorada', (tester) async {
      final repository = _FlakyRepository(FakeBackend.seeded())
        ..generations = const [
          GenerationProgress(
            generation: 'generation-i',
            total: 1,
            registered: 0,
            firstBox: BoxRef(id: 999, name: 'Sumiu', position: 999),
          ),
        ];
      await pumpFullApp(
        tester,
        overrides: [
          personalDexRepositoryProvider.overrideWithValue(repository),
        ],
      );
      await openShinyDex(tester);
      await openProgress(tester);
      await tester.tap(find.text('Geração I'));
      await tester.pumpAndSettle();
      expect(find.text('HOME 1 · 20/30'), findsOneWidget);
    });
  });

  group('busca no dex', () {
    Finder searchField() => find.descendant(
      of: find.byType(SlotSearchPill),
      matching: find.byType(TextField),
    );

    Future<void> searchFor(WidgetTester tester, String text) async {
      await tester.tap(searchField());
      await tester.pumpAndSettle();
      await tester.enterText(searchField(), text);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }

    testWidgets('expandido: leva à box e seleciona o slot', (tester) async {
      await pumpFullApp(tester);
      await openShinyDex(tester);
      await searchFor(tester, 'wiggly');
      // Wigglytuff = forma 40, slot 40 (HOME 2, linha 2, coluna 4).
      expect(
        find.textContaining('#0040 · HOME 2 · linha 2, coluna 4 · '),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('search-slot-40')));
      await tester.pumpAndSettle();
      expect(find.text('HOME 2 · 19/28'), findsOneWidget);
      expect(find.text('Wigglytuff'), findsWidgets);
      // Escolher um resultado fecha a busca.
      expect(find.text('Cancelar'), findsNothing);
      expect(tester.widget<TextField>(searchField()).controller!.text, isEmpty);
    });

    testWidgets('compacto: por número, abre o detalhe no bottom sheet', (
      tester,
    ) async {
      await pumpFullApp(tester, size: compactSize);
      await openShinyDex(tester);
      await searchFor(tester, '40');
      await tester.tap(find.byKey(const ValueKey('search-slot-40')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('HOME 2 · 19/28'), findsOneWidget);
      // A seleção sobreviveu ao pulo de página.
      expect(find.text('HOME 2 · L2 C4 · 10 de 28'), findsOneWidget);
    });

    testWidgets('compacto: a pílula fica embaixo e sobe para o topo com o '
        'foco, recolhendo a AppBar', (tester) async {
      await pumpFullApp(tester, size: compactSize);
      await openShinyDex(tester);
      final pill = find.byType(SlotSearchPill);
      final restTop = tester.getTopLeft(pill).dy;
      // Logo abaixo da última linha da box, centralizada.
      final grid = tester.getRect(
        find
            .descendant(of: find.byType(BoxGrid), matching: find.byType(Column))
            .first,
      );
      expect(restTop - grid.bottom, moreOrLessEquals(16));
      expect(
        tester.getCenter(pill).dx,
        moreOrLessEquals(compactSize.width / 2),
      );
      expect(find.text('Buscar'), findsOneWidget);
      expect(find.byTooltip('Mais opções').hitTestable(), findsOneWidget);
      expect(
        find.byTooltip('Destacar faltantes').hitTestable(),
        findsOneWidget,
      );

      await tester.tap(searchField());
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(pill).dy, lessThan(100));
      expect(find.text('Nome ou número'), findsOneWidget);
      expect(find.byTooltip('Mais opções').hitTestable(), findsNothing);
      expect(find.byTooltip('Destacar faltantes').hitTestable(), findsNothing);
      expect(
        find.text('Digite o nome (2 letras ou mais) ou o número.'),
        findsOneWidget,
      );

      // O campo não é recriado ao subir: segue com o foco (e o teclado).
      expect(
        tester.widget<TextField>(searchField()).focusNode!.hasFocus,
        isTrue,
      );

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(pill).dy, restTop);
      expect(find.byTooltip('Mais opções').hitTestable(), findsOneWidget);
      expect(find.text('Cancelar'), findsNothing);
    });

    testWidgets('expandido: a pílula fica abaixo da grade e, ativa, vira uma '
        'barra com largura limitada', (tester) async {
      await pumpFullApp(tester);
      await openShinyDex(tester);
      final pill = find.byType(SlotSearchPill);
      final grid = tester.getRect(
        find
            .descendant(of: find.byType(BoxGrid), matching: find.byType(Column))
            .first,
      );
      // Centralizada na coluna da grade (o detalhe do slot fica ao lado).
      expect(tester.getTopLeft(pill).dy - grid.bottom, moreOrLessEquals(16));
      expect(tester.getCenter(pill).dx, moreOrLessEquals(grid.center.dx));

      await tester.tap(searchField());
      await tester.pumpAndSettle();
      expect(find.byTooltip('Mais opções').hitTestable(), findsNothing);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(tester.getSize(pill).width, 560);
      expect(tester.getTopLeft(pill).dy, lessThan(100));
    });

    for (final size in [compactSize, expandedSize]) {
      testWidgets('"Buscar" no teclado abre o resultado destacado '
          '(${size.width.toInt()}px)', (tester) async {
        await pumpFullApp(tester, size: size);
        await openShinyDex(tester);
        await searchFor(tester, 'wiggly');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        // Como tocar no resultado: a busca fecha e a grade vai até o slot.
        expect(find.text('Cancelar'), findsNothing);
        expect(find.text('HOME 2 · 19/28'), findsOneWidget);
      });
    }

    testWidgets('Enter antes do debounce usa o texto do campo', (tester) async {
      await pumpFullApp(tester);
      await openShinyDex(tester);
      await tester.tap(searchField());
      await tester.pumpAndSettle();
      await tester.enterText(searchField(), 'wiggly');
      // Sem esperar os 350 ms: a lista ainda é do texto anterior.
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('Cancelar'), findsNothing);
      expect(find.text('HOME 2 · 19/28'), findsOneWidget);
    });

    testWidgets('Enter com texto curto ou sem resultado não abre nada', (
      tester,
    ) async {
      await pumpFullApp(tester, size: compactSize);
      await openShinyDex(tester);
      await searchFor(tester, 'w');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('Cancelar'), findsOneWidget);
      expect(
        find.text('Digite o nome (2 letras ou mais) ou o número.'),
        findsOneWidget,
      );

      await tester.tap(searchField());
      await tester.pumpAndSettle();
      await tester.enterText(searchField(), 'zzz');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma forma deste dex encontrada.'), findsOneWidget);
      // Digitar de novo cancela o "abrir quando chegar".
      await tester.tap(searchField());
      await tester.pumpAndSettle();
      await searchFor(tester, 'wiggly');
      expect(find.byKey(const ValueKey('search-slot-40')), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('celular: o primeiro resultado vem destacado, com a '
        'etiqueta "Buscar abre"', (tester) async {
      await pumpFullApp(tester, size: compactSize);
      await openShinyDex(tester);
      await searchFor(tester, 'pidge');
      final tiles = tester
          .widgetList<ListTile>(
            find.descendant(
              of: find.byType(SlotSearchResults),
              matching: find.byType(ListTile),
            ),
          )
          .toList();
      expect(tiles.map((t) => t.selected), [true, false, false]);
      expect(find.text('Buscar abre'), findsOneWidget);
      expect(find.text('escolher'), findsNothing);
    });

    testWidgets(
      'PC: setas movem o destaque, Enter abre, Esc cancela e o mouse '
      'também destaca',
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
      (tester) async {
        await pumpFullApp(tester);
        await openShinyDex(tester);
        await searchFor(tester, 'pidge');
        List<bool> selected() => [
          for (final tile in tester.widgetList<ListTile>(
            find.descendant(
              of: find.byType(SlotSearchResults),
              matching: find.byType(ListTile),
            ),
          ))
            tile.selected,
        ];
        expect(selected(), [true, false, false]);
        expect(find.text('Buscar abre'), findsNothing);
        expect(find.text('escolher'), findsOneWidget);
        expect(find.text('Enter'), findsNWidgets(2)); // no item e na dica

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(selected(), [true, false, false]); // não passa do primeiro
        for (var i = 0; i < 3; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        }
        await tester.pump();
        expect(selected(), [false, false, true]); // nem do último
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(selected(), [false, true, false]);
        // O foco continua no campo.
        expect(
          tester.widget<TextField>(searchField()).focusNode!.hasFocus,
          isTrue,
        );

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);
        final pidgey = find.byKey(const ValueKey('search-slot-16'));
        await mouse.moveTo(tester.getCenter(pidgey));
        await tester.pump();
        expect(selected(), [true, false, false]);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();

        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(find.text('Cancelar'), findsNothing);
        expect(find.text('Pidgeotto'), findsWidgets);

        await searchFor(tester, 'pidge');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Cancelar'), findsNothing);
        expect(tester.widget<TextField>(searchField()).controller!.text, '');
        // Sem resultados (texto vazio), as setas não fazem nada.
        await tester.tap(searchField());
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
      },
    );

    testWidgets('o "x" apaga o texto e mantém a busca aberta', (tester) async {
      await pumpFullApp(tester, size: compactSize);
      await openShinyDex(tester);
      expect(find.byTooltip('Limpar busca'), findsNothing);
      await searchFor(tester, 'wiggly');
      expect(find.byKey(const ValueKey('search-slot-40')), findsOneWidget);

      await tester.tap(find.byTooltip('Limpar busca'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(searchField()).controller!.text, isEmpty);
      expect(find.byTooltip('Limpar busca'), findsNothing);
      expect(
        find.text('Digite o nome (2 letras ou mais) ou o número.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(searchField()).focusNode!.hasFocus,
        isTrue,
      );
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('cancelar sem escolher não muda nada', (tester) async {
      await pumpFullApp(tester);
      await openShinyDex(tester);
      await searchFor(tester, 'wiggly');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('search-slot-40')), findsNothing);
      expect(find.text('HOME 1 · 20/30'), findsOneWidget);
      expect(
        find.text('Selecione um slot para ver os detalhes.'),
        findsOneWidget,
      );
    });
  });

  group('link direto (?box=&slot=)', () {
    Future<void> go(WidgetTester tester, String location) async {
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
          .read(routerProvider)
          .go(location);
      await tester.pumpAndSettle();
    }

    for (final size in [compactSize, expandedSize]) {
      testWidgets('abre na box e seleciona o slot (${size.width.toInt()}px)', (
        tester,
      ) async {
        await pumpFullApp(tester, size: size);
        // Slot 40 = HOME 2, posição 10 (forma 40).
        await go(tester, Routes.dex(1, boxId: 2, slotId: 40));
        expect(find.text('HOME 2 · 19/28'), findsOneWidget);
        expect(find.text('Wigglytuff'), findsWidgets);
        // No compacto o detalhe já abre sozinho, no bottom sheet.
        expect(
          find.byType(BottomSheet),
          size == compactSize ? findsOneWidget : findsNothing,
        );
      });
    }

    testWidgets('o sheet abre uma vez só, mesmo reconstruindo', (tester) async {
      await pumpFullApp(tester, size: compactSize);
      await go(tester, Routes.dex(1, boxId: 2, slotId: 40));
      await tester.tapAt(const Offset(200, 20)); // fora do sheet: fecha
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.byTooltip('Destacar faltantes'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('box inexistente na URL cai na primeira', (tester) async {
      await pumpFullApp(tester);
      await go(tester, Routes.dex(1, boxId: 999));
      expect(find.text('HOME 1 · 20/30'), findsOneWidget);
    });
  });

  group('layout compacto', () {
    testWidgets('swipe entre boxes e detalhe em bottom sheet', (tester) async {
      await pumpFullApp(tester, size: compactSize);
      await openShinyDex(tester);
      expect(find.text('HOME 1 · 20/30'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('HOME 2 · 19/28'), findsOneWidget);
      await tester.tap(find.byTooltip('Box anterior'));
      await tester.pumpAndSettle();
      expect(find.text('HOME 1 · 20/30'), findsOneWidget);

      await tester.tap(slot(3));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tap(find.text('Depositar'));
      await tester.pumpAndSettle();
      // Seletor abre em bottom sheet no compacto.
      expect(find.text('Depositar Venusaur'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      await tester.tap(find.text('Saur'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Depositar'));
      await tester.pumpAndSettle();
      expect(find.text('Specimen depositado.'), findsOneWidget);
      // Espera o snackbar sumir.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Slot registrado: editar e libertar pelo bottom sheet.
      await tester.tap(slot(3));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar espécime'));
      await tester.pumpAndSettle();
      await saveSpecimenForm(tester);
      expect(find.text('Espécime atualizado.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.tap(slot(3));
      await tester.pumpAndSettle();
      await tapMoreAction(tester, 'Libertar');
      await tester.tap(find.widgetWithText(TextButton, 'Libertar'));
      await tester.pumpAndSettle();
      expect(find.text('Espécime libertado.'), findsOneWidget);
    });

    testWidgets('trocar de compacto para expandido', (tester) async {
      await pumpFullApp(tester, size: compactSize);
      await openShinyDex(tester);
      expect(find.byType(PageView), findsOneWidget);
      await setScreenSize(tester, mediumSize);
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsNothing);
      expect(
        find.text('Selecione um slot para ver os detalhes.'),
        findsOneWidget,
      );
      await setScreenSize(tester, compactSize);
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsOneWidget);
    });
  });

  group('editar e apagar dex', () {
    Future<void> openMenuItem(WidgetTester tester, String item) async {
      await tester.tap(find.byTooltip('Mais opções'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(item));
      await tester.pumpAndSettle();
    }

    Finder nameField() => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );

    Future<void> save(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();
    }

    for (final size in [compactSize, expandedSize]) {
      testWidgets('renomeia e troca shiny dex (${size.width.toInt()}px)', (
        tester,
      ) async {
        await pumpFullApp(tester, size: size);
        await openShinyDex(tester);
        expect(find.byTooltip('Caçadas'), findsOneWidget);

        // Cancelar não muda nada.
        await openMenuItem(tester, 'Editar dex');
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);

        await openMenuItem(tester, 'Editar dex');
        expect(find.text('Shiny Living Dex'), findsWidgets);
        await tester.enterText(nameField(), ' ');
        await save(tester);
        expect(find.text('Este campo não pode ser em branco.'), findsOneWidget);
        await tester.enterText(nameField(), 'Living Dex');
        await save(tester);
        expect(
          find.text('personal dex com este name já existe.'),
          findsOneWidget,
        );

        await tester.enterText(nameField(), ' Minha Dex ');
        await tester.tap(find.text('Dex shiny'));
        await tester.pump();
        // Enter no campo também salva.
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Dex atualizado.'), findsOneWidget);
        expect(find.text('Minha Dex'), findsOneWidget);
        // Sem shiny dex, sem caçadas.
        expect(find.byTooltip('Caçadas'), findsNothing);
      });

      testWidgets('apaga e volta para a lista (${size.width.toInt()}px)', (
        tester,
      ) async {
        final backend = await pumpFullApp(tester, size: size);
        await openShinyDex(tester);

        await openMenuItem(tester, 'Apagar dex');
        expect(find.text('Apagar Shiny Living Dex?'), findsOneWidget);
        expect(find.textContaining('continuam no inventário'), findsOneWidget);
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(find.byType(DexDetailPage), findsOneWidget);

        await openMenuItem(tester, 'Apagar dex');
        await tester.tap(find.widgetWithText(TextButton, 'Apagar'));
        await tester.pumpAndSettle();
        expect(find.text('Dex apagado.'), findsOneWidget);
        expect(find.byType(DexDetailPage), findsNothing);
        expect(find.text('Shiny Living Dex'), findsNothing);
        expect(find.text('Living Dex'), findsOneWidget);
        expect((await backend.fetchDexes()).map((d) => d.name), ['Living Dex']);
      });
    }

    testWidgets('falhas ao editar e apagar mostram a mensagem', (tester) async {
      final repository = _FlakyRepository(FakeBackend.seeded())
        ..updateFailure = const NetworkFailure()
        ..deleteFailure = const ServerFailure();
      await pumpFullApp(
        tester,
        overrides: [
          personalDexRepositoryProvider.overrideWithValue(repository),
        ],
      );
      await openShinyDex(tester);

      await openMenuItem(tester, 'Editar dex');
      await save(tester);
      expect(find.text(const NetworkFailure().message), findsOneWidget);
      // Erro de validação fora do nome também vai para o topo do diálogo.
      repository.updateFailure = ValidationFailure(const {
        ValidationFailure.nonFieldKey: ['Não pode.'],
      });
      await save(tester);
      expect(find.text('Não pode.'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      await openMenuItem(tester, 'Apagar dex');
      await tester.tap(find.widgetWithText(TextButton, 'Apagar'));
      await tester.pumpAndSettle();
      expect(find.text(const ServerFailure().message), findsOneWidget);
      expect(find.byType(DexDetailPage), findsOneWidget);
    });
  });

  group('abas do painel e linha evolutiva', () {
    for (final size in [compactSize, expandedSize]) {
      testWidgets('status no resumo, espécie e ir para a evolução '
          '(${size.width.toInt()}px)', (tester) async {
        await pumpFullApp(tester, size: size);
        await openShinyDex(tester);
        await tester.tap(slot(1));
        await tester.pumpAndSettle();

        // O hexágono fica no resumo, no cartão "Status base".
        expect(find.text('Status'), findsNothing);
        expect(find.text('Status base'), findsOneWidget);
        expect(find.byType(BaseStatsChart), findsOneWidget);
        expect(find.textContaining('Total '), findsOneWidget);

        await tester.tap(find.text('Espécie'));
        await tester.pumpAndSettle();
        expect(find.text('Linha evolutiva'), findsOneWidget);
        expect(find.text('Captura'), findsOneWidget);
        // A forma atual não navega; as outras levam ao slot delas.
        await tester.tap(find.byKey(const ValueKey('species-form-1')));
        await tester.pumpAndSettle();
        expect(find.text('HOME 1 · L1 C1 · 1 de 30'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('species-form-2')));
        await tester.pumpAndSettle();
        expect(find.text('HOME 1 · L1 C2 · 2 de 30'), findsOneWidget);
        // Outro slot: as abas voltam para o resumo.
        expect(find.text('Registrado'), findsOneWidget);
      });
    }
  });

  group('retirar do slot', () {
    for (final size in [compactSize, expandedSize]) {
      testWidgets('retira e desfaz (${size.width.toInt()}px)', (tester) async {
        final backend = await pumpFullApp(tester, size: size);
        await openShinyDex(tester);
        await tester.tap(slot(1));
        await tester.pumpAndSettle();
        final specimenId = (await backend.fetchSlot(1)).specimen!.id;

        await tapMoreAction(tester, 'Retirar do slot');
        expect(find.text('Bulbasaur retirado do slot.'), findsOneWidget);
        expect(find.text('HOME 1 · 19/30'), findsOneWidget);
        expect((await backend.fetchSlot(1)).specimen, isNull);
        // Continua cadastrado, disponível no inventário.
        expect((await backend.fetchSpecimen(specimenId)).slot, isNull);

        await tester.tap(find.text('Desfazer'));
        await tester.pumpAndSettle();
        expect(find.text('HOME 1 · 20/30'), findsOneWidget);
        expect((await backend.fetchSlot(1)).specimen!.id, specimenId);
      });
    }

    testWidgets('falhas ao retirar e ao desfazer', (tester) async {
      final repository = _FlakyRepository(FakeBackend.seeded())
        ..withdrawFailure = const NetworkFailure();
      await pumpFullApp(
        tester,
        overrides: [
          personalDexRepositoryProvider.overrideWithValue(repository),
        ],
      );
      await openShinyDex(tester);
      await tester.tap(slot(1));
      await tester.pumpAndSettle();

      await tapMoreAction(tester, 'Retirar do slot');
      expect(find.text(const NetworkFailure().message), findsOneWidget);

      repository
        ..withdrawFailure = null
        ..depositFailure = const ServerFailure();
      await tapMoreAction(tester, 'Retirar do slot');
      await tester.tap(find.text('Desfazer'));
      await tester.pumpAndSettle();
      expect(find.text(const ServerFailure().message), findsOneWidget);
    });
  });

  group('depositar automaticamente', () {
    Future<void> open(WidgetTester tester) async {
      // A mensagem do depósito anterior cobriria os botões da folha.
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mais opções'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Depositar automaticamente'));
      await tester.pumpAndSettle();
    }

    for (final size in [compactSize, expandedSize]) {
      testWidgets('prévia, só shiny e depositar (${size.width.toInt()}px)', (
        tester,
      ) async {
        await pumpFullApp(tester, size: size);
        await openShinyDex(tester);

        // Cancelar não deposita nada.
        await open(tester);
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(find.text('HOME 1 · 20/30'), findsOneWidget);

        // Seed: 9 shiny livres + o Saur (não shiny) para os 19 vazios.
        await open(tester);
        expect(
          find.text(
            '10 espécimes podem ser depositados · '
            '9 slots vazios continuam sem',
          ),
          findsOneWidget,
        );
        expect(find.text('Não shiny'), findsOneWidget);
        await tester.tap(find.text('Só espécimes shiny'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            '9 espécimes podem ser depositados · '
            '10 slots vazios continuam sem',
          ),
          findsOneWidget,
        );
        expect(find.text('Não shiny'), findsNothing);
        await tester.tap(find.text('Depositar 9'));
        await tester.pumpAndSettle();
        expect(find.text('9 espécimes depositados.'), findsOneWidget);
        expect(find.text('HOME 1 · 25/30'), findsOneWidget);

        // Sem "só shiny", sobra o Saur.
        await open(tester);
        expect(
          find.textContaining('1 espécime pode ser depositado'),
          findsOneWidget,
        );
        await tester.tap(find.text('Depositar 1'));
        await tester.pumpAndSettle();
        expect(find.text('1 espécime depositado.'), findsOneWidget);

        await open(tester);
        expect(
          find.text('Nenhum espécime livre para os slots vazios deste dex.'),
          findsOneWidget,
        );
        expect(find.textContaining(RegExp(r'^Depositar \d')), findsNothing);
        await tester.tap(find.text('Fechar'));
        await tester.pumpAndSettle();
      });
    }

    testWidgets('dex normal: exceção shiny e um slot sem', (tester) async {
      final fake = FakeBackend()
        ..addForm(id: 1, name: 'bulbasaur')
        ..addForm(id: 2, name: 'ivysaur');
      final dex = fake.addDex(name: 'Dex');
      fake
        ..addBox(dexId: dex, name: 'HOME 1', formIds: [1, 2])
        ..addSpecimen(formId: 1, isShiny: true);
      await pumpFullApp(tester, backend: fake);
      await tester.tap(find.text('Dex'));
      await tester.pumpAndSettle();

      await open(tester);
      expect(find.text('Só espécimes não shiny'), findsOneWidget);
      expect(
        find.text('1 espécime pode ser depositado · 1 slot vazio continua sem'),
        findsOneWidget,
      );
      expect(find.widgetWithText(Chip, 'Shiny'), findsOneWidget);
    });

    testWidgets('erro na prévia (com retry) e ao depositar', (tester) async {
      final repository = _FlakyRepository(FakeBackend.seeded())
        ..linkFailure = const NetworkFailure();
      await pumpFullApp(
        tester,
        overrides: [
          personalDexRepositoryProvider.overrideWithValue(repository),
        ],
      );
      await openShinyDex(tester);

      await open(tester);
      expect(find.text(const NetworkFailure().message), findsOneWidget);
      repository.linkFailure = null;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text('Depositar 10'), findsOneWidget);

      repository.linkFailure = const ServerFailure();
      await tester.tap(find.text('Depositar 10'));
      await tester.pumpAndSettle();
      expect(find.text(const ServerFailure().message), findsOneWidget);
      expect(find.text('Depositar automaticamente'), findsOneWidget);
    });
  });

  group('caçada no painel do slot', () {
    for (final size in [expandedSize, compactSize]) {
      testWidgets('a linha leva às caçadas ativas (${size.width.toInt()}px)', (
        tester,
      ) async {
        final backend = FakeBackend.seeded();
        final form = (await backend.fetchSlot(3)).form!.id;
        await backend.saveShinyHunt(
          ShinyHunt(id: 0, form: form, count: 7, unit: 'resets'),
        );
        await pumpFullApp(tester, size: size, backend: backend);
        await openShinyDex(tester);
        await tester.tap(slot(3));
        await tester.pumpAndSettle();
        expect(find.text('Caçada em andamento'), findsOneWidget);
        expect(find.text('7 resets'), findsOneWidget);
        await tester.ensureVisible(find.text('Caçada em andamento'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Caçada em andamento'));
        await tester.pumpAndSettle();
        expect(find.byType(HuntsPage), findsOneWidget);
        expect(find.byType(HuntCards), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
      });
    }
  });

  group('navegação no painel do slot', () {
    Finder balloon(String box) => find.descendant(
      of: find.byType(BoxNoticeBalloon),
      matching: find.text(box),
    );
    Future<void> swipe(WidgetTester tester, double dx) async {
      await tester.fling(find.byType(SlotDetailPanel), Offset(dx, 0), 1000);
      await tester.pumpAndSettle();
    }

    double balloonOpacity(WidgetTester tester) => tester
        .widget<AnimatedOpacity>(
          find.descendant(
            of: find.byType(BoxNoticeBalloon),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;

    testWidgets('setas, deslizar e a troca de box com o balão (expandido)', (
      tester,
    ) async {
      await pumpFullApp(tester);
      await openShinyDex(tester);
      await tester.tap(slot(1));
      await tester.pumpAndSettle();
      expect(find.text('HOME 1 · L1 C1 · 1 de 30'), findsOneWidget);
      // O começo do dex: não há slot antes.
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byTooltip('Slot anterior'),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNull,
      );
      // Um gesto curto demais não conta.
      await tester.drag(find.byType(SlotDetailPanel), const Offset(-20, 0));
      await tester.pumpAndSettle();
      expect(find.text('HOME 1 · L1 C1 · 1 de 30'), findsOneWidget);

      await tester.tap(find.byTooltip('Próximo slot'));
      await tester.pumpAndSettle();
      expect(find.text('HOME 1 · L1 C2 · 2 de 30'), findsOneWidget);
      await swipe(tester, -300);
      expect(find.text('HOME 1 · L1 C3 · 3 de 30'), findsOneWidget);
      // A grade acompanha: o slot 3 fica selecionado.
      expect(
        tester
            .widget<SlotTile>(
              find.ancestor(of: slot(3), matching: find.byType(SlotTile)),
            )
            .selected,
        isTrue,
      );
      await swipe(tester, 300);
      expect(find.text('HOME 1 · L1 C2 · 2 de 30'), findsOneWidget);
      expect(find.byType(BoxNoticeBalloon), findsNothing);

      // Do último slot da box para o primeiro da seguinte, com o balão.
      await tester.tap(slot(30));
      await tester.pumpAndSettle();
      expect(find.text('HOME 1 · L5 C6 · 30 de 30'), findsOneWidget);
      await tester.tap(find.byTooltip('Próximo slot'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('HOME 2 · 19/28'), findsOneWidget);
      expect(find.text('HOME 2 · L1 C1 · 1 de 28'), findsOneWidget);
      expect(balloon('HOME 2'), findsOneWidget);
      expect(balloonOpacity(tester), 1);
      await tester.pump(BoxNoticeBalloon.visibleFor);
      await tester.pumpAndSettle();
      expect(balloonOpacity(tester), 0);

      // E de volta: o balão aparece de novo, com a box anterior.
      await tester.tap(find.byTooltip('Slot anterior'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('HOME 1 · L5 C6 · 30 de 30'), findsOneWidget);
      expect(balloon('HOME 1'), findsOneWidget);
      expect(balloonOpacity(tester), 1);
      await tester.pump(BoxNoticeBalloon.visibleFor);
      await tester.pumpAndSettle();

      // Um toque na grade tira o balão.
      await tester.tap(slot(29));
      await tester.pumpAndSettle();
      expect(find.byType(BoxNoticeBalloon), findsNothing);
    });

    testWidgets('fim do dex: não há próximo slot', (tester) async {
      await pumpFullApp(tester);
      await openShinyDex(tester);
      final boxes = await tester.runAsync(
        () => FakeBackend.seeded().fetchBoxes(1),
      );
      final last = boxes!.length - 1;
      for (var i = 0; i < last; i++) {
        await tester.tap(find.byTooltip('Próxima box'));
        await tester.pumpAndSettle();
      }
      final slots = await tester.runAsync(
        () => FakeBackend.seeded().fetchSlots(dexId: 1, boxId: boxes[last].id),
      );
      final lastSlot = navigableSlots(slots!, onlyMissing: false).last;
      await tester.tap(slot(lastSlot.id));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byTooltip('Próximo slot'),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('com o filtro de faltantes, só os faltantes', (tester) async {
      await pumpFullApp(tester);
      await openShinyDex(tester);
      await tester.tap(find.byTooltip('Destacar faltantes'));
      await tester.pumpAndSettle();
      // Um registrado (apagado) ainda abre, e a navegação parte dele.
      await tester.tap(slot(1));
      await tester.pumpAndSettle();
      expect(find.text('HOME 1 · L1 C1 · 1 de 11'), findsOneWidget);
      await tester.tap(find.byTooltip('Próximo slot'));
      await tester.pumpAndSettle();
      // Saindo do registrado, ele deixa a lista: só os 10 faltantes.
      expect(find.text('HOME 1 · L1 C3 · 1 de 10'), findsOneWidget);
      expect(find.text('Faltante'), findsOneWidget);
    });

    testWidgets('falha ao carregar a box vizinha mostra a mensagem', (
      tester,
    ) async {
      final repository = _FlakyRepository(FakeBackend.seeded());
      await pumpFullApp(
        tester,
        overrides: [
          personalDexRepositoryProvider.overrideWithValue(repository),
        ],
      );
      await openShinyDex(tester);
      await tester.tap(slot(30));
      await tester.pumpAndSettle();
      repository.slotFailures = 1;
      await tester.tap(find.byTooltip('Próximo slot'));
      await tester.pumpAndSettle();
      expect(find.text(const NetworkFailure().message), findsOneWidget);
      expect(find.text('HOME 1 · L5 C6 · 30 de 30'), findsOneWidget);
    });

    testWidgets('compacto: deslizar no bottom sheet troca a box da grade', (
      tester,
    ) async {
      await pumpFullApp(tester, size: compactSize);
      await openShinyDex(tester);
      await tester.tap(slot(29));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('HOME 1 · L5 C5 · 29 de 30'), findsOneWidget);
      await swipe(tester, -300);
      expect(find.text('HOME 1 · L5 C6 · 30 de 30'), findsOneWidget);
      await swipe(tester, -300);
      // O sheet continua aberto, já no slot da box seguinte.
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('HOME 2 · L1 C1 · 1 de 28'), findsOneWidget);
      expect(balloon('HOME 2'), findsOneWidget);
      await tester.pump(BoxNoticeBalloon.visibleFor);
      await tester.pumpAndSettle();

      // Atrás do sheet, a grade já está na HOME 2.
      Navigator.of(tester.element(find.byType(SlotDetailPanel))).pop();
      await tester.pumpAndSettle();
      expect(find.text('HOME 2 · 19/28'), findsOneWidget);
    });
  });
}
