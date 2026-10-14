import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/game_picker.dart';

import '../../helpers/helpers.dart';

void main() {
  testWidgets('em inglês, com duas seções: contagens e busca sem resultado', (
    tester,
  ) async {
    const games = [
      'red',
      'blue',
      'yellow',
      'gold',
      'silver',
      'crystal',
      'ruby',
      'sapphire', //
    ];
    await pumpWidgetApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showGamePicker(
              context,
              sections: const [
                GamePickerSection(
                  title: 'A',
                  versions: games,
                  selected: ['red'],
                  saves: {'red': 2},
                ),
                GamePickerSection(title: 'B', versions: games, selected: []),
              ],
              applyLabel: (_, _) => 'OK',
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
      size: const Size(420, 2400),
      locale: english,
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('8 games'), findsNWidgets(2));
    expect(find.text('1 marked'), findsOneWidget);
    expect(find.text('2 saves'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(
      find.text('No game with that name in this section.'),
      findsNWidgets(2),
    );
  });
}
