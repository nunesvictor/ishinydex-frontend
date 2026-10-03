import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/widgets/confirm_dialog.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';

enum _DexMenuAction { progress, autoDeposit, edit, delete }

/// Menu "⋮" da barra do dex: progresso por geração, editar (nome e shiny
/// dex) e apagar. Fica num menu, e não em mais ícones, para o nome do dex
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
    return PopupMenuButton<_DexMenuAction>(
      tooltip: 'Mais opções',
      onSelected: (action) => switch (action) {
        _DexMenuAction.progress => onShowProgress(),
        _DexMenuAction.autoDeposit => onAutoDeposit(),
        _DexMenuAction.edit => showEditDexDialog(context, dex),
        _DexMenuAction.delete => deleteDex(context, ref, dex),
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _DexMenuAction.progress,
          child: ListTile(
            leading: Icon(Icons.bar_chart),
            title: Text('Progresso por geração'),
          ),
        ),
        const PopupMenuItem(
          value: _DexMenuAction.autoDeposit,
          child: ListTile(
            leading: Icon(Icons.auto_awesome_motion_outlined),
            title: Text('Depositar automaticamente'),
          ),
        ),
        const PopupMenuItem(
          value: _DexMenuAction.edit,
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Editar dex'),
          ),
        ),
        PopupMenuItem(
          value: _DexMenuAction.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: error),
            title: Text('Apagar dex', style: TextStyle(color: error)),
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
  if ((saved ?? false) && context.mounted) _notify(context, 'Dex atualizado.');
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
    title: 'Apagar ${dex.name}?',
    message:
        // Sem número: `registered` é o progresso (num shiny dex, só os
        // shiny), não a quantidade de espécimes depositados.
        'Os ${dex.total} slots deste dex ficam livres nas boxes. Os '
        'espécimes depositados continuam no inventário, como disponíveis. '
        'Esta ação não pode ser desfeita.',
    confirmLabel: 'Apagar',
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;
  try {
    await ref.read(dexActionsProvider).delete(dex.id);
    if (!context.mounted) return;
    _notify(context, 'Dex apagado.');
    context.go(Routes.dexes);
  } on AppFailure catch (failure) {
    if (context.mounted) _notify(context, failure.message);
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
        if (failure.errorFor('name') == null) _error = failure.message;
      });
    } on AppFailure catch (failure) {
      setState(() {
        _saving = false;
        _error = failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Editar dex'),
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
            labelText: 'Nome',
            errorText: _validation?.errorFor('name'),
          ),
          onSubmitted: (_) => _saving ? null : _save(),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Dex shiny'),
          subtitle: const Text('Mostra os sprites shiny e as caçadas.'),
          value: _isShinyDex,
          onChanged: (value) => setState(() => _isShinyDex = value),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: const Text('Salvar'),
      ),
    ],
  );
}
