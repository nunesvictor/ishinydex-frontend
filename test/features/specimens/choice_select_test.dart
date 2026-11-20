import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/choice_select.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

const _balls = [
  Choice(value: 'poke-ball', label: 'Poké Ball', spriteUrl: 'http://x/p.png'),
  Choice(value: 'dream-ball', label: 'Dream Ball', spriteUrl: 'http://x/d.png'),
];

/// Com o efeito (#410): fora da ordem alfabética de propósito, para a busca
/// por atributo mostrar a ordem dela.
const _effects = [
  Choice(
    value: 'brave',
    label: 'Brave',
    increased: 'attack',
    decreased: 'speed',
  ),
  Choice(
    value: 'careful',
    label: 'Careful',
    increased: 'special-defense',
    decreased: 'special-attack',
  ),
  Choice(
    value: 'hardy',
    label: 'Hardy',
    increased: 'attack',
    decreased: 'attack',
  ),
  Choice(
    value: 'jolly',
    label: 'Jolly',
    increased: 'speed',
    decreased: 'special-attack',
  ),
  Choice(value: 'bashful', label: 'Bashful'),
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
    Locale locale = portuguese,
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
      locale: locale,
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

    testWidgets('focar seleciona o texto: digitar substitui o "—"', (
      tester,
    ) async {
      await pumpSelect(tester, platform: TargetPlatform.windows);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      final controller = field(tester).controller!;
      expect(controller.selection.textInside(controller.text), '—');
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

  group('naturezas com o efeito (#410)', () {
    TextSpan fieldSpan(WidgetTester tester) {
      final controller = field(tester).controller!;
      return controller.buildTextSpan(
        context: tester.element(find.byType(TextField)),
        style: const TextStyle(fontSize: 16),
        withComposing: false,
      );
    }

    Color? colorOf(TextSpan span, String text) => span.children!
        .whereType<TextSpan>()
        .firstWhere((c) => c.text == text)
        .style
        ?.color;

    testWidgets('no campo fechado, ↑ vermelho e ↓ azul', (tester) async {
      await pumpSelect(
        tester,
        platform: TargetPlatform.iOS,
        choices: _effects,
        value: 'careful',
      );
      expect(field(tester).controller!.text, 'Careful ↑ Def. Esp. ↓ Atq. Esp.');
      final span = fieldSpan(tester);
      expect(colorOf(span, '↑ Def. Esp.'), const Color(0xFFC62828));
      expect(colorOf(span, '↓ Atq. Esp.'), const Color(0xFF1565C0));
    });

    testWidgets('neutra: "(neutra)" apagado, no escuro também', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpSelect(
        tester,
        platform: TargetPlatform.iOS,
        choices: _effects,
        value: 'bashful',
      );
      expect(field(tester).controller!.text, 'Bashful (neutra)');
      expect(fieldSpan(tester).children, hasLength(3));
    });

    testWidgets('na lista, o efeito em duas colunas', (tester) async {
      await pumpSelect(tester, platform: TargetPlatform.iOS, choices: _effects);
      expect(fieldSpan(tester).children, isNull);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      final jolly = find.ancestor(
        of: find.text('Jolly'),
        matching: find.byType(MenuItemButton),
      );
      expect(
        find.descendant(of: jolly, matching: find.text('↑ Velocidade')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: jolly, matching: find.text('↓ Atq. Esp.')),
        findsOneWidget,
      );
      // Hardy sobe e desce o mesmo: neutra.
      expect(find.text('(neutra)'), findsNWidgets(2));
    });

    testWidgets('busca pelo atributo: as que sobem antes das que descem', (
      tester,
    ) async {
      final changes = await pumpSelect(
        tester,
        platform: TargetPlatform.linux,
        choices: _effects,
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      List<String> names() => [
        for (final e in tester.widgetList<Text>(
          find.descendant(
            of: find.byType(MenuItemButton),
            matching: find.byType(Text),
          ),
        ))
          if (const [
            'Brave',
            'Careful',
            'Hardy',
            'Jolly',
            'Bashful',
          ].contains(e.data))
            e.data!,
      ];
      await tester.enterText(find.byType(TextField), 'velo');
      await tester.pumpAndSettle();
      expect(names(), ['Jolly', 'Brave']);

      await tester.enterText(find.byType(TextField), 'neutra');
      await tester.pumpAndSettle();
      expect(names(), ['Hardy', 'Bashful']);

      await tester.enterText(find.byType(TextField), 'car');
      await tester.pumpAndSettle();
      expect(names(), ['Careful']);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(changes, ['careful']);
    });

    testWidgets('em inglês', (tester) async {
      await pumpSelect(
        tester,
        platform: TargetPlatform.iOS,
        choices: _effects,
        value: 'bashful',
        locale: english,
      );
      expect(field(tester).controller!.text, 'Bashful (neutral)');
    });
  });

  testWidgets('outras listas com parênteses não viram natureza', (
    tester,
  ) async {
    await pumpSelect(
      tester,
      platform: TargetPlatform.linux,
      choices: const [
        Choice(value: 'es', label: 'Espanhol (Espanha)'),
        Choice(value: 'es-419', label: 'Espanhol (América Latina)'),
      ],
      value: 'es',
    );
    final controller = field(tester).controller!;
    final span = controller.buildTextSpan(
      context: tester.element(find.byType(TextField)),
      withComposing: false,
    );
    expect(span.children, isNull);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'latina');
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsOneWidget);
  });
}
