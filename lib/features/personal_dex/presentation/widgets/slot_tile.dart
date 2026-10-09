import 'package:flutter/material.dart';
import 'package:ishinydex/core/widgets/mark_icons.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/location_flow.dart';

/// Posição da box sem forma deste dex: só o fundo, sem conteúdo nem toque.
class EmptySlotTile extends StatelessWidget {
  const EmptySlotTile({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
    ),
  );
}

/// Célula da box: sprite apagado quando faltante, bola no canto quando
/// registrado. Fora do HOME (num save), o sprite fica esmaecido e o selo do
/// jogo aparece no canto superior direito. Só para slots com forma; os
/// livres usam [EmptySlotTile].
class SlotTile extends StatelessWidget {
  const SlotTile({
    required this.slot,
    required this.selected,
    required this.onTap,
    this.dimmed = false,
    super.key,
  });

  /// A partir deste tamanho, os selos de shiny e alfa ficam lado a lado;
  /// abaixo, empilhados.
  static const badgesInRowMinSize = 64.0;

  /// Abaixo deste tamanho não cabe o segundo selo: fica só o de shiny.
  static const alphaMinSize = 40.0;

  final Slot slot;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final form = slot.form!;
    final specimen = slot.specimen;
    final ballUrl = specimen?.pokeballSpriteUrl;
    final away = specimen?.location;
    final visiting = specimen?.isVisitingChampions ?? false;
    return Material(
      color: slot.isRegistered
          ? scheme.surfaceContainerHighest
          : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? scheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('slot-${slot.id}'),
        onTap: onTap,
        child: Opacity(
          opacity: dimmed ? 0.25 : 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest.shortestSide;
              // Folga interna proporcional: os selos nunca encostam na borda.
              final inset = size * 0.06;
              final badges = [
                if (specimen != null && specimen.isShiny)
                  ShinyIcon(size: size * 0.18),
                if (specimen != null &&
                    specimen.isAlpha &&
                    size >= SlotTile.alphaMinSize)
                  AlphaIcon(size: size * 0.18),
              ];
              return Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Opacity(
                      opacity: slot.isMissing
                          ? 0.35
                          : away != null || visiting
                          ? 0.55
                          : 1,
                      child: PokemonSprite(
                        url: slot.spriteUrl,
                        size: size * 0.8,
                        semanticLabel: form.displayName,
                      ),
                    ),
                  ),
                  // Canto superior esquerdo: selos juntos (shiny e alfa). Os cantos
                  // livres (topo-direito, base-esquerda) ficam para ícones
                  // futuros, como a geração.
                  if (badges.isNotEmpty)
                    Positioned(
                      left: inset,
                      top: inset,
                      child: size >= SlotTile.badgesInRowMinSize
                          ? Row(
                              key: const ValueKey('badges-row'),
                              mainAxisSize: MainAxisSize.min,
                              children: badges,
                            )
                          : Column(
                              key: const ValueKey('badges-column'),
                              mainAxisSize: MainAxisSize.min,
                              children: badges,
                            ),
                    ),
                  if (away != null)
                    Positioned(
                      right: inset,
                      top: inset,
                      child: Tooltip(
                        message: 'Em ${away.title}',
                        child: SaveIcon(away, size: size * 0.22),
                      ),
                    ),
                  // Visitando o Champions (#174): como quem está num save,
                  // com a marca do HOME. Ela é mais larga que alta, por isso
                  // um pouco maior que a do save para ter o mesmo peso.
                  if (visiting)
                    Positioned(
                      right: inset,
                      top: inset,
                      child: Tooltip(
                        message: 'Visitando o Champions',
                        child: Image.asset(
                          'assets/origin_marks/champions.png',
                          key: const ValueKey('champions-mark'),
                          width: size * 0.28,
                          height: size * 0.28,
                          color: IconTheme.of(context).color,
                          colorBlendMode: BlendMode.srcIn,
                        ),
                      ),
                    ),
                  if (ballUrl != null)
                    Positioned(
                      right: inset,
                      bottom: inset,
                      child: PokemonSprite(url: ballUrl, size: size * 0.28),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
