import 'package:flutter/material.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
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

  /// `null` quando um texto ao lado já diz o que é (evita leitura dupla);
  /// [automaticLabel] (o padrão das subclasses), o nome da marca no idioma
  /// da tela ([defaultLabel]).
  final String? semanticLabel;

  static const automaticLabel = '';

  /// O nome da marca, para o leitor de tela.
  String defaultLabel(AppLocalizations l10n);

  /// Glifo branco (as marcas de origem): pintado com a cor dos ícones ao
  /// redor, para servir no tema claro e no escuro. Os ícones coloridos
  /// (shiny, alfa) ficam como são.
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final label = semanticLabel == automaticLabel
        ? defaultLabel(context.l10n)
        : semanticLabel;
    return Image.asset(
      asset,
      width: size,
      height: size,
      color: tinted ? IconTheme.of(context).color : null,
      colorBlendMode: tinted ? BlendMode.srcIn : null,
      semanticLabel: label,
      excludeFromSemantics: label == null,
      errorBuilder: (_, _, _) => Text(
        emoji,
        semanticsLabel: label,
        style: TextStyle(fontSize: size * 0.8),
      ),
    );
  }
}

/// As estrelas de shiny do Pokémon HOME, no lugar do ✨.
class ShinyIcon extends MarkIcon {
  const ShinyIcon({
    super.size = 20,
    super.semanticLabel = MarkIcon.automaticLabel,
    @visibleForTesting super.asset = defaultAsset,
    super.key,
  }) : super(emoji: shinyEmoji);

  static const defaultAsset = 'assets/icons/shiny.png';

  @override
  String defaultLabel(AppLocalizations l10n) => l10n.markShiny;
}

/// Ícone de alfa do Pokémon HOME (o selo vermelho de Legends: Arceus), no
/// lugar do 💢.
class AlphaIcon extends MarkIcon {
  const AlphaIcon({
    super.size = 20,
    super.semanticLabel = MarkIcon.automaticLabel,
    @visibleForTesting super.asset = defaultAsset,
    super.key,
  }) : super(emoji: alphaEmoji);

  static const defaultAsset = 'assets/icons/alpha.png';

  @override
  String defaultLabel(AppLocalizations l10n) => l10n.markAlpha;
}

/// A marca de origem do Pokémon GO, no lugar do 📱, para "veio do GO".
class GoIcon extends MarkIcon {
  const GoIcon({
    super.size = 20,
    super.semanticLabel = MarkIcon.automaticLabel,
    @visibleForTesting super.asset = defaultAsset,
    super.key,
  }) : super(emoji: goEmoji, tinted: true);

  /// O mesmo arquivo de `OriginMark.go.asset` (aqui como constante).
  static const defaultAsset = 'assets/origin_marks/go.png';

  @override
  String defaultLabel(AppLocalizations l10n) => l10n.markGo;
}

/// O brilho de shiny riscado: o motivo "Sem shiny" das Caçadas (#219).
class NoShinyIcon extends StatelessWidget {
  const NoShinyIcon({this.size = 20, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        ShinyIcon(size: size, semanticLabel: null),
        Transform.rotate(
          angle: -0.785,
          child: Container(
            width: size * 1.15,
            height: size / 9,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface,
              borderRadius: BorderRadius.circular(size),
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 0.5,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
