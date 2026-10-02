import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';

/// Título do AppBar do dex que abre um menu para trocar de PersonalDex ou
/// voltar à lista completa. [subtitle] (o progresso do dex) vai numa linha
/// menor embaixo do nome.
class DexSwitcher extends ConsumerWidget {
  const DexSwitcher({
    required this.dexId,
    required this.title,
    this.subtitle,
    super.key,
  });

  final int dexId;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dexes = ref.watch(dexListProvider).value ?? const <PersonalDex>[];
    return MenuAnchor(
      menuChildren: [
        for (final dex in dexes)
          MenuItemButton(
            key: ValueKey('switch-dex-${dex.id}'),
            leadingIcon: Icon(dex.id == dexId ? Icons.check : null),
            trailingIcon: Text('${dex.registered}/${dex.total}'),
            onPressed: dex.id == dexId
                ? null
                : () => context.go(Routes.dex(dex.id)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                Text(dex.name),
                if (dex.isShinyDex) const Text(shinyEmoji),
              ],
            ),
          ),
        if (dexes.isNotEmpty) const Divider(),
        MenuItemButton(
          leadingIcon: const Icon(Icons.view_list),
          onPressed: () => context.go(Routes.dexes),
          child: const Text('Ver todos'),
        ),
      ],
      builder: (context, controller, _) => Tooltip(
        message: 'Trocar PersonalDex',
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: controller.isOpen ? controller.close : controller.open,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, overflow: TextOverflow.ellipsis),
                      if (subtitle case final subtitle?)
                        Text(
                          subtitle,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
