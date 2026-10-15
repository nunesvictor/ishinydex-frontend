import 'package:flutter/material.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/utils/type_chart.dart';
import 'package:ishinydex/core/widgets/type_chip.dart';

/// "Tipos em batalha" (#230): pelos tipos da forma, o que acerta forte (ou
/// fraco) quando ela é atacada, e contra o que os golpes do próprio tipo
/// (STAB) são super efetivos. Sem nenhum tipo da tabela, não aparece.
class TypeMatchupsCard extends StatelessWidget {
  const TypeMatchupsCard({required this.types, super.key});

  /// Os tipos da forma, na ordem dos slots.
  final List<String> types;

  @override
  Widget build(BuildContext context) {
    final own = types.where(isChartType).toList();
    if (own.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final defense = defenseMultipliers(own);
    List<String> at(double m) => [
      for (final t in pokemonTypes)
        if (defense[t] == m) t,
    ];
    final groups = [
      ('4×', l10n.typeEffect4, scheme.primary, scheme.onPrimary, at(4)),
      (
        '2×',
        l10n.typeEffect2,
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        at(2),
      ),
      (
        '½×',
        l10n.typeEffectHalf,
        scheme.surfaceContainerHighest,
        scheme.onSurface,
        at(0.5),
      ),
      (
        '¼×',
        l10n.typeEffectQuarter,
        scheme.surfaceContainerHighest,
        scheme.onSurface,
        at(0.25),
      ),
      ('0×', l10n.typeEffect0, scheme.onSurface, scheme.surface, at(0)),
    ];
    final heading = theme.textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      letterSpacing: 0.6,
    );
    final caption = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    Widget chips(List<String> list) => Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final t in list) TypeChip(t, small: true)],
    );
    Widget row(
      Widget lead,
      double leadWidth,
      String label,
      List<String> list,
    ) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        SizedBox(width: leadWidth, child: lead),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 5,
            children: [
              Text(label, style: caption),
              chips(list),
            ],
          ),
        ),
      ],
    );
    return Card.outlined(
      key: const ValueKey('type-matchups'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 14,
          children: [
            Text(l10n.typeMatchups, style: theme.textTheme.titleMedium),
            Text(l10n.typeMatchupsDefense.toUpperCase(), style: heading),
            for (final (mult, label, bg, fg, list) in groups)
              if (list.isNotEmpty)
                row(
                  Container(
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      mult,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  40,
                  label,
                  list,
                ),
            const Divider(height: 1),
            Text(l10n.typeMatchupsAttack.toUpperCase(), style: heading),
            for (final type in own)
              row(
                // Um nome comprido (Electric, Fighting) encolhe para caber.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: TypeChip(type, small: true),
                ),
                96,
                l10n.typeEffectAgainst,
                superEffectiveAgainst(type),
              ),
            Text(l10n.typeMatchupsNote, style: caption),
          ],
        ),
      ),
    );
  }
}
