import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/widgets/game_icon.dart';

Future<void> _pump(WidgetTester tester, Widget icon) async {
  await tester.pumpWidget(MaterialApp(home: Center(child: icon)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ícone do jogo no HOME, com o nome do jogo', (tester) async {
    await _pump(tester, const GameIcon('legends-za', size: 32));

    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/game_icons/legends-za.png',
    );
    expect(image.width, 32);
    expect(find.bySemanticsLabel('Legends: Z-A'), findsOneWidget);
    expect(find.byTooltip('Legends: Z-A'), findsOneWidget);
    expect(find.byType(ColorFiltered), findsNothing);
  });

  testWidgets('em cinza: jogo sem save do usuário', (tester) async {
    await _pump(tester, const GameIcon('scarlet', muted: true));

    expect(find.byType(ColorFiltered), findsOneWidget);
    expect(find.bySemanticsLabel('Scarlet (sem save seu)'), findsOneWidget);
  });

  testWidgets('sem o asset (outra versão): a sigla do jogo', (tester) async {
    await _pump(tester, const GameIcon('lets-go-pikachu'));

    expect(find.text('LG'), findsOneWidget);
    expect(find.bySemanticsLabel("Let's Go Pikachu"), findsOneWidget);
  });
}
