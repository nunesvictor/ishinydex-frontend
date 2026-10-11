import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/confirm_dialog.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/location_flow.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/new_trainer_dialog.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Ajustes → Meus saves: os jogos para onde o usuário envia Pokémon do HOME.
///
/// Um save é um treinador original (nome, TID e versão) marcado como "meu":
/// servem os treinadores de jogos ligados ao HOME. O apelido distingue dois
/// saves do mesmo jogo ("Switch Lite").
///
/// Os saves de jogos só de ida ([Save.isOneWay], como o FireRed do Switch)
/// ficam numa seção à parte: servem para caçar e para o OT, mas nunca são
/// destino de transferência.
class SavesPage extends ConsumerWidget {
  const SavesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Meus saves')),
    floatingActionButton: FloatingActionButton.extended(
      heroTag: 'new-save',
      onPressed: () => _add(context, ref),
      icon: const Icon(Icons.add),
      label: const Text('Adicionar save'),
    ),
    body: switch (ref.watch(savesProvider)) {
      AsyncData(value: final saves) when saves.isEmpty => const EmptyView(
        message:
            'Nenhum save cadastrado. Um save é um jogo para onde você envia '
            'Pokémon do HOME (Scarlet, Legends: Z-A...).',
      ),
      AsyncData(value: final saves) => _SaveList(saves),
      AsyncError(:final error) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(savesProvider),
      ),
      _ => const LoadingView(),
    },
  );
}

/// A lista de saves. Com algum save só de ida, ela se divide em duas
/// seções: "Recebem do HOME" e "Só enviam para o HOME", esta com uma linha
/// que explica por que esses saves não aparecem como destino.
class _SaveList extends ConsumerWidget {
  const _SaveList(this.saves);

  final List<Save> saves;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final receivers = [
      for (final s in saves)
        if (!s.isOneWay) s,
    ];
    final oneWay = [
      for (final s in saves)
        if (s.isOneWay) s,
    ];
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        if (oneWay.isNotEmpty && receivers.isNotEmpty)
          header('Recebem do HOME'),
        for (final save in receivers) _tile(context, ref, save),
        if (oneWay.isNotEmpty) ...[
          if (receivers.isNotEmpty) const Divider(indent: 16, endIndent: 16),
          header('Só enviam para o HOME'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Servem para caçar e para o OT. Não aparecem como destino: o '
              'Pokémon que sai deles não volta.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final save in oneWay) _tile(context, ref, save),
        ],
      ],
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref, Save save) => ListTile(
    key: ValueKey('save-${save.id}'),
    leading: SaveIcon(save),
    title: Text(save.title),
    subtitle: Text(
      save.isOneWay
          ? '${save.trainer.label}\nSó envia para o HOME'
          : save.trainer.label,
    ),
    isThreeLine: save.isOneWay,
    trailing: PopupMenuButton<_SaveAction>(
      tooltip: 'Ações do save',
      onSelected: (action) => switch (action) {
        _SaveAction.rename => _rename(context, ref, save),
        _SaveAction.delete => _delete(context, ref, save),
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: _SaveAction.rename, child: Text('Renomear')),
        PopupMenuItem(value: _SaveAction.delete, child: Text('Remover')),
      ],
    ),
  );
}

enum _SaveAction { rename, delete }

void _notify(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

/// Escolhe um treinador que pode virar save (ou cadastra um novo) e cria o
/// save.
Future<void> _add(BuildContext context, WidgetRef ref) async {
  final repository = ref.read(specimenRepositoryProvider);
  final List<Trainer> eligible;
  try {
    final trainers = await ref.read(trainersProvider.future);
    final saves = await ref.read(savesProvider.future);
    final taken = {for (final s in saves) s.trainer.id};
    eligible = [
      for (final t in trainers)
        if (Save.homeVersions.contains(t.version) && !taken.contains(t.id)) t,
    ];
  } on AppFailure catch (failure) {
    if (context.mounted) _notify(context, failure.message);
    return;
  }
  if (!context.mounted) return;
  // `null` no pop = "Novo treinador…".
  final picked = await showModalBottomSheet<({Trainer? trainer})>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              'Qual treinador é o seu save?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final trainer in eligible)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(trainer.label),
              onTap: () => Navigator.of(context).pop((trainer: trainer)),
            ),
          if (eligible.isEmpty)
            const ListTile(
              title: Text('Nenhum treinador de jogo ligado ao HOME.'),
            ),
          ListTile(
            leading: const Icon(Icons.person_add_alt),
            title: const Text('Novo treinador…'),
            onTap: () => Navigator.of(context).pop((trainer: null)),
          ),
        ],
      ),
    ),
  );
  if (picked == null || !context.mounted) return;
  var trainer = picked.trainer;
  if (trainer == null) {
    trainer = await showNewTrainerDialog(context);
    ref.invalidate(trainersProvider);
    if (trainer == null || !context.mounted) return;
  }
  try {
    final save = await repository.createSave(trainerId: trainer.id);
    ref.invalidate(savesProvider);
    if (context.mounted) _notify(context, '${save.title} adicionado.');
  } on AppFailure catch (failure) {
    if (context.mounted) _notify(context, failure.message);
  }
}

Future<void> _rename(BuildContext context, WidgetRef ref, Save save) async {
  final label = await showDialog<String>(
    context: context,
    builder: (context) => _RenameDialog(initial: save.label),
  );
  if (label == null || !context.mounted) return;
  try {
    await ref
        .read(specimenRepositoryProvider)
        .updateSave(save.id, label: label.trim());
    ref.invalidate(savesProvider);
    // Os espécimes fora do HOME mostram o apelido do save.
    ref.read(slotActionsProvider).specimensChanged();
  } on AppFailure catch (failure) {
    if (context.mounted) _notify(context, failure.message);
  }
}

Future<void> _delete(BuildContext context, WidgetRef ref, Save save) async {
  final confirmed = await showConfirmDialog(
    context,
    title: 'Remover ${save.title}?',
    message:
        'O treinador continua cadastrado; só deixa de ser um save. Um save '
        'com espécimes não pode ser removido.',
    confirmLabel: 'Remover',
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;
  try {
    await ref.read(specimenRepositoryProvider).deleteSave(save.id);
    ref.invalidate(savesProvider);
  } on AppFailure catch (failure) {
    if (context.mounted) _notify(context, failure.message);
  }
}

/// Apelido do save. O controller vive no `State` do diálogo: ele só é
/// descartado quando o diálogo sai da árvore, depois da animação de
/// fechamento (descartar logo após o `pop` quebraria o campo ainda visível).
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Apelido do save'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(
        hintText: 'Ex.: Switch Lite',
        helperText: 'Para diferenciar dois saves do mesmo jogo.',
      ),
      onSubmitted: (text) => Navigator.of(context).pop(text),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text('Salvar'),
      ),
    ],
  );
}
