import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// O registro da caçada no detalhe do espécime (#163): "Soft reset · 4.213
/// resets · 3 meses", as datas de início e de captura e o botão do post.
class HuntRecordCard extends ConsumerWidget {
  const HuntRecordCard({required this.hunt, this.capturedAt, super.key});

  final HuntRecord hunt;
  final DateTime? capturedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final format = MaterialLocalizations.of(context).formatCompactDate;
    final method = ref
        .watch(shinyMethodsProvider)(null)
        .where((m) => m.id == hunt.method)
        .firstOrNull;
    final (start, end) = (hunt.startedAt, capturedAt);
    final headline = [
      ?method?.label,
      if (hunt.count case final count?) huntCountLabel(count, hunt.unit),
      if ((start, end) case (final s?, final e?)) huntDuration(s, e),
    ].join(' · ');
    final dates = [
      if (start != null) 'Início ${format(start)}',
      if (end != null) 'Captura ${format(end)}',
    ].join(' · ');
    final post = hunt.postUrl;
    return Card.outlined(
      key: const ValueKey('hunt-card'),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          spacing: 12,
          children: [
            Icon(Icons.track_changes, color: theme.colorScheme.primary),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text('Registro da caçada', style: theme.textTheme.labelLarge),
                  if (headline.isNotEmpty)
                    Text(headline, style: theme.textTheme.bodyLarge),
                  if (dates.isNotEmpty)
                    Text(dates, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (post != null)
              TextButton.icon(
                onPressed: () => ref.read(openLinkProvider)(post),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Ver post'),
              ),
          ],
        ),
      ),
    );
  }
}
