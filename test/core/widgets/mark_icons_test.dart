import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/utils/origin_mark.dart';
import 'package:ishinydex/core/widgets/mark_icons.dart';

Future<void> pumpIcon(WidgetTester tester, Widget icon) => tester.pumpWidget(
  MaterialApp(
    home: IconTheme(
      data: const IconThemeData(color: Colors.teal),
      child: Center(child: icon),
    ),
  ),
);

void main() {
  final cases = <(String, MarkIcon, MarkIcon, String, String)>[
    (
      'shiny',
      const ShinyIcon(size: 32),
      const ShinyIcon(asset: 'assets/icons/nao-existe.png'),
      ShinyIcon.defaultAsset,
      shinyEmoji,
    ),
    (
      'alfa',
      const AlphaIcon(size: 32),
      const AlphaIcon(asset: 'assets/icons/nao-existe.png'),
      AlphaIcon.defaultAsset,
      alphaEmoji,
    ),
    (
      'GO',
      const GoIcon(size: 32),
      const GoIcon(asset: 'assets/icons/nao-existe.png'),
      GoIcon.defaultAsset,
      goEmoji,
    ),
  ];

  for (final (name, icon, broken, asset, emoji) in cases) {
    testWidgets('$name: mostra o asset do HOME, com rótulo', (tester) async {
      await pumpIcon(tester, icon);
      await tester.pumpAndSettle();

      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, asset);
      expect(image.width, 32);
      expect(find.bySemanticsLabel(icon.semanticLabel!), findsOneWidget);
      expect(find.text(emoji), findsNothing);
    });

    testWidgets('$name: asset que falha volta ao emoji $emoji', (tester) async {
      await pumpIcon(tester, broken);
      await tester.pumpAndSettle();

      expect(find.text(emoji), findsOneWidget);
      expect(find.bySemanticsLabel(broken.semanticLabel!), findsOneWidget);
    });
  }

  testWidgets('sem rótulo, fica fora da acessibilidade', (tester) async {
    await pumpIcon(tester, const AlphaIcon(semanticLabel: null));
    await tester.pumpAndSettle();

    expect(tester.widget<Image>(find.byType(Image)).excludeFromSemantics, true);
  });

  testWidgets('só a marca do GO (glifo branco) leva a cor dos ícones', (
    tester,
  ) async {
    await pumpIcon(tester, const Row(children: [GoIcon(), ShinyIcon()]));
    await tester.pumpAndSettle();

    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images[0].color, Colors.teal);
    expect(images[0].colorBlendMode, BlendMode.srcIn);
    expect(images[1].color, isNull);
  });

  test('a marca do GO é a mesma das marcas de origem', () {
    expect(GoIcon.defaultAsset, OriginMark.go.asset);
  });
}
