import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/deposit_flow.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_form_page.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';
import '../../helpers/mocks.dart';

/// Monta um botão que abre o fluxo e guarda o resultado.
Future<List<bool>> pumpFlow(
  WidgetTester tester, {
  required FakeBackend backend,
  required Slot slot,
  bool preferShiny = true,
  Size size = expandedSize,
  SpecimenRepositoryOverride? specimens,
}) async {
  final results = <bool>[];
  await pumpWidgetApp(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async => results.add(
            await showDepositFlow(
              context,
              slot: slot,
              preferShiny: preferShiny,
            ),
          ),
          child: const Text('abrir'),
        ),
      ),
    ),
    size: size,
    overrides: [
      envProvider.overrideWithValue(fakeEnv),
      fakeBackendProvider.overrideWithValue(backend),
      if (specimens != null)
        specimenRepositoryProvider.overrideWithValue(specimens),
    ],
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return results;
}

typedef SpecimenRepositoryOverride = MockSpecimenRepository;

void main() {
  late FakeBackend backend;

  setUp(() => backend = FakeBackend.seeded());

  Future<Slot> slotAt(int index, {int box = 1}) async =>
      (await backend.fetchSlots(dexId: 1, boxId: box))[index];

  testWidgets('lista vazia e fechar sem depositar', (tester) async {
    // Forma 5 (slot 5) está registrada e não há outro specimen dela.
    final results = await pumpFlow(
      tester,
      backend: backend,
      slot: await slotAt(4),
    );
    expect(
      find.text('Nenhum specimen disponível desta forma.'),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(results, [false]);
  });

  testWidgets('shiny preferido deposita direto', (tester) async {
    // Forma 6 tem um specimen shiny disponível.
    final results = await pumpFlow(
      tester,
      backend: backend,
      slot: await slotAt(5),
    );
    expect(find.text(shinyEmoji), findsOneWidget);
    await tester.tap(find.text('Charizard'));
    await tester.pumpAndSettle();
    expect(results, [true]);
  });

  testWidgets('não-shiny em dex normal com shiny pede confirmação', (
    tester,
  ) async {
    await backend.create(
      SpecimenDraft(
        form: 6,
        nickname: 'Zard',
        isAlpha: true,
        pokeball: 'poke-ball',
        capturedAt: DateTime(2024, 3, 2),
      ),
    );
    final results = await pumpFlow(
      tester,
      backend: backend,
      slot: await slotAt(5),
      preferShiny: false,
      size: compactSize,
    );
    // O não-shiny vem primeiro.
    expect(find.textContaining('Alfa · Poke Ball'), findsOneWidget);
    await tester.tap(find.text('Charizard'));
    await tester.pumpAndSettle();
    expect(find.textContaining('é shiny, mas o dex não é'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(results, isEmpty);
    await tester.tap(find.text('Zard'));
    await tester.pumpAndSettle();
    expect(results, [true]);
  });

  testWidgets('erro de validação do depósito aparece no seletor', (
    tester,
  ) async {
    // Slot com forma 6 mas id do slot 3 (forma 3): o backend recusa.
    final wrong = (await slotAt(5)).copyWith(id: 3);
    await pumpFlow(tester, backend: backend, slot: wrong);
    await tester.tap(find.text('Charizard'));
    await tester.pumpAndSettle();
    expect(
      find.text("specimen form doesn't match with slot form."),
      findsOneWidget,
    );
  });

  testWidgets('erro ao carregar e tentar novamente', (tester) async {
    final specimens = MockSpecimenRepository();
    var calls = 0;
    when(() => specimens.fetchAvailable(6)).thenAnswer((_) async {
      if (calls++ == 0) throw const NetworkFailure();
      return const [];
    });
    await pumpFlow(
      tester,
      backend: backend,
      slot: await slotAt(5),
      specimens: specimens,
    );
    expect(find.text(const NetworkFailure().message), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(
      find.text('Nenhum specimen disponível desta forma.'),
      findsOneWidget,
    );
  });

  testWidgets('cadastrar novo specimen e depositar', (tester) async {
    final results = await pumpFlow(
      tester,
      backend: backend,
      slot: await slotAt(2),
    );
    await tester.tap(find.text('Cadastrar novo specimen'));
    await tester.pumpAndSettle();
    expect(find.text('Novo Venusaur'), findsOneWidget);
    // Voltar sem salvar não deposita.
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(results, isEmpty);

    await tester.tap(find.text('Cadastrar novo specimen'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Salvar e depositar'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(SpecimenForm),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Salvar e depositar'));
    await tester.pumpAndSettle();
    expect(results, [true]);
  });
}
