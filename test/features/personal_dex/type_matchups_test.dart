import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/widgets/type_chip.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/type_matchups.dart';

import '../../helpers/helpers.dart';

/// Os tipos (em ordem) na linha do rótulo [label].
List<String> _row(WidgetTester tester, String label) => [
  for (final chip in tester.widgetList<TypeChip>(
    find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
      matching: find.byType(TypeChip),
    ),
  ))
    chip.type,
];

Future<void> _pump(
  WidgetTester tester,
  List<String> types, {
  Locale locale = portuguese,
}) => pumpWidgetApp(
  tester,
  SingleChildScrollView(child: TypeMatchupsCard(types: types)),
  locale: locale,
  size: const Size(402, 1400),
);

void main() {
  testWidgets('Garchomp: as fraquezas e o STAB do mock', (tester) async {
    await _pump(tester, ['dragon', 'ground']);
    expect(find.text('Tipos em batalha'), findsOneWidget);
    expect(_row(tester, 'Extremamente efetivo'), ['ice']);
    expect(_row(tester, 'Super efetivo'), ['dragon', 'fairy']);
    expect(_row(tester, 'Pouco efetivo'), ['fire', 'poison', 'rock']);
    expect(_row(tester, 'Sem efeito'), ['electric']);
    // Sem ¼× no Garchomp: a linha não aparece.
    expect(find.text('Muito pouco efetivo'), findsNothing);
    expect(find.text('2× contra'), findsNWidgets(2));
    expect(
      find.text(
        'Tabela da geração 6 em diante. Habilidades (como Levitate) e Tera '
        'não entram.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Bulbasaur: ¼× contra Grass; todo chip com o ícone', (
    tester,
  ) async {
    await _pump(tester, ['grass', 'poison']);
    expect(_row(tester, 'Muito pouco efetivo'), ['grass']);
    expect(
      find.byType(TypeIcon),
      findsNWidgets(find.byType(TypeChip).evaluate().length),
    );
  });

  testWidgets('sem tipo da tabela (Stellar): o quadro não aparece', (
    tester,
  ) async {
    await _pump(tester, ['stellar']);
    expect(find.byKey(const ValueKey('type-matchups')), findsNothing);
  });

  testWidgets('em inglês', (tester) async {
    await _pump(tester, ['dragon', 'ground'], locale: english);
    expect(find.text('Type matchups'), findsOneWidget);
    expect(find.text('WHEN ATTACKED'), findsOneWidget);
    expect(find.text('ATTACKING WITH ITS OWN TYPES (STAB)'), findsOneWidget);
    expect(find.text('Extremely effective'), findsOneWidget);
    expect(find.text('No effect'), findsOneWidget);
    expect(find.text('2× against'), findsNWidgets(2));
  });

  testWidgets('TypeIcon: sem o asset (Stellar), um círculo na cor', (
    tester,
  ) async {
    await pumpWidgetApp(tester, const Center(child: TypeIcon('stellar')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(TypeIcon),
        matching: find.byType(Container),
      ),
      findsOneWidget,
    );
  });
}
