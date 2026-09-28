import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
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
}
