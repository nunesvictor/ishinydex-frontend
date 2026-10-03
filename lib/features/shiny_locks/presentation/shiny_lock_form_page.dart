import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/widgets/confirm_dialog.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/shiny_locks/domain/models.dart';
import 'package:ishinydex/features/shiny_locks/presentation/shiny_locks_page.dart';
import 'package:ishinydex/features/shiny_locks/shiny_lock_providers.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/form_picker.dart';

/// O que aconteceu no cadastro (`null` = fechou sem mudar nada).
enum ShinyLockFormResult { saved, deleted }

/// Cadastro de shiny lock: novo, ou a edição de [lock]. Abre em tela cheia
/// (Navigator raiz, cobrindo a barra inferior), como o cadastro de espécime.
Future<ShinyLockFormResult?> showShinyLockForm(
  BuildContext context, {
  ShinyLock? lock,
}) => Navigator.of(context, rootNavigator: true).push<ShinyLockFormResult>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => ShinyLockFormPage(lock: lock),
  ),
);

class ShinyLockFormPage extends ConsumerStatefulWidget {
  const ShinyLockFormPage({this.lock, super.key});

  /// `null` = novo shiny lock.
  final ShinyLock? lock;

  @override
  ConsumerState<ShinyLockFormPage> createState() => _ShinyLockFormPageState();
}

class _ShinyLockFormPageState extends ConsumerState<ShinyLockFormPage> {
  late final ShinyLockDraft _initial = widget.lock == null
      ? const ShinyLockDraft()
      : ShinyLockDraft.of(widget.lock!);
  late final _caption = TextEditingController(text: _initial.caption);
  late final _description = TextEditingController(text: _initial.description);
  late ShinyLockType _lockType = _initial.lockType;
  late bool _active = _initial.active;
  late List<FormRef> _forms = _initial.forms;

  bool _busy = false;

  /// Erros da API por campo (nome repetido, sem formas...).
  ValidationFailure? _validation;

  /// Outro erro (rede, servidor), no topo do formulário.
  String? _error;

  bool get _isNew => widget.lock == null;

  @override
  void dispose() {
    _caption.dispose();
    _description.dispose();
    super.dispose();
  }

  ShinyLockDraft get _draft => ShinyLockDraft(
    caption: _caption.text,
    description: _description.text,
    lockType: _lockType,
    active: _active,
    forms: _forms,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: Text(_isNew ? 'Novo shiny lock' : 'Editar shiny lock'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Salvar'),
            ),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        // Nas telas largas o formulário não estica até as bordas.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              TextField(
                controller: _caption,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => _clearError('caption'),
                decoration: InputDecoration(
                  labelText: 'Nome',
                  errorText: _validation?.errorFor('caption'),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _description,
                onChanged: (_) => _clearError('description'),
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Descrição (opcional)',
                  errorText: _validation?.errorFor('description'),
                ),
              ),
              const SizedBox(height: 24),
              Text('Tipo', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<ShinyLockType>(
                showSelectedIcon: false,
                segments: [
                  for (final type in ShinyLockTypeUi.ordered)
                    ButtonSegment(
                      value: type,
                      icon: Icon(type.icon),
                      label: Text(type.label),
                    ),
                ],
                selected: {_lockType},
                onSelectionChanged: (selected) =>
                    setState(() => _lockType = selected.single),
              ),
              const SizedBox(height: 8),
              Text(
                switch (_lockType) {
                  ShinyLockType.unobtainable =>
                    'Não existe shiny desta forma. Nas caçadas, ela só '
                        'aparece com "incluir shiny impossível".',
                  ShinyLockType.distroOnly =>
                    'Ainda dá para conseguir, por distribuição (evento). Nas '
                        'caçadas, aparece com o aviso.',
                },
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ativo'),
                subtitle: const Text('Inativo, o lock não vale nas caçadas.'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
              const SizedBox(height: 8),
              _formsHeader(theme),
              if (_validation?.errorFor('forms') case final error?)
                Text(error, style: TextStyle(color: theme.colorScheme.error)),
              for (final form in _forms)
                ListTile(
                  key: ValueKey('lock-form-${form.id}'),
                  contentPadding: EdgeInsets.zero,
                  leading: PokemonSprite(url: form.spriteUrl, size: 40),
                  title: Text(form.displayName),
                  subtitle: Text(form.dexNumber),
                  trailing: IconButton(
                    tooltip: 'Remover forma',
                    onPressed: () => setState(
                      () => _forms = [
                        for (final f in _forms)
                          if (f.id != form.id) f,
                      ],
                    ),
                    icon: const Icon(Icons.close),
                  ),
                ),
              if (!_isNew) ...[
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    onPressed: _busy ? null : _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Apagar shiny lock'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _formsHeader(ThemeData theme) => Row(
    children: [
      Expanded(
        child: Text(
          'Formas · ${_forms.length}',
          style: theme.textTheme.titleSmall,
        ),
      ),
      TextButton.icon(
        onPressed: _addForm,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar forma'),
      ),
    ],
  );

  /// Escolhe uma forma no seletor que já existe (o do cadastro de
  /// espécime). Forma repetida é ignorada; a lista fica na ordem da dex.
  Future<void> _addForm() async {
    final form = await showFormPicker(context);
    if (form == null || _forms.any((f) => f.id == form.id)) return;
    _clearError('forms');
    setState(() {
      _forms = [..._forms, form]
        ..sort(
          (a, b) => (a.nationalNumber ?? a.pokeapiId).compareTo(
            b.nationalNumber ?? b.pokeapiId,
          ),
        );
    });
  }

  /// O usuário mexeu no campo: o erro antigo dele sai da tela (os dos
  /// outros campos ficam até o próximo "Salvar").
  void _clearError(String field) {
    final validation = _validation;
    if (validation?.errorFor(field) == null) return;
    final rest = {...validation!.fieldErrors}..remove(field);
    setState(() => _validation = rest.isEmpty ? null : ValidationFailure(rest));
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _validation = null;
      _error = null;
    });
    final actions = ref.read(shinyLockActionsProvider);
    try {
      if (_isNew) {
        await actions.create(_draft);
      } else {
        await actions.update(widget.lock!.id, _draft);
      }
      if (mounted) Navigator.of(context).pop(ShinyLockFormResult.saved);
    } on ValidationFailure catch (failure) {
      setState(() {
        _busy = false;
        _validation = failure;
      });
    } on AppFailure catch (failure) {
      setState(() {
        _busy = false;
        _error = failure.message;
      });
    }
  }

  Future<void> _delete() async {
    final lock = widget.lock!;
    final confirmed = await showConfirmDialog(
      context,
      icon: Icons.warning_amber_rounded,
      title: 'Apagar ${lock.caption}?',
      message:
          'As formas deixam de ter este shiny lock e voltam a aparecer nas '
          'caçadas como as outras.',
      confirmLabel: 'Apagar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(shinyLockActionsProvider).delete(lock.id);
      if (mounted) Navigator.of(context).pop(ShinyLockFormResult.deleted);
    } on AppFailure catch (failure) {
      setState(() {
        _busy = false;
        _error = failure.message;
      });
    }
  }
}
