import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/theme/app_theme.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/progress_badge.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';

/// Lista de PersonalDex com o progresso de cada um.
class DexListPage extends ConsumerWidget {
  const DexListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dexes = ref.watch(dexListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('PersonalDex')),
      body: dexes.when(
        data: (items) => items.isEmpty
            ? const EmptyView(message: 'Nenhum PersonalDex cadastrado.')
            : RefreshIndicator.adaptive(
                onRefresh: () => ref.refresh(dexListProvider.future),
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 420,
                    mainAxisExtent: 132,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _DexCard(dex: items[i]),
                ),
              ),
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(dexListProvider),
        ),
      ),
    );
  }
}

class _DexCard extends StatelessWidget {
  const _DexCard({required this.dex});

  final PersonalDex dex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/dexes/${dex.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (dex.isShinyDex)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.auto_awesome,
                        color: AppTheme.shinyGold,
                        semanticLabel: 'Dex shiny',
                      ),
                    ),
                  Expanded(
                    child: Text(
                      dex.name,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Text(
                dex.missing == 0 ? 'Completo!' : 'Faltam ${dex.missing}',
                style: theme.textTheme.bodySmall,
              ),
              ProgressBadge(registered: dex.registered, total: dex.total),
            ],
          ),
        ),
      ),
    );
  }
}
