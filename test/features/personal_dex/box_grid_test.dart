import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/box_grid.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/slot_tile.dart';

import '../../fixtures/api_fixtures.dart';
import '../../helpers/helpers.dart';

void main() {
  for (final size in [compactSize, expandedSize]) {
    testWidgets('slot livre e posições ausentes viram células vazias '
        '(${size.width.toInt()}px)', (tester) async {
      final registered = Slot.fromJson(registeredSlotJson);
      // Um slot livre vindo da API (sem forma) na posição seguinte.
      final free = registered.copyWith(id: 999, col: 1, form: null);
      final tapped = <Slot>[];
      await pumpWidgetApp(
        tester,
        Scaffold(
          body: BoxGrid(slots: [registered, free], onSlotTap: tapped.add),
        ),
        size: size,
      );
      expect(find.byType(SlotTile), findsOneWidget);
      expect(find.byType(EmptySlotTile), findsNWidgets(29));

      await tester.tap(find.byType(EmptySlotTile).first);
      await tester.tap(find.byType(SlotTile));
      expect(tapped, [registered]);
    });
  }
}
