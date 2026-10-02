import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/network/paginated.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/widgets/alpha_icon.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/personal_dex/data/last_dex_storage.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/domain/personal_dex_repository.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/dex_detail_page.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/box_list_panel.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/slot_search.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/slot_tile.dart';
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
  Future<Slot> deposit({required int slotId, required int specimenId}) =>
      inner.deposit(slotId: slotId, specimenId: specimenId);
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
      expect(find.text('Libertar'), findsOneWidget);
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
      // Botão de atenção: cor de erro do tema.
      final button = find.widgetWithText(OutlinedButton, 'Libertar');
      expect(
        DefaultTextStyle.of(
          tester.element(
            find.descendant(of: button, matching: find.text('Libertar')),
          ),
        ).style.color,
        Theme.of(tester.element(button)).colorScheme.error,
      );

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Libertar Bulbasaur?'), findsOneWidget);
      expect(find.textContaining('não pode ser desfeita'), findsOneWidget);
      // Cancelar não faz nada.
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Registrado'), findsOneWidget);

      await tester.tap(button);
      await tester.pumpAndSettle();
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
      await tester.tap(find.text('Libertar'));
      await tester.pumpAndSettle();
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
    // Barra no topo (telas maiores) ou pílula embaixo (celular).
    Finder searchField() => find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is SlotSearchBar || widget is SlotSearchPill,
      ),
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
      expect(find.text('#0040 · HOME 2 · linha 2, coluna 4'), findsOneWidget);
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
      expect(find.text('HOME 2 · linha 2, coluna 4'), findsOneWidget);
    });

    testWidgets('compacto: a pílula fica embaixo e sobe para o topo com o '
        'foco, recolhendo a AppBar', (tester) async {
      await pumpFullApp(tester, size: compactSize);
      await openShinyDex(tester);
      final pill = find.byType(SlotSearchPill);
      final restTop = tester.getTopLeft(pill).dy;
      expect(restTop, greaterThan(compactSize.height / 2));
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

    testWidgets('expandido: a AppBar fica durante a busca', (tester) async {
      await pumpFullApp(tester);
      await openShinyDex(tester);
      await tester.tap(searchField());
      await tester.pumpAndSettle();
      expect(find.byTooltip('Mais opções').hitTestable(), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    for (final size in [compactSize, expandedSize]) {
      testWidgets('"Buscar" no teclado fecha o teclado e mantém os resultados '
          '(${size.width.toInt()}px)', (tester) async {
        await pumpFullApp(tester, size: size);
        await openShinyDex(tester);
        await searchFor(tester, 'wiggly');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(searchField()).focusNode!.hasFocus,
          isFalse,
        );
        expect(find.byKey(const ValueKey('search-slot-40')), findsOneWidget);
        expect(find.text('Cancelar'), findsOneWidget);
      });
    }

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
      await tester.tap(find.text('Libertar'));
      await tester.pumpAndSettle();
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
}
