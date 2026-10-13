import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/features/settings/presentation/settings_page.dart';

import '../../helpers/helpers.dart';

void main() {
  testWidgets('mostra a versão; sem "Servidor" nem "Sair"', (tester) async {
    await pumpWidgetApp(
      tester,
      const SettingsPage(),
      overrides: [
        envProvider.overrideWithValue(const Env(appVersion: 'v2.0.0')),
      ],
    );
    expect(find.text('Versão v2.0.0'), findsOneWidget);
    expect(find.text('Servidor'), findsNothing);
    expect(find.text('Sair'), findsNothing);
  });

  for (final size in [compactSize, expandedSize]) {
    testWidgets('sem a escolha do formato da data (#208, '
        '${size.width.toInt()}px)', (tester) async {
      await pumpWidgetApp(tester, const SettingsPage(), size: size);
      await tester.pumpAndSettle();
      expect(find.text('Formato da data de captura'), findsNothing);
    });
  }
}
