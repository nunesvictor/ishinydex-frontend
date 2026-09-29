import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/features/settings/data/date_format_storage.dart';
import 'package:ishinydex/features/settings/presentation/settings_page.dart';

import '../../helpers/helpers.dart';

void main() {
  testWidgets('mostra a URL da API real', (tester) async {
    await pumpWidgetApp(
      tester,
      const SettingsPage(),
      overrides: [
        envProvider.overrideWithValue(
          const Env(apiBaseUrl: 'http://server/api', useFakeApi: false),
        ),
      ],
    );
    expect(find.text('http://server/api'), findsOneWidget);
  });

  testWidgets('sair com confirmação volta para o login', (tester) async {
    await pumpFullApp(tester, size: compactSize);
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Modo demonstração (dados fake)'), findsOneWidget);

    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Servidor'), findsOneWidget);

    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Sair'));
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsOneWidget);
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
