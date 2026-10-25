import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/widgets/shiny_charm_icon.dart';
import 'package:ishinydex/fake/fake_backend.dart';

import '../../helpers/helpers.dart';

void main() {
  testWidgets('o sprite do item; sem ele, um brilho com o mesmo nome', (
    tester,
  ) async {
    await pumpWidgetApp(tester, const Center(child: ShinyCharmIcon()));
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as NetworkImage).url,
      endsWith('/items/shiny-charm.png'),
    );
    expect(image.filterQuality, FilterQuality.none);
    // Nos testes, a rede falha: fica o ícone de reserva.
    expect(find.byIcon(Icons.auto_awesome), findsOne);
    expect(find.bySemanticsLabel('Shiny Charm'), findsWidgets);
    expect(find.byTooltip('Shiny Charm'), findsOne);
  });

  for (final size in [compactSize, expandedSize]) {
    testWidgets('Meus saves: o Charm só no save que o tem '
        '(#317, ${size.width.toInt()}px)', (tester) async {
      final backend = FakeBackend.seeded();
      final saves = await backend.fetchSaves();
      await backend.updateSave(saves.first.id, hasShinyCharm: true);
      await pumpFullApp(tester, size: size, backend: backend);
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
          .read(routerProvider)
          .go(Routes.saves);
      await tester.pumpAndSettle();
      expect(find.byType(ShinyCharmIcon), findsOne);
      expect(
        find.descendant(
          of: find.byKey(ValueKey('save-${saves.first.id}')),
          matching: find.byType(ShinyCharmIcon),
        ),
        findsOne,
      );
    });
  }
}
