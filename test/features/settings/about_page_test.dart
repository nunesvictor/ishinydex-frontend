import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/features/settings/presentation/about_page.dart';

import '../../helpers/helpers.dart';

void main() {
  testWidgets('servidor: versão, endereço do projeto e aviso legal', (
    tester,
  ) async {
    await pumpWidgetApp(
      tester,
      const AboutPage(),
      overrides: [
        envProvider.overrideWithValue(
          const Env(
            apiBaseUrl: 'http://server/api',
            useFakeApi: false,
            appVersion: 'v2.0.0',
          ),
        ),
      ],
    );
    expect(find.text('Versão v2.0.0'), findsOneWidget);
    expect(find.text(projectUrl), findsOneWidget);
    expect(
      find.textContaining('servidor configurado (http://server/api)'),
      findsOneWidget,
    );
    expect(find.textContaining('The Pokémon Company'), findsOneWidget);
    expect(find.textContaining('demonstração'), findsNothing);
  });

  testWidgets('demonstração: dados fictícios, nada é enviado', (tester) async {
    await pumpWidgetApp(
      tester,
      const AboutPage(),
      overrides: [
        envProvider.overrideWithValue(
          const Env(apiBaseUrl: 'http://x/api', useFakeApi: true),
        ),
      ],
    );
    expect(find.textContaining('Esta é uma demonstração'), findsOneWidget);
    expect(find.textContaining('Nada do que você faz'), findsOneWidget);
    expect(find.textContaining('servidor configurado'), findsNothing);
  });

  testWidgets('Ajustes → Sobre, e o login avisa da demonstração', (
    tester,
  ) async {
    await pumpFullApp(tester, size: compactSize, token: null);
    expect(find.textContaining('qualquer usuário e senha'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'ash');
    await tester.enterText(find.byType(TextFormField).last, 'pikachu');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sobre o iShinyDex'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sobre o iShinyDex'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutPage), findsOneWidget);
    expect(find.textContaining('Esta é uma demonstração'), findsOneWidget);
  });
}
