import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ishinydex/core/config/env.dart';

/// O Shiny Charm de um save (#317): o sprite do item no PokéAPI, como as
/// Pokébolas. Sem internet e sem o sprite guardado, um brilho do Material
/// no lugar (e não a pokébola de reserva do `PokemonSprite`, que diria
/// outra coisa).
class ShinyCharmIcon extends ConsumerWidget {
  const ShinyCharmIcon({this.size = 20, super.key});

  final double size;

  /// O nome do item no PokéAPI, que também é o que o leitor de tela diz.
  static const label = 'Shiny Charm';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.watch(envProvider).spritesBaseUrl;
    final fallback = Icon(
      Icons.auto_awesome,
      size: size * 0.8,
      color: Theme.of(context).colorScheme.primary,
      semanticLabel: label,
    );
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Image.network(
          '$base/items/shiny-charm.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          // Pixel art: sem suavizar ao ampliar.
          filterQuality: FilterQuality.none,
          semanticLabel: label,
          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }
}
