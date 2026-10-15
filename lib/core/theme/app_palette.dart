import 'package:flutter/material.dart';

/// As cores de um tema do app, no claro e no escuro (#162).
///
/// A paleta é dado, não código: o `AppTheme` monta o `ThemeData` a partir
/// de qualquer [AppPalette], e os widgets só leem as cores do tema
/// (`ColorScheme` e [AppColors]). Um tema novo (#244, #245) é só mais uma
/// constante aqui.
@immutable
class AppPalette {
  const AppPalette({required this.id, required this.light, required this.dark});

  /// Identificador estável (para guardar a escolha, quando houver temas).
  final String id;
  final PaletteColors light;
  final PaletteColors dark;

  PaletteColors of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// C · Clássico, a identidade padrão (aprovada em 2026-10-14): base
  /// neutra (branco e grafite), vermelho só no que é ação; o amarelo fica
  /// para o shiny.
  static const classic = AppPalette(
    id: 'classic',
    light: PaletteColors(
      primary: Color(0xFFC62828),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFFFDAD6),
      onPrimaryContainer: Color(0xFF410002),
      secondaryContainer: Color(0xFFE8E2E2),
      onSecondaryContainer: Color(0xFF1C1B1B),
      surface: Color(0xFFFAFAFA),
      onSurface: Color(0xFF1C1B1B),
      onSurfaceVariant: Color(0xFF4A4646),
      outline: Color(0xFFAFA9A9),
      outlineVariant: Color(0xFFE3E0E0),
      surfaceContainerLow: Color(0xFFF4F2F2),
      surfaceContainer: Color(0xFFF0EEEE),
      surfaceContainerHigh: Color(0xFFEEECEC),
      surfaceContainerHighest: Color(0xFFE6E1E1),
      shiny: Color(0xFFC28E00),
      success: Color(0xFF2E7D32),
      huntBadge: Color(0xFFC62828),
      onHuntBadge: Color(0xFFFFFFFF),
    ),
    dark: PaletteColors(
      primary: Color(0xFFFF8A80),
      onPrimary: Color(0xFF5F0010),
      primaryContainer: Color(0xFF8C1D18),
      onPrimaryContainer: Color(0xFFFFDAD6),
      secondaryContainer: Color(0xFF3A3636),
      onSecondaryContainer: Color(0xFFE6E1E1),
      surface: Color(0xFF131313),
      onSurface: Color(0xFFE6E1E1),
      onSurfaceVariant: Color(0xFFCAC4C4),
      outline: Color(0xFF6F6A6A),
      outlineVariant: Color(0xFF363434),
      surfaceContainerLow: Color(0xFF1C1B1B),
      surfaceContainer: Color(0xFF1E1E1E),
      surfaceContainerHigh: Color(0xFF242323),
      surfaceContainerHighest: Color(0xFF353333),
      shiny: Color(0xFFFFCB05),
      success: Color(0xFF81C784),
      // No escuro, o selo da caçada fica amarelo, como antes da paleta.
      huntBadge: Color(0xFFFFCB05),
      onHuntBadge: Color(0xFF1C1B1B),
    ),
  );
}

/// As cores de um lado (claro ou escuro) de uma [AppPalette].
@immutable
class PaletteColors {
  const PaletteColors({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.surface,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.shiny,
    required this.success,
    required this.huntBadge,
    required this.onHuntBadge,
  });

  /// Ações: botões, aba e slot selecionados, progresso.
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;

  /// Pílula da navegação, filtros marcados e segmentos escolhidos.
  final Color secondaryContainer;
  final Color onSecondaryContainer;

  final Color surface;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;
  final Color outlineVariant;

  /// Slot faltante (o mais claro) até o registrado (o mais forte).
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;

  /// As cores fora do `ColorScheme` (ver [AppColors]).
  final Color shiny;
  final Color success;
  final Color huntBadge;
  final Color onHuntBadge;

  /// O `ColorScheme` do Material 3: o que a paleta não define (secundária,
  /// terciária, erro...) sai do `fromSeed` com a [primary], na variante
  /// neutra, para não brigar com a base cinza.
  ColorScheme scheme(Brightness brightness) =>
      ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.neutral,
      ).copyWith(
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        surface: surface,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        outline: outline,
        outlineVariant: outlineVariant,
        surfaceContainerLowest: surface,
        surfaceContainerLow: surfaceContainerLow,
        surfaceContainer: surfaceContainer,
        surfaceContainerHigh: surfaceContainerHigh,
        surfaceContainerHighest: surfaceContainerHighest,
        // Sem a tinta vermelha nas superfícies elevadas.
        surfaceTint: onSurface,
      );

  AppColors get extension => AppColors(
    shiny: shiny,
    success: success,
    huntBadge: huntBadge,
    onHuntBadge: onHuntBadge,
  );
}

/// As cores do app que não têm papel no `ColorScheme` do Material 3. Ficam
/// no tema como `ThemeExtension`, então trocam com o tema claro/escuro (e,
/// no futuro, com o tema escolhido).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.shiny,
    required this.success,
    required this.huntBadge,
    required this.onHuntBadge,
  });

  /// O amarelo do shiny (textos e destaques ligados a ele).
  final Color shiny;

  /// Concluído: depositado, dex completo.
  final Color success;

  /// O selo de caçada em andamento no slot.
  final Color huntBadge;
  final Color onHuntBadge;

  /// As cores do tema em volta de [context].
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ??
      AppPalette.classic.of(Theme.of(context).brightness).extension;

  @override
  AppColors copyWith({
    Color? shiny,
    Color? success,
    Color? huntBadge,
    Color? onHuntBadge,
  }) => AppColors(
    shiny: shiny ?? this.shiny,
    success: success ?? this.success,
    huntBadge: huntBadge ?? this.huntBadge,
    onHuntBadge: onHuntBadge ?? this.onHuntBadge,
  );

  @override
  AppColors lerp(AppColors? other, double t) => other == null
      ? this
      : AppColors(
          shiny: Color.lerp(shiny, other.shiny, t)!,
          success: Color.lerp(success, other.success, t)!,
          huntBadge: Color.lerp(huntBadge, other.huntBadge, t)!,
          onHuntBadge: Color.lerp(onHuntBadge, other.onHuntBadge, t)!,
        );
}
