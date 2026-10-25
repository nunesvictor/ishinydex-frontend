import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/responsive/breakpoints.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/confirm_dialog.dart';
import 'package:ishinydex/core/widgets/shiny_charm_icon.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/location_flow.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_labels.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/home_cutoff_notice.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/home_tag.dart';
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
    appBar: AppBar(title: Text(context.l10n.settingsMySaves)),
    floatingActionButton: FloatingActionButton.extended(
      heroTag: 'new-save',
      onPressed: () => _add(context, ref),
      icon: const Icon(Icons.add),
      label: Text(context.l10n.addSave),
    ),
    body: switch (ref.watch(savesProvider)) {
      AsyncData(value: final saves) when saves.isEmpty => EmptyView(
        message: context.l10n.savesEmpty,
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
    final cutoffOf = ref.watch(homeCutoffProvider);
    bool cut(Save s) => cutoffOf(s.trainer.version)?.passed ?? false;
    final oneWay = [
      for (final s in saves)
        if (s.isOneWay && !cut(s)) s,
    ];
    // Depois do corte do HOME (#222): continuam saves (caçadas, odds, OT),
    // só não enviam mais para o HOME.
    final noPath = [
      for (final s in saves)
        if (s.isOneWay && cut(s)) s,
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
        const HomeCutoffNotice(),
        if ((oneWay.isNotEmpty || noPath.isNotEmpty) && receivers.isNotEmpty)
          header(context.l10n.receiveFromHome),
        for (final save in receivers) _tile(context, ref, save),
        if (oneWay.isNotEmpty) ...[
          if (receivers.isNotEmpty) const Divider(indent: 16, endIndent: 16),
          header(context.l10n.onlySendToHome),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              context.l10n.oneWayNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final save in oneWay) _tile(context, ref, save),
        ],
        if (noPath.isNotEmpty) ...[
          if (receivers.isNotEmpty || oneWay.isNotEmpty)
            const Divider(indent: 16, endIndent: 16),
          header(context.l10n.noPathToHome),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              context.l10n.noPathNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final save in noPath) _tile(context, ref, save),
        ],
      ],
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref, Save save) {
    final cutoff = ref.watch(homeCutoffProvider)(save.trainer.version);
    return ListTile(
      key: ValueKey('save-${save.id}'),
      leading: SaveIcon(save),
      title: Row(
        spacing: 6,
        children: [
          Flexible(child: Text(save.gameFullName)),
          if (save.hasShinyCharm) const ShinyCharmIcon(),
        ],
      ),
      subtitle: !save.isOneWay
          ? Text(save.ownerLine)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(save.ownerLine),
                Row(
                  spacing: 6,
                  children: [
                    if (!(cutoff?.passed ?? false))
                      Flexible(child: Text(context.l10n.onlySendsToHome)),
                    if (cutoff != null) HomeTag(cutoff),
                  ],
                ),
              ],
            ),
      isThreeLine: save.isOneWay,
      trailing: PopupMenuButton<_SaveAction>(
        tooltip: context.l10n.saveActions,
        onSelected: (action) => switch (action) {
          _SaveAction.edit => _edit(context, ref, save),
          _SaveAction.delete => _delete(context, ref, save),
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: _SaveAction.edit,
            child: Text(context.l10n.edit),
          ),
          PopupMenuItem(
            value: _SaveAction.delete,
            child: Text(context.l10n.removeAction),
          ),
        ],
      ),
    );
  }
}

enum _SaveAction { edit, delete }

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
    if (context.mounted) _notify(context, context.failureText(failure));
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
              context.l10n.whichTrainer,
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
            ListTile(title: Text(context.l10n.noHomeTrainer)),
          ListTile(
            leading: const Icon(Icons.person_add_alt),
            title: Text(context.l10n.newTrainerEllipsis),
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
    if (context.mounted) _notify(context, context.l10n.saveAdded(save.title));
  } on AppFailure catch (failure) {
    if (context.mounted) _notify(context, context.failureText(failure));
  }
}

Future<void> _edit(BuildContext context, WidgetRef ref, Save save) async {
  final edited = await showDialog<({String label, bool hasShinyCharm})>(
    context: context,
    builder: (context) => _EditSaveDialog(save: save),
  );
  if (edited == null || !context.mounted) return;
  try {
    await ref
        .read(specimenRepositoryProvider)
        .updateSave(
          save.id,
          label: edited.label.trim(),
          hasShinyCharm: edited.hasShinyCharm,
        );
    ref.invalidate(savesProvider);
    // Os espécimes fora do HOME mostram o apelido do save.
    ref.read(slotActionsProvider).specimensChanged();
  } on AppFailure catch (failure) {
    if (context.mounted) _notify(context, context.failureText(failure));
  }
}

Future<void> _delete(BuildContext context, WidgetRef ref, Save save) async {
  final confirmed = await showConfirmDialog(
    context,
    title: context.l10n.removeNamedQuestion(save.title),
    message: context.l10n.removeSaveMessage,
    confirmLabel: context.l10n.removeAction,
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;
  try {
    await ref.read(specimenRepositoryProvider).deleteSave(save.id);
    ref.invalidate(savesProvider);
  } on AppFailure catch (failure) {
    if (context.mounted) _notify(context, context.failureText(failure));
  }
}

/// Edição do save: o apelido e, nos jogos que têm, o Shiny Charm (#220).
/// Tela cheia no celular, diálogo no resto. O controller vive no `State`:
/// ele só é descartado quando o diálogo sai da árvore, depois da animação
/// de fechamento (descartar logo após o `pop` quebraria o campo visível).
class _EditSaveDialog extends StatefulWidget {
  const _EditSaveDialog({required this.save});

  final Save save;

  @override
  State<_EditSaveDialog> createState() => _EditSaveDialogState();
}

class _EditSaveDialogState extends State<_EditSaveDialog> {
  late final _controller = TextEditingController(text: widget.save.label);
  late bool _charm = widget.save.hasShinyCharm;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() =>
      Navigator.of(context)
          .pop((label: _controller.text, hasShinyCharm: _charm));

  @override
  Widget build(BuildContext context) {
    final save = widget.save;
    final fields = [
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.person_outline),
        title: Text(context.l10n.originalTrainer),
        subtitle: Text(save.trainer.label),
      ),
      TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: context.l10n.saveNickname,
          hintText: context.l10n.saveNicknameHint,
          helperText: context.l10n.saveNicknameHelper,
        ),
        onSubmitted: (_) => _submit(),
      ),
      if (save.canHaveShinyCharm)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.auto_awesome),
          title: Text(context.l10n.haveShinyCharm),
          subtitle: Text(context.l10n.shinyCharmHint(save)),
          value: _charm,
          onChanged: (value) => setState(() => _charm = value),
        ),
    ];
    if (WindowSize.of(context).isCompact) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: context.l10n.cancel,
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(context.l10n.editSave),
            actions: [
              TextButton(onPressed: _submit, child: Text(context.l10n.save)),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final field in fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: field,
                ),
            ],
          ),
        ),
      );
    }
    return AlertDialog(
      title: Text(context.l10n.editSave),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: fields,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(context.l10n.save)),
      ],
    );
  }
}
