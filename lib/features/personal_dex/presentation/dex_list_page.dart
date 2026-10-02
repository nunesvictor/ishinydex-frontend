import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/progress_badge.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/new_dex_page.dart';

/// Lista de PersonalDex com o progresso de cada um.
class DexListPage extends ConsumerWidget {
  const DexListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dexes = ref.watch(dexListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('PersonalDex')),
      floatingActionButton: FloatingActionButton.extended(
        // As abas ficam vivas juntas: cada botão precisa da sua hero tag.
        heroTag: 'new-dex',
        onPressed: () => _createDex(context),
        icon: const Icon(Icons.add),
        label: const Text('Novo PersonalDex'),
      ),
      body: dexes.when(
        data: (items) => items.isEmpty
            ? const EmptyView(
                message:
                    'Nenhum PersonalDex cadastrado. Crie o primeiro em '
                    '"Novo PersonalDex".',
              )
            : RefreshIndicator.adaptive(
                onRefresh: () => ref.refresh(dexListProvider.future),
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
  final dex = await Navigator.of(context, rootNavigator: true)
      .push<PersonalDex>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const NewDexPage(),
        ),
      );
  if (dex != null && context.mounted) context.go(Routes.dex(dex.id));
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
                      child: Text(shinyEmoji, semanticsLabel: 'Dex shiny'),
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
