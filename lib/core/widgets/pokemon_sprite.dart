import 'package:material_ui/material_ui.dart';

/// A imagem de um sprite remoto, a mesma que o [PokemonSprite] desenha.
///
/// O `imageCache` do Flutter guarda cada imagem pela chave do provider (URL,
/// escala e estratégia na web), então quem pré-carrega um sprite (ex.:
/// `NeighborBoxPrecache`) precisa usar exatamente este provider para o
/// [PokemonSprite] encontrá-lo já decodificado.
ImageProvider spriteImage(String url) =>
    NetworkImage(url, webHtmlElementStrategy: WebHtmlElementStrategy.fallback);

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
          : Image(
              image: spriteImage(src),
              width: size,
              height: size,
              fit: BoxFit.contain,
              semanticLabel: semanticLabel,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}
