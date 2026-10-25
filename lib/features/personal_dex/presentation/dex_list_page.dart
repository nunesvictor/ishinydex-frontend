import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/mark_icons.dart';
import 'package:ishinydex/core/widgets/progress_badge.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/new_dex_page.dart';
import 'package:ishinydex/features/sync/sync_providers.dart';

/// Lista de PersonalDex com o progresso de cada um.
class DexListPage extends ConsumerWidget {
  const DexListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dexes = ref.watch(dexListProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.navPersonalDex)),
      floatingActionButton: FloatingActionButton.extended(
        // As abas ficam vivas juntas: cada botão precisa da sua hero tag.
        heroTag: 'new-dex',
        onPressed: () => _createDex(context),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.dexNew),
      ),
      body: dexes.when(
        data: (items) => items.isEmpty
            ? EmptyView(
                message: context.l10n.dexListEmpty,
                // Quem só caça não precisa de dex (#246).
                detail: context.l10n.dexListHuntsHint,
              )
            : RefreshIndicator.adaptive(
                // Puxar a lista também sincroniza (com o Dropbox conectado).
                onRefresh: () async {
                  await ref.read(syncControllerProvider.notifier).sync();
                  return await ref.refresh(dexListProvider.future);
                },
                child: GridView.builder(
                  // Espaço embaixo para o botão "Novo PersonalDex".
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
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

/// Abre o cadastro e, se um dex for criado, vai direto para ele.
Future<void> _createDex(BuildContext context) async {
  final dex = await openNewDex(context);
  if (dex != null && context.mounted) context.go(Routes.dex(dex.id));
}

/// Abre o "Novo PersonalDex" em tela cheia; devolve o dex criado, ou `null`
/// se a pessoa desistir.
Future<PersonalDex?> openNewDex(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).push<PersonalDex>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const NewDexPage(),
      ),
    );

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
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ShinyIcon(semanticLabel: context.l10n.shinyDex),
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
              Text.rich(
                TextSpan(
                  text: dex.missing == 0
                      ? context.l10n.dexComplete
                      : context.l10n.dexMissingCount(dex.missing),
                  children: [
                    // A parte que nunca completa (#341): explica a diferença
                    // para o "para caçar" da aba Faltam.
                    if (dex.locked > 0)
                      TextSpan(
                        text: ' · ${context.l10n.dexLockedCount(dex.locked)}',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                style: theme.textTheme.bodySmall,
              ),
              ProgressBadge(
                registered: dex.registered,
                total: dex.total,
                away: dex.away,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
