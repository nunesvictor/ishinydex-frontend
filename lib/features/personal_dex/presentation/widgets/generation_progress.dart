import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/responsive/breakpoints.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/progress_badge.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/dex_labels.dart';

/// Progresso do dex [dexId] por geração. Tela cheia no compacto, diálogo
/// nos demais. Retorna o id da primeira box da geração tocada, ou `null`.
Future<int?> showGenerationProgress(
  BuildContext context, {
  required int dexId,
}) {
  final content = GenerationProgressView(dexId: dexId);
  return showDialog<int>(
    context: context,
    builder: (context) => WindowSize.of(context).isCompact
        ? Dialog.fullscreen(child: content)
        : Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
              child: content,
            ),
          ),
  );
}

class GenerationProgressView extends ConsumerWidget {
  const GenerationProgressView({required this.dexId, super.key});

  final int dexId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
        child: Row(
          children: [
            const CloseButton(),
            Expanded(
              child: Text(
                context.l10n.progressByGeneration,
                style: Theme.of(context).textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: switch (ref.watch(generationsProvider(dexId))) {
          AsyncData(value: final gens) when gens.isEmpty => EmptyView(
            message: context.l10n.dexNoForms,
          ),
          AsyncData(value: final gens) => ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: gens.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final gen = gens[i];
              return ListTile(
                key: ValueKey('generation-$i'),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(context.l10n.generation(gen.generation)),
                    ),
                    Text.rich(
                      TextSpan(
                        text: gen.missing == 0
                            ? context.l10n.generationComplete
                            : context.l10n.dexMissingCount(gen.missing),
                        children: [
                          if (gen.locked > 0)
                            TextSpan(
                              text:
                                  ' · '
                                  '${context.l10n.dexLockedCount(gen.locked)}',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: ProgressBadge(
                    registered: gen.registered,
                    total: gen.total,
                    away: gen.away,
                  ),
                ),
                trailing: Tooltip(
                  message: context.l10n.goToBox(gen.firstBox.name),
                  child: const Icon(Icons.chevron_right),
                ),
                onTap: () => Navigator.of(context).pop(gen.firstBox.id),
              );
            },
          ),
          AsyncError(:final error) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(generationsProvider(dexId)),
          ),
          _ => const LoadingView(),
        },
      ),
    ],
  );
}
