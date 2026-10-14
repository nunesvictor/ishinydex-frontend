import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/widgets/chip_icons.dart';
import 'package:ishinydex/core/widgets/mark_icons.dart';
import 'package:ishinydex/core/widgets/menu_chip.dart';

import '../../helpers/helpers.dart';

void main() {
  Widget icons(int n) => ChipIcons([
    for (var i = 0; i < n; i++) const Icon(Icons.star),
  ], semanticLabel: 'Jogo: vários');

  testWidgets('até 3 ícones e "+N"; o nome no leitor de tela', (tester) async {
    for (final (n, plus) in [(1, null), (3, null), (5, '+2')]) {
      await pumpWidgetApp(tester, Scaffold(body: Center(child: icons(n))));
      expect(find.byIcon(Icons.star), findsNWidgets(n.clamp(0, 3)));
      expect(find.textContaining('+'), plus == null ? findsNothing : findsOne);
    }
    expect(find.bySemanticsLabel('Jogo: vários'), findsOne);
  });

  test('joinLabels', () {
    expect(joinLabels(ptText, []), '');
    expect(joinLabels(ptText, ['shiny']), 'shiny');
    expect(joinLabels(ptText, ['A', 'B', 'C']), 'A, B e C');
    expect(joinLabels(enText, ['A', 'B', 'C']), 'A, B and C');
  });

  testWidgets('MenuChip: o nome sem valores; só ícones com valores', (
    tester,
  ) async {
    await pumpWidgetApp(
      tester,
      const Scaffold(
        body: Center(
          child: Column(
            children: [
              MenuChip(label: 'Raridade', menuChildren: []),
              MenuChip(
                label: 'Motivos',
                tooltip: 'Motivos: sem shiny',
                icons: [NoShinyIcon(size: 18)],
                selected: true,
                menuChildren: [],
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Raridade'), findsOne);
    expect(find.text('Motivos'), findsNothing);
    expect(find.byTooltip('Motivos: sem shiny'), findsOne);
    expect(find.byType(NoShinyIcon), findsOne);
  });
}
