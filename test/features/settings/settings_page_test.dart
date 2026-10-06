import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/features/settings/data/date_format_storage.dart';
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
    testWidgets('formato da data de captura (${size.width.toInt()}px)', (
      tester,
    ) async {
      final storage = InMemoryDateFormatStorage();
      await pumpWidgetApp(
        tester,
        const SettingsPage(),
        size: size,
        dateFormat: storage,
      );
      await tester.pumpAndSettle();
      expect(find.text('Pokémon HOME (mm/dd/aaaa)'), findsOneWidget);
      expect(find.text('Ex.: 09/23/2024'), findsOneWidget);
      expect(find.text('Do idioma do app (dd/mm/aaaa)'), findsOneWidget);

      await tester.tap(find.text('Do idioma do app (dd/mm/aaaa)'));
      await tester.pumpAndSettle();
      expect(await storage.read(), CaptureDateFormat.locale);
    });
  }
}
