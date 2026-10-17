import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/app.dart';
import 'package:ishinydex/core/theme/app_palette.dart';

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

  testWidgets('theme-color da web: o grafite do topo nos dois temas (#290)', (
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

    final topBar = AppPalette.classic.light.topBar.toARGB32();
    await pumpFullApp(tester);
    expect(colors.last, topBar);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpAndSettle();
    expect(colors.last, topBar);
  });
}
