import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Uma seção com o [header] preso no topo da rolagem enquanto ela passa
/// (como as boxes do Faltam), dentro de qualquer `Scrollable` (a ficha
/// rola inteira, sem lista própria).
///
/// O cabeçalho fica no lugar dele na coluna (para ocupar o espaço) e uma
/// cópia desenhada por cima desce junto com a rolagem até o fim da seção,
/// com sombra enquanto está presa.
class StickySection extends StatefulWidget {
  const StickySection({
    required this.header,
    required this.children,
    super.key,
  });

  final Widget header;
  final List<Widget> children;

  @override
  State<StickySection> createState() => _StickySectionState();
}

class _StickySectionState extends State<StickySection> {
  final GlobalKey _headerKey = GlobalKey();
  ScrollPosition? _position;
  double _shift = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _position?.removeListener(_update);
    _position = Scrollable.maybeOf(context)?.position;
    _position?.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    _position?.removeListener(_update);
    super.dispose();
  }

  /// Quanto o cabeçalho desce: o que a seção já subiu além do topo da
  /// rolagem, até o fim dela.
  void _update() {
    if (!mounted) return;
    final section = context.findRenderObject() as RenderBox?;
    final viewport = Scrollable.maybeOf(context)?.context.findRenderObject();
    final header = _headerKey.currentContext?.size;
    if (section == null || viewport == null || header == null) return;
    final top = section.localToGlobal(Offset.zero, ancestor: viewport).dy;
    final shift = math
        .min(
          math.max(0, -top),
          math.max(0, section.size.height - header.height),
        )
        .toDouble();
    if (shift != _shift) setState(() => _shift = shift);
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // O lugar do cabeçalho; o visível é o de cima, que se move.
          Visibility.maintain(
            visible: false,
            child: KeyedSubtree(key: _headerKey, child: widget.header),
          ),
          ...widget.children,
        ],
      ),
      Positioned(
        top: _shift,
        left: 0,
        right: 0,
        child: Material(
          key: const ValueKey('sticky-header'),
          elevation: _shift > 0 ? 2 : 0,
          child: widget.header,
        ),
      ),
    ],
  );
}
