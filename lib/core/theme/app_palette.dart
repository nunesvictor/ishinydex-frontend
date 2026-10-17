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
      inverseSurface: Color(0xFF2B2929),
      onInverseSurface: Color(0xFFF4F0F0),
      inversePrimary: Color(0xFFFF8A80),
      shiny: Color(0xFFC28E00),
      success: Color(0xFF2E7D32),
      huntBadge: Color(0xFFC62828),
      onHuntBadge: Color(0xFFFFFFFF),
      topBar: _topBar,
      onTopBar: _onTopBar,
      onTopBarVariant: _onTopBarVariant,
      topBarField: _topBarField,
      onTopBarField: _onTopBarField,
      topBarAccent: _topBarAccent,
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
      inverseSurface: Color(0xFFE6E1E1),
      onInverseSurface: Color(0xFF1C1B1B),
      inversePrimary: Color(0xFFB71C1C),
      shiny: Color(0xFFFFCB05),
      success: Color(0xFF81C784),
      // No escuro, o selo da caçada fica amarelo, como antes da paleta.
      huntBadge: Color(0xFFFFCB05),
      onHuntBadge: Color(0xFF1C1B1B),
      topBar: _topBar,
      onTopBar: _onTopBar,
      onTopBarVariant: _onTopBarVariant,
      topBarField: _topBarField,
      onTopBarField: _onTopBarField,
      topBarAccent: _topBarAccent,
    ),
  );

  // O topo grafite (#290), igual nos dois temas: a barra de status do
  // iPhone não troca de cor com o app aberto (bug do WebKit), então a cor
  // do topo nunca muda.
  static const _topBar = Color(0xFF1C1B1B);
  static const _onTopBar = Color(0xFFFFFFFF);
  static const _onTopBarVariant = Color(0xFFCAC4C4);
  static const _topBarField = Color(0xFF353333);
  static const _onTopBarField = Color(0xFFE6E1E1);
  static const _topBarAccent = Color(0xFFFF8A80);
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
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.inversePrimary,
    required this.shiny,
    required this.success,
    required this.huntBadge,
    required this.onHuntBadge,
    required this.topBar,
    required this.onTopBar,
    required this.onTopBarVariant,
    required this.topBarField,
    required this.onTopBarField,
    required this.topBarAccent,
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

  /// Os avisos embaixo da tela (SnackBar, #278): o contrário do tema, com a
  /// ação no vermelho do outro lado (grafite com vermelho claro no tema
  /// claro; claro com vermelho escuro no escuro).
  final Color inverseSurface;
  final Color onInverseSurface;
  final Color inversePrimary;

  /// As cores fora do `ColorScheme` (ver [AppColors]).
  final Color shiny;
  final Color success;
  final Color huntBadge;
  final Color onHuntBadge;

  /// O topo do app (#290): a barra de status e a de título, numa cor fixa.
  /// O título e os ícones ficam em [onTopBar]; textos de apoio (o progresso
  /// do dex) em [onTopBarVariant]; campos dentro da barra (a busca do dex)
  /// em [topBarField], com o texto em [onTopBarField] e o cursor e a borda
  /// em [topBarAccent].
  final Color topBar;
  final Color onTopBar;
  final Color onTopBarVariant;
  final Color topBarField;
  final Color onTopBarField;
  final Color topBarAccent;

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
        inverseSurface: inverseSurface,
        onInverseSurface: onInverseSurface,
        inversePrimary: inversePrimary,
        // Sem a tinta vermelha nas superfícies elevadas.
        surfaceTint: onSurface,
      );

  AppColors get extension => AppColors(
    shiny: shiny,
    success: success,
    huntBadge: huntBadge,
    onHuntBadge: onHuntBadge,
    topBar: topBar,
    onTopBar: onTopBar,
    onTopBarVariant: onTopBarVariant,
    topBarField: topBarField,
    onTopBarField: onTopBarField,
    topBarAccent: topBarAccent,
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
    required this.topBar,
    required this.onTopBar,
    required this.onTopBarVariant,
    required this.topBarField,
    required this.onTopBarField,
    required this.topBarAccent,
  });

  /// O amarelo do shiny (textos e destaques ligados a ele).
  final Color shiny;

  /// Concluído: depositado, dex completo.
  final Color success;

  /// O selo de caçada em andamento no slot.
  final Color huntBadge;
  final Color onHuntBadge;

  /// O topo grafite (#290; ver [PaletteColors.topBar]).
  final Color topBar;
  final Color onTopBar;
  final Color onTopBarVariant;
  final Color topBarField;
  final Color onTopBarField;
  final Color topBarAccent;

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
    Color? topBar,
    Color? onTopBar,
    Color? onTopBarVariant,
    Color? topBarField,
    Color? onTopBarField,
    Color? topBarAccent,
  }) => AppColors(
    shiny: shiny ?? this.shiny,
    success: success ?? this.success,
    huntBadge: huntBadge ?? this.huntBadge,
    onHuntBadge: onHuntBadge ?? this.onHuntBadge,
    topBar: topBar ?? this.topBar,
    onTopBar: onTopBar ?? this.onTopBar,
    onTopBarVariant: onTopBarVariant ?? this.onTopBarVariant,
    topBarField: topBarField ?? this.topBarField,
    onTopBarField: onTopBarField ?? this.onTopBarField,
    topBarAccent: topBarAccent ?? this.topBarAccent,
  );

  @override
  AppColors lerp(AppColors? other, double t) => other == null
      ? this
      : AppColors(
          shiny: Color.lerp(shiny, other.shiny, t)!,
          success: Color.lerp(success, other.success, t)!,
          huntBadge: Color.lerp(huntBadge, other.huntBadge, t)!,
          onHuntBadge: Color.lerp(onHuntBadge, other.onHuntBadge, t)!,
          topBar: Color.lerp(topBar, other.topBar, t)!,
          onTopBar: Color.lerp(onTopBar, other.onTopBar, t)!,
          onTopBarVariant: Color.lerp(
            onTopBarVariant,
            other.onTopBarVariant,
            t,
          )!,
          topBarField: Color.lerp(topBarField, other.topBarField, t)!,
          onTopBarField: Color.lerp(onTopBarField, other.onTopBarField, t)!,
          topBarAccent: Color.lerp(topBarAccent, other.topBarAccent, t)!,
        );
}
