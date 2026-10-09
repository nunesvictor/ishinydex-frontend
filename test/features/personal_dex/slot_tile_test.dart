import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/widgets/mark_icons.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/slot_tile.dart';

import '../../fixtures/api_fixtures.dart';
import '../../helpers/helpers.dart';

void main() {
  // Registrado, shiny e alfa.
  final slot = Slot.fromJson(registeredSlotJson);
  final shinyAlpha = slot.copyWith(
    specimen: slot.specimen!.copyWith(isShiny: true, isAlpha: true),
  );

  Future<void> pumpTile(WidgetTester tester, double cell, Slot slot) =>
      pumpWidgetApp(
        tester,
        Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: cell,
              child: SlotTile(slot: slot, selected: false, onTap: () {}),
            ),
          ),
        ),
        size: expandedSize,
      );

  testWidgets('célula grande: ✨ e 💢 lado a lado', (tester) async {
    await pumpTile(tester, 120, shinyAlpha);
    expect(find.byKey(const ValueKey('badges-row')), findsOneWidget);
    expect(find.byType(ShinyIcon), findsOneWidget);
    expect(find.byType(AlphaIcon), findsOneWidget);
  });

  testWidgets('célula média: selos empilhados', (tester) async {
    await pumpTile(tester, 50, shinyAlpha);
    expect(find.byKey(const ValueKey('badges-column')), findsOneWidget);
    expect(find.byType(AlphaIcon), findsOneWidget);
  });

  testWidgets('célula muito pequena: só o ✨', (tester) async {
    await pumpTile(tester, 32, shinyAlpha);
    expect(find.byType(ShinyIcon), findsOneWidget);
    expect(find.byType(AlphaIcon), findsNothing);
  });

  testWidgets('sem shiny nem alfa, sem selos', (tester) async {
    await pumpTile(
      tester,
      120,
      slot.copyWith(specimen: slot.specimen!.copyWith(isShiny: false)),
    );
    expect(find.byKey(const ValueKey('badges-row')), findsNothing);
    expect(find.byType(ShinyIcon), findsNothing);
  });

  testWidgets('visitando o Champions: a marca no canto', (tester) async {
    await pumpTile(
      tester,
      120,
      slot.copyWith(
        specimen: slot.specimen!.copyWith(championsSince: DateTime(2026)),
      ),
    );
    expect(find.byKey(const ValueKey('champions-mark')), findsOne);
    expect(find.byTooltip('Visitando o Champions'), findsOne);
  });
}
