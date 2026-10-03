import 'package:flutter/material.dart';
import 'package:ishinydex/core/utils/format.dart';

/// Ícone do Pokémon HOME para uma característica do espécime (shiny, alfa,
/// veio do GO), no lugar do emoji. Se o asset falhar, volta ao emoji.
///
/// As subclasses só escolhem o asset, o emoji e o rótulo; ter uma classe por
/// marca deixa o uso curto (`ShinyIcon()`) e os testes podem achar cada uma
/// com `find.byType`.
abstract class MarkIcon extends StatelessWidget {
  const MarkIcon({
    required this.asset,
    required this.emoji,
    required this.size,
    required this.semanticLabel,
    this.tinted = false,
    super.key,
  });

  final String asset;

  /// Reserva, se a imagem não carregar.
  final String emoji;

  final double size;

  /// `null` quando um texto ao lado já diz o que é (evita leitura dupla).
  final String? semanticLabel;

  /// Glifo branco (as marcas de origem): pintado com a cor dos ícones ao
  /// redor, para servir no tema claro e no escuro. Os ícones coloridos
  /// (shiny, alfa) ficam como são.
  final bool tinted;

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    width: size,
    height: size,
    color: tinted ? IconTheme.of(context).color : null,
    colorBlendMode: tinted ? BlendMode.srcIn : null,
    semanticLabel: semanticLabel,
    excludeFromSemantics: semanticLabel == null,
    errorBuilder: (_, _, _) => Text(
      emoji,
      semanticsLabel: semanticLabel,
      style: TextStyle(fontSize: size * 0.8),
    ),
  );
}

/// As estrelas de shiny do Pokémon HOME, no lugar do ✨.
class ShinyIcon extends MarkIcon {
  const ShinyIcon({
    super.size = 20,
    super.semanticLabel = 'Shiny',
    @visibleForTesting super.asset = defaultAsset,
    super.key,
  }) : super(emoji: shinyEmoji);

  static const defaultAsset = 'assets/icons/shiny.png';
}

/// Ícone de alfa do Pokémon HOME (o selo vermelho de Legends: Arceus), no
/// lugar do 💢.
class AlphaIcon extends MarkIcon {
  const AlphaIcon({
    super.size = 20,
    super.semanticLabel = 'Alfa',
    @visibleForTesting super.asset = defaultAsset,
    super.key,
  }) : super(emoji: alphaEmoji);

  static const defaultAsset = 'assets/icons/alpha.png';
}

/// A marca de origem do Pokémon GO, no lugar do 📱, para "veio do GO".
class GoIcon extends MarkIcon {
  const GoIcon({
    super.size = 20,
    super.semanticLabel = 'Pokémon GO',
    @visibleForTesting super.asset = defaultAsset,
    super.key,
  }) : super(emoji: goEmoji, tinted: true);

  /// O mesmo arquivo de `OriginMark.go.asset` (aqui como constante).
  static const defaultAsset = 'assets/origin_marks/go.png';
}
