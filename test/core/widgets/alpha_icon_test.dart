import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/alpha_icon.dart';

Future<void> pumpIcon(WidgetTester tester, AlphaIcon icon) =>
    tester.pumpWidget(MaterialApp(home: Center(child: icon)));

void main() {
  testWidgets('mostra o asset do HOME, com rótulo "Alfa"', (tester) async {
    await pumpIcon(tester, const AlphaIcon(size: 32));
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, AlphaIcon.defaultAsset);
    expect(image.width, 32);
    expect(find.bySemanticsLabel('Alfa'), findsOneWidget);
    expect(find.text(alphaEmoji), findsNothing);
  });

  testWidgets('sem rótulo, fica fora da acessibilidade', (tester) async {
    await pumpIcon(tester, const AlphaIcon(semanticLabel: null));
    await tester.pumpAndSettle();

    expect(tester.widget<Image>(find.byType(Image)).excludeFromSemantics, true);
  });

  testWidgets('asset que falha volta ao emoji 💢', (tester) async {
    await pumpIcon(
      tester,
      const AlphaIcon(asset: 'assets/icons/nao-existe.png'),
    );
    await tester.pumpAndSettle();

    expect(find.text(alphaEmoji), findsOneWidget);
    expect(find.bySemanticsLabel('Alfa'), findsOneWidget);
  });
}
