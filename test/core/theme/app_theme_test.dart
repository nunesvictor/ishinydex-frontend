import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/theme/app_theme.dart';

void main() {
  test('temas claro e escuro em Material 3', () {
    expect(AppTheme.light().colorScheme.brightness, Brightness.light);
    expect(AppTheme.dark().colorScheme.brightness, Brightness.dark);
    expect(
      AppTheme.light().pageTransitionsTheme.builders[TargetPlatform.iOS],
      isA<CupertinoPageTransitionsBuilder>(),
    );
  });

  test('barra de título: no iOS não muda de cor ao rolar (#205)', () {
    final scheme = AppTheme.light().colorScheme;
    final ios = AppTheme.appBarTheme(scheme, TargetPlatform.iOS)!;
    expect(ios.backgroundColor, scheme.surface);
    expect(ios.scrolledUnderElevation, 1);
    expect(ios.shadowColor, scheme.outlineVariant);
    expect(AppTheme.appBarTheme(scheme, TargetPlatform.android), isNull);
  });
}
