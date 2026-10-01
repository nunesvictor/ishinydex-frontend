import 'package:flutter/material.dart';
import 'package:ishinydex/core/utils/format.dart';

/// Ícone de alfa do Pokémon HOME (o selo vermelho de Legends: Arceus), no
/// lugar do emoji 💢. Se o asset falhar, volta ao emoji.
class AlphaIcon extends StatelessWidget {
  const AlphaIcon({
    this.size = 20,
    this.semanticLabel = 'Alfa',
    @visibleForTesting this.asset = defaultAsset,
    super.key,
  });

  static const defaultAsset = 'assets/icons/alpha.png';

  final String asset;

  final double size;

  /// `null` quando um texto ao lado já diz "Alfa" (evita leitura dupla).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    width: size,
    height: size,
    semanticLabel: semanticLabel,
    excludeFromSemantics: semanticLabel == null,
    errorBuilder: (_, _, _) => Text(
      alphaEmoji,
      semanticsLabel: semanticLabel,
      style: TextStyle(fontSize: size * 0.8),
    ),
  );
}
