import 'package:flutter/material.dart';
import 'package:ishinydex/core/l10n/l10n.dart';

/// A face de um chip de filtro com valores marcados (#219): só os ícones,
/// sobrepostos, até [max], e "+N". O nome completo fica no tooltip do chip
/// e no leitor de tela ([semanticLabel]), então a fila de chips cabe numa
/// linha no celular.
class ChipIcons extends StatelessWidget {
  const ChipIcons(
    this.icons, {
    required this.semanticLabel,
    this.max = 3,
    super.key,
  });

  final List<Widget> icons;
  final String semanticLabel;
  final int max;

  static const _size = 18.0;

  /// Quanto cada ícone anda para a direita: o resto fica sob o próximo.
  static const _step = 12.0;

  @override
  Widget build(BuildContext context) {
    final shown = icons.take(max).toList();
    final rest = icons.length - shown.length;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: [
          SizedBox(
            width: _size + _step * (shown.length - 1),
            height: _size,
            // Cada ícone por cima do anterior, separado por um contorno da
            // cor do chip selecionado.
            child: Stack(
              children: [
                for (final (i, icon) in shown.indexed)
                  Positioned(
                    left: _step * i,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.secondaryContainer,
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: [
                          BoxShadow(
                            color: colors.secondaryContainer,
                            spreadRadius: 1.5,
                          ),
                        ],
                      ),
                      child: SizedBox.square(
                        dimension: _size,
                        child: IconTheme.merge(
                          data: const IconThemeData(size: _size),
                          child: Center(child: icon),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (rest > 0)
            Text('+$rest', style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

/// "shiny e alfa", "A, B e C" ("A, B and C"): a lista para o tooltip e o
/// leitor de tela.
String joinLabels(AppLocalizations l10n, List<String> labels) =>
    switch (labels) {
      [] => '',
      [final one] => one,
      _ => l10n.listAnd(
        labels.sublist(0, labels.length - 1).join(', '),
        labels.last,
      ),
    };
