import 'package:flutter/widgets.dart';

/// Classes de largura de janela (Material 3).
enum WindowSize {
  compact,
  medium,
  expanded;

  static const mediumMin = 600.0;
  static const expandedMin = 1024.0;

  static WindowSize fromWidth(double width) {
    if (width >= expandedMin) return WindowSize.expanded;
    if (width >= mediumMin) return WindowSize.medium;
    return WindowSize.compact;
  }

  static WindowSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  bool get isCompact => this == WindowSize.compact;
  bool get isExpanded => this == WindowSize.expanded;
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
