import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/choice_select.dart';

import '../../helpers/helpers.dart';

const _balls = [
  Choice(value: 'poke-ball', label: 'Poké Ball', spriteUrl: 'http://x/p.png'),
  Choice(value: 'dream-ball', label: 'Dream Ball', spriteUrl: 'http://x/d.png'),
];

const _natures = [
  Choice(value: 'adamant', label: 'Adamant'),
  Choice(value: 'modest', label: 'Modest'),
];

void main() {
  Future<List<String?>> pumpSelect(
    WidgetTester tester, {
    required TargetPlatform platform,
    List<Choice> choices = _balls,
    String? value,
    Size size = expandedSize,
  }) async {
    final changes = <String?>[];
    await pumpWidgetApp(
      tester,
      Scaffold(
        body: ChoiceSelect(
          label: 'Pokébola',
          choices: choices,
          value: value,
          errorText: 'erro da API',
          onChanged: changes.add,
        ),
      ),
      platform: platform,
      size: size,
    );
    return changes;
  }

  TextField field(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField));

  group('desktop', () {
    testWidgets('digitar filtra sem acento e Enter escolhe', (tester) async {
      final changes = await pumpSelect(tester, platform: TargetPlatform.linux);
      expect(field(tester).readOnly, false);
      expect(find.text('erro da API'), findsOneWidget);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'poke');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(MenuItemButton, 'Poké Ball'), findsOneWidget);
      expect(find.widgetWithText(MenuItemButton, 'Dream Ball'), findsNothing);

      // Enter no campo de texto dispara o "submit" do teclado.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(changes, ['poke-ball']);
    });

    testWidgets('texto vazio ou sem resultado não destaca nada', (
      tester,
    ) async {
      await pumpSelect(tester, platform: TargetPlatform.macOS);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      // Sem filtro: "—" e as duas bolas.
      expect(find.byType(MenuItemButton), findsNWidgets(3));
    });
  });

  for (final size in [compactSize, expandedSize]) {
    testWidgets('mobile só aceita toque (${size.width.toInt()}px)', (
      tester,
    ) async {
      final changes = await pumpSelect(
        tester,
        platform: TargetPlatform.iOS,
        value: 'poke-ball',
        size: size,
      );
      expect(field(tester).readOnly, true);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, '—'));
      await tester.pumpAndSettle();
      expect(changes, [null]);
    });
  }

  testWidgets('pokébolas mostram o sprite no campo e em cada item', (
    tester,
  ) async {
    await pumpSelect(
      tester,
      platform: TargetPlatform.android,
      value: 'dream-ball',
    );
    PokemonSprite leading() => tester.widget<PokemonSprite>(
      find
          .descendant(
            of: find.byType(TextField),
            matching: find.byType(PokemonSprite),
          )
          .first,
    );
    expect(leading().url, 'http://x/d.png');

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.widgetWithText(MenuItemButton, 'Poké Ball'),
        matching: find.byType(PokemonSprite),
      ),
      findsOneWidget,
    );
  });

  testWidgets('opções sem sprite não mostram ícone', (tester) async {
    await pumpSelect(
      tester,
      platform: TargetPlatform.android,
      choices: _natures,
    );
    expect(find.byType(PokemonSprite), findsNothing);
  });
}
