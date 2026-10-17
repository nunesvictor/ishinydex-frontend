import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      appBarTheme: appBarTheme(colors, brightness),
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
      // Os avisos embaixo da tela (#278): flutuantes, acima da barra de
      // navegação, com cantos arredondados. As cores vêm das `inverse*` da
      // paleta.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// A barra de título: grafite nos dois temas e em todas as plataformas
  /// (#290), com o título e os ícones em branco. A cor nunca muda, nem ao
  /// rolar a lista por baixo (#205/#215): é a mesma da barra de status do
  /// iPhone, que o PWA não consegue trocar com o app aberto. No escuro, uma
  /// linha de 1 px separa a barra do fundo, que é quase da mesma cor.
  @visibleForTesting
  static AppBarThemeData appBarTheme(
    PaletteColors colors,
    Brightness brightness,
  ) => AppBarThemeData(
    backgroundColor: colors.topBar,
    foregroundColor: colors.onTopBar,
    iconTheme: IconThemeData(color: colors.onTopBar),
    actionsIconTheme: IconThemeData(color: colors.onTopBar),
    // Sem isto, ao rolar, o Material 3 pinta a barra com o `surfaceTint`.
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
    // Ícones da barra de status claros (Android e iOS nativos).
    systemOverlayStyle: SystemUiOverlayStyle.light,
    shape: brightness == Brightness.dark
        ? Border(bottom: BorderSide(color: colors.outlineVariant))
        : null,
  );

  /// Botão de texto dentro da barra de título ("Salvar", "Cancelar"): em
  /// branco, porque o vermelho das ações não lê sobre o grafite (#290).
  static ButtonStyle topBarTextButton(BuildContext context) =>
      TextButton.styleFrom(foregroundColor: AppColors.of(context).onTopBar);
}
