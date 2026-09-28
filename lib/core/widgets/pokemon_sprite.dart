import 'package:flutter/material.dart';

/// Sprite remoto com fallback quando a imagem não existe ou falha.
class PokemonSprite extends StatelessWidget {
  const PokemonSprite({
    required this.url,
    this.size = 64,
    this.semanticLabel,
    super.key,
  });

  final String? url;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final placeholder = Icon(
      Icons.catching_pokemon,
      size: size * 0.6,
      color: Theme.of(context).colorScheme.outlineVariant,
      semanticLabel: semanticLabel,
    );
    final src = url;
    return SizedBox.square(
      dimension: size,
      child: src == null
          ? placeholder
          : Image.network(
              src,
              width: size,
              height: size,
              fit: BoxFit.contain,
              semanticLabel: semanticLabel,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}
