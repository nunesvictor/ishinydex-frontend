import 'package:flutter/material.dart';

import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';

/// Uma linha no estilo do HOME: pokébola, nome (ou apelido) e os selos em
/// emoji (gênero, shiny, alfa, GO). Substitui os chips de Shiny, Alfa e
/// pokébola, que ocupavam uma linha inteira no celular.
///
/// Recebe valores soltos (e não um `Specimen`) porque o detalhe do slot só
/// tem o resumo do espécime.
class SpecimenHeadline extends StatelessWidget {
  const SpecimenHeadline({
    required this.name,
    this.pokeballSpriteUrl,
    this.pokeballLabel,
    this.gender,
    this.isShiny = false,
    this.isAlpha = false,
    this.isFromGo = false,
    this.style,
    this.center = false,
    super.key,
  });

  final String name;
  final String? pokeballSpriteUrl;
  final String? pokeballLabel;
  final String? gender;
  final bool isShiny;
  final bool isAlpha;
  final bool isFromGo;

  /// Estilo do nome e dos emojis; o tamanho da pokébola acompanha a fonte.
  final TextStyle? style;

  /// Centraliza a linha (detalhes); na lista, fica à esquerda.
  final bool center;

  @override
  Widget build(BuildContext context) {
    final textStyle = DefaultTextStyle.of(context).style.merge(style);
    final ballSize = (textStyle.fontSize ?? 14) * 1.3;
    final badges = [
      if (gender == 'male') (maleEmoji, 'Macho'),
      if (gender == 'female') (femaleEmoji, 'Fêmea'),
      if (isShiny) (shinyEmoji, 'Shiny'),
      if (isAlpha) (alphaEmoji, 'Alfa'),
      if (isFromGo) (goEmoji, 'Pokémon GO'),
    ];
    return Row(
      mainAxisAlignment: center
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      spacing: 4,
      children: [
        if (pokeballSpriteUrl != null)
          PokemonSprite(
            url: pokeballSpriteUrl,
            size: ballSize,
            semanticLabel: pokeballLabel,
          ),
        Flexible(
          child: Text(
            name,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        for (final (emoji, label) in badges)
          Text(emoji, style: style, semanticsLabel: label),
      ],
    );
  }
}
