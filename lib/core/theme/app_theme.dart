import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ishinydex/core/theme/app_palette.dart';

/// Tema Material 3 compartilhado por web e iOS, montado a partir de uma
/// [AppPalette] (por padrão, a Clássico).
abstract final class AppTheme {
  /// A família declarada no `pubspec.yaml`.
  static const fontFamily = 'Roboto';

  static ThemeData light([AppPalette palette = AppPalette.classic]) =>
      _build(palette.light, Brightness.light);

  static ThemeData dark([AppPalette palette = AppPalette.classic]) =>
      _build(palette.dark, Brightness.dark);

  static ThemeData _build(PaletteColors colors, Brightness brightness) {
    final scheme = colors.scheme(brightness);
    return ThemeData(
      colorScheme: scheme,
      extensions: [colors.extension],
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
          // Sem isto, com elevação o Material 3 pinta a barra com o
          // `surfaceTint` e ela escurece do mesmo jeito (#215).
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 1,
          shadowColor: scheme.outlineVariant,
        )
      : null;
}
