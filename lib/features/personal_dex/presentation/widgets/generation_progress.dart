import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/responsive/breakpoints.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/progress_badge.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';

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
                'Progresso por geração',
                style: Theme.of(context).textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: switch (ref.watch(generationsProvider(dexId))) {
          AsyncData(value: final gens) when gens.isEmpty => const EmptyView(
            message: 'Este dex ainda não tem formas nas boxes.',
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
                    Expanded(child: Text(gen.label)),
                    Text(
                      gen.missing == 0 ? 'Completa!' : 'Faltam ${gen.missing}',
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
                  message: 'Ir para ${gen.firstBox.name}',
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
