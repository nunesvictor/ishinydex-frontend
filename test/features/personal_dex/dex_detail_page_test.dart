import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/personal_dex/data/last_dex_storage.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/domain/personal_dex_repository.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/slot_tile.dart';

import '../../helpers/helpers.dart';

/// Repositório que delega ao fake, mas pode falhar sob demanda.
class _FlakyRepository implements PersonalDexRepository {
  _FlakyRepository(this.inner);

  final FakeBackend inner;
  int dexFailures = 0;
  int boxFailures = 0;
  int slotFailures = 0;
  bool failWithdraw = false;

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
  Future<Slot> deposit({required int slotId, required int specimenId}) =>
      inner.deposit(slotId: slotId, specimenId: specimenId);

  @override
  Future<Slot> withdraw(int slotId) async {
    if (failWithdraw) throw ValidationFailure(const {}, detail: 'Não pode.');
    return await inner.withdraw(slotId);
  }
}

Future<void> openShinyDex(WidgetTester tester) async {
  await tester.tap(find.text('Shiny Living Dex'));
  await tester.pumpAndSettle();
}

Finder slot(int id) => find.byKey(ValueKey('slot-$id'));

void main() {
  group('layout expandido', () {
    testWidgets('lista de boxes, seleção e detalhe', (tester) async {
      await pumpFullApp(tester);
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
      expect(find.text('Trocar specimen'), findsOneWidget);

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

    testWidgets('retirar com confirmação', (tester) async {
      await pumpFullApp(tester);
      await openShinyDex(tester);
      await tester.tap(slot(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retirar'));
      await tester.pumpAndSettle();
      // Cancelar não faz nada.
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Registrado'), findsOneWidget);

      await tester.tap(find.text('Retirar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Retirar'));
      await tester.pumpAndSettle();
      expect(find.text('Specimen retirado.'), findsOneWidget);
      expect(find.text('Faltante'), findsOneWidget);
      expect(find.text('HOME 1 · 19/30'), findsOneWidget);
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

    testWidgets('falha ao retirar mostra a mensagem', (tester) async {
      final repository = _FlakyRepository(FakeBackend.seeded())
        ..failWithdraw = true;
      await pumpFullApp(
        tester,
        overrides: [
          personalDexRepositoryProvider.overrideWithValue(repository),
        ],
      );
      await openShinyDex(tester);
      await tester.tap(slot(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retirar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Retirar'));
      await tester.pumpAndSettle();
      expect(find.text('Não pode.'), findsOneWidget);
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

      await tester.tap(slot(3));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retirar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Retirar'));
      await tester.pumpAndSettle();
      expect(find.text('Specimen retirado.'), findsOneWidget);
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
