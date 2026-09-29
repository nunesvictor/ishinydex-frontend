import 'package:flutter/material.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';

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
/// registrado. Só para slots com forma; os livres usam [EmptySlotTile].
class SlotTile extends StatelessWidget {
  const SlotTile({
    required this.slot,
    required this.selected,
    required this.onTap,
    this.dimmed = false,
    super.key,
  });

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
              return Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Opacity(
                      opacity: slot.isMissing ? 0.35 : 1,
                      child: PokemonSprite(
                        url: slot.spriteUrl,
                        size: size * 0.85,
                        semanticLabel: form.displayName,
                      ),
                    ),
                  ),
                  if (ballUrl != null)
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: PokemonSprite(url: ballUrl, size: size * 0.3),
                    ),
                  if (specimen != null && specimen.isShiny)
                    Positioned(
                      left: 2,
                      top: 2,
                      child: Text(
                        shinyEmoji,
                        semanticsLabel: 'Shiny',
                        style: TextStyle(fontSize: size * 0.16),
                      ),
                    ),
                  if (specimen != null && specimen.isAlpha)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Text(
                        alphaEmoji,
                        semanticsLabel: 'Alfa',
                        style: TextStyle(fontSize: size * 0.16),
                      ),
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
