import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/hunt_share_sheet.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_labels.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// O registro da caçada no detalhe do espécime (#163): "Soft reset · 4.213
/// resets · 3 meses", as datas de início e de captura, o botão do post e,
/// num shiny, o de compartilhar o card (#243).
class HuntRecordCard extends ConsumerWidget {
  const HuntRecordCard({
    required this.hunt,
    this.capturedAt,
    this.specimen,
    super.key,
  });

  final HuntRecord hunt;
  final DateTime? capturedAt;

  /// O espécime da caçada: com ele (e shiny), o botão de compartilhar.
  final Specimen? specimen;

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
      if (method != null) context.catalogText(method.label, method.labels),
      if (hunt.count case final count?)
        context.l10n.huntCount(count, hunt.unit),
      if (hunt.bestChain case final best?) context.l10n.longestChain(best),
      if ((start, end) case (final s?, final e?))
        context.l10n.huntDuration(s, e),
    ].join(' · ');
    // As odds guardadas no fim da caçada (#221).
    final decimal = NumberFormat('0.0', context.l10n.localeName);
    final odds = [
      if (hunt.odds case final x?)
        context.l10n.oddsAtEnd(x < 10 ? decimal.format(x) : '${x.round()}'),
      if (hunt.multiple case final m?)
        context.l10n.foundAtOdds(decimal.format(m)),
    ].join(' · ');
    final dates = [
      if (start != null) context.l10n.huntStartDate(format(start)),
      if (end != null) context.l10n.huntCaptureDate(format(end)),
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
                  Text(
                    context.l10n.huntRecord,
                    style: theme.textTheme.labelLarge,
                  ),
                  if (headline.isNotEmpty)
                    Text(headline, style: theme.textTheme.bodyLarge),
                  if (odds.isNotEmpty)
                    Text(odds, style: theme.textTheme.bodyMedium),
                  if (dates.isNotEmpty)
                    Text(dates, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (specimen case final specimen?
                when huntShareDataOf(context, ref, specimen) != null)
              IconButton(
                tooltip: context.l10n.shareHunt,
                onPressed: () =>
                    unawaited(showHuntShareSheet(context, specimen)),
                icon: const Icon(Icons.ios_share),
              ),
            if (post != null)
              TextButton.icon(
                onPressed: () => ref.read(openLinkProvider)(post),
                icon: const Icon(Icons.open_in_new),
                label: Text(context.l10n.seePost),
              ),
          ],
        ),
      ),
    );
  }
}
