import 'package:flutter/material.dart';
import 'package:ishinydex/core/utils/origin_mark.dart';

/// Ícone da marca de origem na cor dos ícones ao redor (no chip, a do
/// chip).
///
/// Os PNGs são glifos brancos: `color` + [BlendMode.srcIn] troca o branco
/// pela cor pedida mantendo a transparência, então o mesmo arquivo funciona
/// no tema claro e no escuro.
class OriginMarkIcon extends StatelessWidget {
  const OriginMarkIcon(this.mark, {this.size = 20, super.key});

  final OriginMark mark;
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    mark.asset,
    width: size,
    height: size,
    color: IconTheme.of(context).color,
    colorBlendMode: BlendMode.srcIn,
    semanticLabel: mark.label,
  );
}

/// Chip "marca de origem" (ícone + nome), com tooltip explicando o que é.
class OriginMarkChip extends StatelessWidget {
  const OriginMarkChip(this.mark, {super.key});

  final OriginMark mark;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Marca de origem',
    child: Chip(
      avatar: ExcludeSemantics(child: OriginMarkIcon(mark)),
      label: Text(mark.label),
    ),
  );
}
