import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/features/specimens/domain/home_cutoff.dart';

/// A etiqueta do corte do HOME (#222), a mesma no save, no espécime, na
/// caçada e na aba Faltam. Antes do corte, ⏳ "HOME 26/02"; depois, o elo
/// cortado e "HOME". "HOME" é o nome do produto e não se traduz; a data
/// segue o idioma. A frase completa fica no toque longo e no leitor de
/// tela, como na etiqueta de idioma.
class HomeTag extends StatelessWidget {
  const HomeTag(this.cutoff, {super.key});

  final HomeCutoff cutoff;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final until = cutoff.until.toLocal();
    final passed = cutoff.passed;
    final message = passed
        ? context.l10n.noLongerReachesHome
        : context.l10n.reachesHomeUntil(
            MaterialLocalizations.of(context).formatCompactDate(until),
          );
    final day = DateFormat.Md(Localizations.localeOf(context).toString())
        .format(until);
    final (background, foreground) = passed
        ? (Colors.transparent, colors.onSurfaceVariant)
        : (colors.tertiaryContainer, colors.onTertiaryContainer);
    return Tooltip(
      message: message,
      excludeFromSemantics: true,
      child: Semantics(
        label: message,
        excludeSemantics: true,
        child: Container(
          key: const ValueKey('home-tag'),
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(6),
            border: passed ? Border.all(color: colors.outline) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              Icon(
                passed ? Icons.link_off : Icons.hourglass_bottom,
                size: 14,
                color: foreground,
              ),
              Text(
                passed ? 'HOME' : 'HOME $day',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: foreground, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
