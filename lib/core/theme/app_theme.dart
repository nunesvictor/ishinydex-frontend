import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Tema Material 3 compartilhado por web e iOS.
abstract final class AppTheme {
  static const seed = Color(0xFF3F51B5);

  /// A família declarada no `pubspec.yaml`.
  static const fontFamily = 'Roboto';

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      // A Roboto do app (`assets/fonts/`, #212), a mesma em todas as
      // plataformas.
      fontFamily: fontFamily,
      appBarTheme: appBarTheme(scheme, defaultTargetPlatform),
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      // Padrão dos campos de formulário: contorno com cantos de 12 (os
      // estados de foco e erro herdam o formato). Buscas usam `SearchField`.
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// A barra de título (#205). No iOS (também no navegador do iPhone), ela
  /// não muda de cor quando a lista rola por baixo: fica igual à faixa da
  /// hora, que o PWA não consegue trocar de cor com o app aberto. Ganha só
  /// uma sombra de 1 px, a linha fina do iOS. Nas outras plataformas, fica
  /// o padrão do Material 3 (a barra muda de tom).
  @visibleForTesting
  static AppBarThemeData? appBarTheme(
    ColorScheme scheme,
    TargetPlatform platform,
  ) => platform == TargetPlatform.iOS
      ? AppBarThemeData(
          // Com a cor definida, o Material 3 não troca pela
          // `surfaceContainer` ao rolar.
          backgroundColor: scheme.surface,
          scrolledUnderElevation: 1,
          shadowColor: scheme.outlineVariant,
        )
      : null;
}
