import 'package:flutter/material.dart';
import 'package:ishinydex/core/theme/app_theme.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';

/// Célula da box: sprite apagado quando faltante, bola no canto quando
/// registrado.
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
    final form = slot.form;
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
        onTap: form == null ? null : onTap,
        child: form == null
            ? const SizedBox.expand()
            : Opacity(
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
                            child: PokemonSprite(
                              url: ballUrl,
                              size: size * 0.3,
                            ),
                          ),
                        if (specimen != null && specimen.isShiny)
                          Positioned(
                            left: 2,
                            top: 2,
                            child: Icon(
                              Icons.auto_awesome,
                              size: size * 0.2,
                              color: AppTheme.shinyGold,
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
