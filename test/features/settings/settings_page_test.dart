import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/l10n/app_language.dart';
import 'package:ishinydex/features/settings/presentation/settings_page.dart';

import '../../helpers/helpers.dart';

void main() {
  languageTests();

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

/// Abre Ajustes no app completo, pelo ícone da navegação (o nome muda com
/// o idioma).
Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings_outlined).first);
  await tester.pumpAndSettle();
}

void languageTests() {
  testWidgets('Preferências → Idioma: Automático segue o aparelho', (
    tester,
  ) async {
    await pumpWidgetApp(tester, const SettingsPage());
    expect(find.text('Preferências'), findsOneWidget);
    expect(find.text('Idioma'), findsOneWidget);
    expect(find.text('Automático (Português)'), findsOneWidget);
  });

  testWidgets('celular: a folha troca para English na hora e guarda', (
    tester,
  ) async {
    final storage = InMemoryLanguageStorage(AppLanguage.pt);
    await pumpFullApp(tester, size: compactSize, languageStorage: storage);
    await openSettings(tester);
    expect(find.text('Português (Brasil)'), findsOneWidget);
    await tester.tap(find.text('Idioma'));
    await tester.pumpAndSettle();
    // O aparelho dos testes é en-US: o Automático usaria o inglês.
    expect(find.text('Segue o idioma do aparelho (English)'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    // O título e o destino da navegação.
    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(await storage.read(), AppLanguage.en);
  });

  testWidgets('PC: diálogo; Cancel não muda; Automático volta ao aparelho', (
    tester,
  ) async {
    final storage = InMemoryLanguageStorage(AppLanguage.en);
    await pumpFullApp(
      tester,
      language: AppLanguage.en,
      languageStorage: storage,
    );
    await openSettings(tester);
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(await storage.read(), AppLanguage.en);

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Automatic'));
    await tester.pumpAndSettle();
    expect(find.text('Automatic (English)'), findsOneWidget);
    expect(await storage.read(), AppLanguage.system);
  });
}
