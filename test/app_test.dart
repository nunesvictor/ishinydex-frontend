import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/app.dart';
import 'package:ishinydex/core/theme/app_theme.dart';

import 'helpers/helpers.dart';

void main() {
  test('construtor do app registrado na cobertura', () {
    // Os testes usam `const IShinyDexApp()`, criado em tempo de compilação:
    // a cobertura às vezes não marca a linha do construtor (no CI, 99.97%).
    // Instanciar sem const garante que ela execute.
    // ignore: prefer_const_constructors
    expect(IShinyDexApp(), isA<ConsumerWidget>());
  });

  test('noRetry desliga o retry automático', () {
    expect(noRetry(0, Exception()), isNull);
  });

  testWidgets('theme-color da web segue o tema em uso (barra do iPhone)', (
    tester,
  ) async {
    final colors = <int>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setApplicationSwitcherDescription') {
          colors.add((call.arguments as Map)['primaryColor'] as int);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpFullApp(tester);
    expect(colors.last, AppTheme.light().colorScheme.surface.toARGB32());

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpAndSettle();
    expect(colors.last, AppTheme.dark().colorScheme.surface.toARGB32());
  });
}
