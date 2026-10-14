import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/presentation/dex_labels.dart';
import 'package:ishinydex/features/shiny_locks/domain/models.dart';
import 'package:ishinydex/features/shiny_locks/presentation/shiny_lock_form_page.dart';
import 'package:ishinydex/features/shiny_locks/shiny_lock_providers.dart';

/// Ajustes → Shiny locks: as formas sem shiny, ou com shiny só por
/// distribuição, cadastradas à mão. Tocar num item abre a edição; o botão
/// flutuante cria um novo.
class ShinyLocksPage extends ConsumerStatefulWidget {
  const ShinyLocksPage({super.key});

  @override
  ConsumerState<ShinyLocksPage> createState() => _ShinyLocksPageState();
}

class _ShinyLocksPageState extends ConsumerState<ShinyLocksPage> {
  /// Filtro por tipo; `null` = todos.
  ShinyLockType? _type;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.shinyLocksTitle)),
    floatingActionButton: FloatingActionButton.extended(
      heroTag: 'new-shiny-lock',
      onPressed: _open,
      icon: const Icon(Icons.add),
      label: Text(context.l10n.shinyLockNew),
    ),
    body: switch (ref.watch(shinyLocksProvider)) {
      AsyncData(value: final locks) when locks.isEmpty => EmptyView(
        message: context.l10n.shinyLocksEmpty,
      ),
      AsyncData(value: final locks) => _list(locks),
      AsyncError(:final error) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(shinyLocksProvider),
      ),
      _ => const LoadingView(),
    },
  );

  Widget _list(List<ShinyLock> locks) {
    final shown = [
      for (final lock in locks)
        if (_type == null || lock.lockType == _type) lock,
    ];
    int count(ShinyLockType type) =>
        locks.where((lock) => lock.lockType == type).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Uma linha rolável: no celular estreito os chips não quebram linha.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(
                  context.l10n.labelCount(context.l10n.allLabel, locks.length),
                ),
                selected: _type == null,
                onSelected: (_) => setState(() => _type = null),
              ),
              for (final type in ShinyLockTypeUi.ordered)
                ChoiceChip(
                  avatar: Icon(type.icon, size: 18),
                  label: Text(
                    context.l10n.labelCount(
                      type.shortLabel(context.l10n),
                      count(type),
                    ),
                  ),
                  selected: _type == type,
                  onSelected: (_) => setState(() => _type = type),
                ),
            ],
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? EmptyView(message: context.l10n.shinyLocksEmptyType)
              : ListView(
                  // Espaço para o botão flutuante não cobrir o último.
                  padding: const EdgeInsets.only(bottom: 88),
                  children: [
                    for (final lock in shown)
                      _ShinyLockTile(lock: lock, onTap: () => _open(lock)),
                  ],
                ),
        ),
      ],
    );
  }

  /// Abre o cadastro (novo, ou a edição de [lock]) e avisa o resultado.
  Future<void> _open([ShinyLock? lock]) async {
    final result = await showShinyLockForm(context, lock: lock);
    if (result == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(switch (result) {
            ShinyLockFormResult.saved => context.l10n.shinyLockSaved,
            ShinyLockFormResult.deleted => context.l10n.shinyLockDeleted,
          }),
        ),
      );
  }
}

class _ShinyLockTile extends StatelessWidget {
  const _ShinyLockTile({required this.lock, required this.onTap});

  /// Quantos sprites aparecem antes do total.
  static const _previewForms = 3;

  final ShinyLock lock;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final forms = lock.forms.length;
    return Opacity(
      // Inativo não vale nas caçadas: fica esmaecido.
      opacity: lock.active ? 1 : 0.55,
      child: ListTile(
        key: ValueKey('shiny-lock-${lock.id}'),
        leading: ShinyLockTypeAvatar(lock.lockType),
        title: Row(
          spacing: 8,
          children: [
            Flexible(
              child: Text(lock.caption, overflow: TextOverflow.ellipsis),
            ),
            if (!lock.active)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Text(
                    context.l10n.shinyLockInactive,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Row(
          spacing: 4,
          children: [
            for (final form in lock.forms.take(_previewForms))
              PokemonSprite(
                url: form.spriteUrl,
                size: 24,
                semanticLabel: form.displayName,
              ),
            const SizedBox(width: 4),
            Text(context.l10n.countForms(forms)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// Ícone do tipo num círculo colorido: cadeado (shiny impossível) ou presente
/// (só por distribuição).
class ShinyLockTypeAvatar extends StatelessWidget {
  const ShinyLockTypeAvatar(this.type, {super.key});

  final ShinyLockType type;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (type) {
      ShinyLockType.unobtainable => (
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      ShinyLockType.distroOnly => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
    };
    return CircleAvatar(
      backgroundColor: background,
      foregroundColor: foreground,
      child: Icon(type.icon, semanticLabel: context.l10n.shinyLockType(type)),
    );
  }
}

/// Ícone e rótulo curto (chips) de cada tipo, usados nas duas telas.
extension ShinyLockTypeUi on ShinyLockType {
  /// Ordem nas telas: o caso mais comum (impossível) primeiro.
  static const List<ShinyLockType> ordered = [
    ShinyLockType.unobtainable,
    ShinyLockType.distroOnly,
  ];

  IconData get icon => switch (this) {
    ShinyLockType.unobtainable => Icons.lock_outline,
    ShinyLockType.distroOnly => Icons.card_giftcard,
  };

  /// O nome curto, nos chips.
  String shortLabel(AppLocalizations l10n) => switch (this) {
    ShinyLockType.unobtainable => l10n.shinyLockShortUnobtainable,
    ShinyLockType.distroOnly => l10n.shinyLockShortDistro,
  };
}
