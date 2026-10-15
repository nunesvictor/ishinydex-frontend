import 'package:flutter/material.dart';
import 'package:ishinydex/core/utils/pokemon_types.dart';

/// O ícone do tipo no Pokémon HOME (`assets/type_icons/`, #230). Um tipo
/// sem ícone (o Stellar) vira um círculo na cor dele.
class TypeIcon extends StatelessWidget {
  const TypeIcon(this.type, {this.size = 18, super.key});

  final String type;
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/type_icons/$type.png',
    width: size,
    height: size,
    // O nome vem ao lado, no chip.
    excludeFromSemantics: true,
    errorBuilder: (_, _, _) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: typeColor(type), shape: BoxShape.circle),
    ),
  );
}

/// O tipo com ícone e nome, na cor dele: o mesmo chip em todo lugar que
/// mostra tipos (ficha da forma, "Tipos em batalha").
class TypeChip extends StatelessWidget {
  const TypeChip(this.type, {this.small = false, super.key});

  final String type;

  /// Nas listas do quadro de tipos, um tamanho menor.
  final bool small;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = small
        ? theme.textTheme.labelMedium
        : theme.textTheme.labelLarge;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: typeColor(type),
        borderRadius: BorderRadius.circular(small ? 6 : 8),
      ),
      child: Padding(
        padding: small
            ? const EdgeInsets.fromLTRB(3, 2, 8, 2)
            : const EdgeInsets.fromLTRB(4, 4, 10, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: small ? 4 : 6,
          children: [
            TypeIcon(type, size: small ? 16 : 20),
            Text(
              typeLabel(type),
              style: style?.copyWith(
                color: typeOnColor(type),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
