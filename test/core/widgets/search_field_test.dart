import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/widgets/search_field.dart';

import '../../helpers/helpers.dart';

void main() {
  testWidgets('pílula: o "x" só com texto; sem onCleared, avisa com vazio', (
    tester,
  ) async {
    final changes = <String>[];
    await pumpWidgetApp(
      tester,
      Scaffold(
        body: SearchField(hintText: 'Buscar', onChanged: changes.add),
      ),
    );
    final border =
        tester.widget<TextField>(find.byType(TextField)).decoration!.border!
            as OutlineInputBorder;
    expect(border.borderRadius, BorderRadius.circular(28));
    expect(find.byTooltip('Limpar busca'), findsNothing);

    await tester.enterText(find.byType(TextField), 'pika');
    await tester.pump();
    await tester.tap(find.byTooltip('Limpar busca'));
    await tester.pump();

    expect(changes, ['pika', '']);
    expect(find.text('pika'), findsNothing);
    expect(find.byTooltip('Limpar busca'), findsNothing);
  });

  testWidgets('com onCleared, só ele é chamado ao limpar', (tester) async {
    final controller = TextEditingController(text: 'abc');
    addTearDown(controller.dispose);
    var cleared = 0;
    final changes = <String>[];
    await pumpWidgetApp(
      tester,
      Scaffold(
        body: SearchField(
          hintText: 'Buscar',
          controller: controller,
          onChanged: changes.add,
          onCleared: () => cleared++,
        ),
      ),
    );
    await tester.tap(find.byTooltip('Limpar busca'));
    await tester.pump();

    expect(cleared, 1);
    expect(changes, isEmpty);
    expect(controller.text, '');
  });
}
