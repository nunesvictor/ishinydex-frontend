import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/widgets/confirm_dialog.dart';
import 'package:ishinydex/features/moves/presentation/move_search_page.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/dex_update.dart';

enum _DexMenuAction { update, progress, autoDeposit, moves, edit, delete }

/// Menu "⋮" da barra do dex: progresso por geração, buscar golpes (#369),
/// editar (nome e shiny dex) e apagar. Fica num menu, e não em mais ícones, para o nome do dex
/// caber inteiro na barra do celular.
class DexMenu extends ConsumerWidget {
  const DexMenu({
    required this.dex,
    required this.onShowProgress,
    required this.onAutoDeposit,
    super.key,
  });

  final PersonalDex dex;
  final VoidCallback onShowProgress;
  final VoidCallback onAutoDeposit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = Theme.of(context).colorScheme.error;
    // O padrão mudou (#308): fica aqui até o usuário atualizar ou dizer
    // "Não atualizar", mesmo depois do "Agora não" do aviso.
    final update = pendingUpdate(ref, dex);
    return PopupMenuButton<_DexMenuAction>(
      tooltip: context.l10n.moreOptions,
      onSelected: (action) => switch (action) {
        _DexMenuAction.update => showDexUpdateSheet(context, dex),
        _DexMenuAction.progress => onShowProgress(),
        _DexMenuAction.autoDeposit => onAutoDeposit(),
        _DexMenuAction.moves => openMoveSearch(context),
        _DexMenuAction.edit => showEditDexDialog(context, dex),
        _DexMenuAction.delete => deleteDex(context, ref, dex),
      },
      itemBuilder: (context) => [
        if (update != null)
          PopupMenuItem(
            value: _DexMenuAction.update,
            child: ListTile(
              leading: const Icon(Icons.update),
              title: Text(context.l10n.dexUpdateMenu(updateChange(update))),
            ),
          ),
        PopupMenuItem(
          value: _DexMenuAction.progress,
          child: ListTile(
            leading: const Icon(Icons.bar_chart),
            title: Text(context.l10n.progressByGeneration),
          ),
        ),
        PopupMenuItem(
          value: _DexMenuAction.autoDeposit,
          child: ListTile(
            leading: const Icon(Icons.auto_awesome_motion_outlined),
            title: Text(context.l10n.autoDeposit),
          ),
        ),
        PopupMenuItem(
          value: _DexMenuAction.moves,
          child: ListTile(
            leading: const Icon(Icons.manage_search),
            title: Text(context.l10n.moveSearchTitle),
          ),
        ),
        PopupMenuItem(
          value: _DexMenuAction.edit,
          child: ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(context.l10n.dexEdit),
          ),
        ),
        PopupMenuItem(
          value: _DexMenuAction.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: error),
            title: Text(context.l10n.dexDelete, style: TextStyle(color: error)),
          ),
        ),
      ],
    );
  }
}

/// Diálogo para renomear o dex e trocar se é shiny dex.
Future<void> showEditDexDialog(BuildContext context, PersonalDex dex) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => _EditDexDialog(dex: dex),
  );
  if ((saved ?? false) && context.mounted) {
    _notify(context, context.l10n.dexUpdated);
  }
}

/// Confirma e apaga o dex; depois volta para a lista de dexes.
Future<void> deleteDex(
  BuildContext context,
  WidgetRef ref,
  PersonalDex dex,
) async {
  final confirmed = await showConfirmDialog(
    context,
    icon: Icons.warning_amber_rounded,
    title: context.l10n.deleteNamedQuestion(dex.name),
    message:
        // Sem número: `registered` é o progresso (num shiny dex, só os
        // shiny), não a quantidade de espécimes depositados.
        context.l10n.dexDeleteMessage(dex.total),
    confirmLabel: context.l10n.deleteAction,
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;
  try {
    await ref.read(dexActionsProvider).delete(dex.id);
    if (!context.mounted) return;
    _notify(context, context.l10n.dexDeleted);
    context.go(Routes.dexes);
  } on AppFailure catch (failure) {
    if (context.mounted) _notify(context, context.failureText(failure));
  }
}

void _notify(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

class _EditDexDialog extends ConsumerStatefulWidget {
  const _EditDexDialog({required this.dex});

  final PersonalDex dex;

  @override
  ConsumerState<_EditDexDialog> createState() => _EditDexDialogState();
}

class _EditDexDialogState extends ConsumerState<_EditDexDialog> {
  late final _name = TextEditingController(text: widget.dex.name);
  late bool _isShinyDex = widget.dex.isShinyDex;
  bool _saving = false;
  ValidationFailure? _validation;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _validation = null;
      _error = null;
    });
    try {
      await ref
          .read(dexActionsProvider)
          .update(
            widget.dex.id,
            name: _name.text.trim(),
            isShinyDex: _isShinyDex,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ValidationFailure catch (failure) {
      setState(() {
        _saving = false;
        _validation = failure;
        // Erros fora do nome (ex.: non_field_errors) vão para o topo.
        if (failure.errorsFor('name') == null) {
          _error = context.failureText(failure);
        }
      });
    } on AppFailure catch (failure) {
      setState(() {
        _saving = false;
        _error = context.failureText(failure);
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.dexEdit),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        TextField(
          controller: _name,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.l10n.fieldName,
            errorText: context.fieldError(_validation, 'name'),
          ),
          onSubmitted: (_) => _saving ? null : _save(),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.shinyDex),
          subtitle: Text(context.l10n.shinyDexEditSubtitle),
          value: _isShinyDex,
          onChanged: (value) => setState(() => _isShinyDex = value),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(context.l10n.save),
      ),
    ],
  );
}
