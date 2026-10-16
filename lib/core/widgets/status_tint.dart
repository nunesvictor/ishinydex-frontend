import 'package:flutter/material.dart';
import 'package:ishinydex/core/web/browser.dart' as browser;

/// Leva a cor do topo do app para a página (#286): o fundo do `body` e o
/// elemento fixo `#status-tint` do `index.html`, de onde o iPhone tira a
/// cor da barra de status no app instalado. Refaz a cada troca de [color]
/// (claro ↔ escuro), o que a `theme-color` sozinha não consegue com o app
/// aberto.
class StatusTint extends StatefulWidget {
  const StatusTint({
    required this.color,
    required this.child,
    this.apply = browser.setTopColor,
    super.key,
  });

  final Color color;
  final Widget child;

  /// Grava a cor na página (`#RRGGBB`); trocado nos testes.
  final ValueChanged<String> apply;

  /// [color] em CSS, sem a transparência.
  static String css(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  @override
  State<StatusTint> createState() => _StatusTintState();
}

class _StatusTintState extends State<StatusTint> {
  @override
  void initState() {
    super.initState();
    widget.apply(StatusTint.css(widget.color));
  }

  @override
  void didUpdateWidget(StatusTint old) {
    super.didUpdateWidget(old);
    if (old.color != widget.color) widget.apply(StatusTint.css(widget.color));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
