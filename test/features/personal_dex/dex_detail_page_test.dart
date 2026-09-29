import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/personal_dex/data/last_dex_storage.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/domain/personal_dex_repository.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/box_list_panel.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/slot_tile.dart';
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
      expect(find.text('Shiny'), findsOneWidget);
      expect(find.text('Alfa'), findsOneWidget);
      // Selo 💢 nos alfas da box (formas 1, 11, 16 e 26) + chip do detalhe.
      expect(find.text(alphaEmoji), findsNWidgets(5));
      expect(find.text('Poke Ball'), findsOneWidget);
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
        // Entrou direto no último dex usado.
        expect(find.text('HOME 3 · 20/30'), findsOneWidget);

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

        await tester.tap(find.byTooltip('Progresso por geração'));
        await tester.pumpAndSettle();
        expect(find.text('Geração I'), findsOneWidget);
        await tester.tap(find.text('Geração II'));
        await tester.pumpAndSettle();
        expect(find.text('HOME B · 0/1'), findsOneWidget);

        // Fechar sem escolher mantém a box.
        await tester.tap(find.byTooltip('Progresso por geração'));
        await tester.pumpAndSettle();
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
      await tester.tap(find.byTooltip('Progresso por geração'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Geração I'));
      await tester.pumpAndSettle();
      expect(find.text('HOME 1 · 20/30'), findsOneWidget);
    });
  });

  group('busca no dex', () {
    Future<void> searchFor(WidgetTester tester, String text) async {
      await tester.tap(find.byTooltip('Buscar no dex'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Nome ou número'),
        text,
      );
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

    testWidgets('fechar sem escolher não muda nada', (tester) async {
      await pumpFullApp(tester);
      await openShinyDex(tester);
      await tester.tap(find.byTooltip('Buscar no dex'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
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
        if (size == compactSize) {
          // No compacto o detalhe fica no bottom sheet: toca no slot.
          await tester.tap(slot(40));
          await tester.pumpAndSettle();
        }
        expect(find.text('Wigglytuff'), findsWidgets);
      });
    }

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
}
