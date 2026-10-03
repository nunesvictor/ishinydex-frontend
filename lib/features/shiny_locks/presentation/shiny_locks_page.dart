import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
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
    appBar: AppBar(title: const Text('Shiny locks')),
    floatingActionButton: FloatingActionButton.extended(
      heroTag: 'new-shiny-lock',
      onPressed: _open,
      icon: const Icon(Icons.add),
      label: const Text('Novo shiny lock'),
    ),
    body: switch (ref.watch(shinyLocksProvider)) {
      AsyncData(value: final locks) when locks.isEmpty => const EmptyView(
        message:
            'Nenhum shiny lock cadastrado. Um shiny lock marca formas sem '
            'shiny, ou com shiny só por distribuição (evento).',
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
                label: Text('Todos · ${locks.length}'),
                selected: _type == null,
                onSelected: (_) => setState(() => _type = null),
              ),
              for (final type in ShinyLockTypeUi.ordered)
                ChoiceChip(
                  avatar: Icon(type.icon, size: 18),
                  label: Text('${type.shortLabel} · ${count(type)}'),
                  selected: _type == type,
                  onSelected: (_) => setState(() => _type = type),
                ),
            ],
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? const EmptyView(message: 'Nenhum shiny lock deste tipo.')
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
            ShinyLockFormResult.saved => 'Shiny lock salvo.',
            ShinyLockFormResult.deleted => 'Shiny lock apagado.',
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
                  child: Text('Inativo', style: theme.textTheme.labelSmall),
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
            Text(forms == 1 ? '1 forma' : '$forms formas'),
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
      child: Icon(type.icon, semanticLabel: type.label),
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

  String get shortLabel => switch (this) {
    ShinyLockType.unobtainable => 'Impossível',
    ShinyLockType.distroOnly => 'Distribuição',
  };
}
