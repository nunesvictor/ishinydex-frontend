import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/choice_select.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Abre o cadastro de treinador original. Retorna o [Trainer] criado, ou
/// `null` se o usuário cancelar.
Future<Trainer?> showNewTrainerDialog(BuildContext context) =>
    showDialog<Trainer>(
      context: context,
      builder: (_) => const NewTrainerDialog(),
    );

class NewTrainerDialog extends ConsumerStatefulWidget {
  const NewTrainerDialog({super.key});

  @override
  ConsumerState<NewTrainerDialog> createState() => _NewTrainerDialogState();
}

class _NewTrainerDialogState extends ConsumerState<NewTrainerDialog> {
  final _name = TextEditingController();
  final _trainerId = TextEditingController();
  String? _version;
  bool _saving = false;
  ValidationFailure? _validation;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _trainerId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Novo treinador'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              if (_error != null)
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              TextField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nome',
                  errorText: _validation?.errorFor('name'),
                ),
              ),
              TextField(
                controller: _trainerId,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'ID do treinador',
                  errorText: _validation?.errorFor('trainer_id'),
                ),
              ),
              _versionField(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }

  /// Versão é opcional: se a lista falhar, dá para salvar sem ela.
  Widget _versionField() => switch (ref.watch(versionsProvider)) {
    AsyncData(value: final versions) => ChoiceSelect(
      key: const ValueKey('field-version'),
      label: 'Versão do jogo (opcional)',
      value: _version,
      choices: [
        for (final v in versions) Choice(value: v.name, label: v.label),
      ],
      errorText: _validation?.errorFor('version'),
      onChanged: (v) => setState(() => _version = v),
    ),
    AsyncError() => Row(
      children: [
        const Expanded(child: Text('Não foi possível carregar as versões.')),
        TextButton(
          onPressed: () => ref.invalidate(versionsProvider),
          child: const Text('Tentar novamente'),
        ),
      ],
    ),
    _ => const LinearProgressIndicator(),
  };

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _validation = null;
      _error = null;
    });
    try {
      final trainer = await ref
          .read(specimenRepositoryProvider)
          .createTrainer(
            name: _name.text.trim(),
            trainerId: _trainerId.text.trim(),
            version: _version,
          );
      if (mounted) Navigator.of(context).pop(trainer);
    } on AppFailure catch (failure) {
      setState(() {
        _saving = false;
        _validation = failure is ValidationFailure ? failure : null;
        _error = failure.message;
      });
    }
  }
}
