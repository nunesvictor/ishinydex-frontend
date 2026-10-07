import 'package:flutter/material.dart';
import 'package:ishinydex/core/utils/format.dart';

/// Ícone do jogo no Pokémon HOME para uma versão (`scarlet`, `legends-za`...),
/// de `assets/game_icons/`. [muted] deixa em cinza: nas caçadas, um jogo em
/// que o usuário não tem save. Sem o asset (outra versão), a sigla do jogo.
class GameIcon extends StatelessWidget {
  const GameIcon(this.version, {this.size = 22, this.muted = false, super.key});

  final String version;
  final double size;
  final bool muted;

  /// Tons de cinza pela luminância (a mesma conta do `grayscale` do CSS).
  static const _grayscale = ColorFilter.matrix([
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    final label = versionLabel(version);
    final description = muted ? '$label (sem save seu)' : label;
    Widget icon = Image.asset(
      'assets/game_icons/$version.png',
      width: size,
      height: size,
      semanticLabel: description,
      errorBuilder: (context, _, _) => SizedBox.square(
        dimension: size,
        child: Center(
          child: Text(
            // "Legends: Z-A" → "LZ".
            label
                .split(RegExp('[ :-]+'))
                .where((word) => word.isNotEmpty)
                .take(2)
                .map((word) => word[0])
                .join(),
            semanticsLabel: description,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ),
    );
    if (muted) {
      icon = Opacity(
        opacity: 0.5,
        child: ColorFiltered(colorFilter: _grayscale, child: icon),
      );
    }
    return Tooltip(message: description, child: icon);
  }
}
