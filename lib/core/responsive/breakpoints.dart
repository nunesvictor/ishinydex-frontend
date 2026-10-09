import 'package:flutter/widgets.dart';

/// Classes de largura de janela (Material 3).
enum WindowSize {
  compact,
  medium,
  expanded,

  /// Monitores largos (PC): cabem rail estendido e lista de boxes sem
  /// apertar a grade.
  large;

  /// 840, e não os 600 do Material 3 para o *medium*: é onde o M3 passa de
  /// um painel para dois. Assim o iPad em retrato (mini 744, A16/Air/Pro 11"
  /// 820–834) fica com o layout do iPhone, e os painéis só aparecem na
  /// paisagem.
  static const mediumMin = 840.0;
  static const expandedMin = 1024.0;
  static const largeMin = 1440.0;

  static WindowSize fromWidth(double width) {
    if (width >= largeMin) return WindowSize.large;
    if (width >= expandedMin) return WindowSize.expanded;
    if (width >= mediumMin) return WindowSize.medium;
    return WindowSize.compact;
  }

  static WindowSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  bool get isCompact => this == WindowSize.compact;

  /// Expandido ou maior (layouts de PC).
  bool get isExpanded => index >= WindowSize.expanded.index;
  bool get isLarge => this == WindowSize.large;
}

/// Desktop (mouse e teclado físico) × mobile (toque).
///
/// Depende da plataforma, não da largura: um navegador desktop estreito
/// continua tendo teclado. Na web, `Theme.of(context).platform` reflete o
/// sistema do navegador (o Safari do iPhone é [TargetPlatform.iOS]).
bool isDesktopPlatform(TargetPlatform platform) => switch (platform) {
  TargetPlatform.linux ||
  TargetPlatform.macOS ||
  TargetPlatform.windows => true,
  TargetPlatform.android ||
  TargetPlatform.iOS ||
  TargetPlatform.fuchsia => false,
};
