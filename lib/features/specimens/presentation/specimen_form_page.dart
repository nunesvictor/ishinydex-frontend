import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Cadastro de um specimen da forma [form]. Retorna o [Specimen] criado.
class SpecimenFormPage extends ConsumerWidget {
  const SpecimenFormPage({
    required this.form,
    this.initialShiny = false,
    super.key,
  });

  final FormRef form;
  final bool initialShiny;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(formDetailProvider(form.id));
    final options = ref.watch(specimenOptionsProvider);
    final trainers = ref.watch(trainersProvider);
    return Scaffold(
      appBar: AppBar(title: Text('Novo ${form.displayName}')),
      body: switch ((detail, options, trainers)) {
        (
          AsyncData(value: final d),
          AsyncData(value: final o),
          AsyncData(value: final t),
        ) =>
          SpecimenForm(
            form: d,
            options: o,
            trainers: t,
            initialShiny: initialShiny,
          ),
        (AsyncError(:final error), _, _) ||
        (_, AsyncError(:final error), _) ||
        (_, _, AsyncError(:final error)) => ErrorView(
          error: error,
          onRetry: () => ref
            ..invalidate(formDetailProvider(form.id))
            ..invalidate(specimenOptionsProvider)
            ..invalidate(trainersProvider),
        ),
        _ => const LoadingView(),
      },
    );
  }
}

class SpecimenForm extends ConsumerStatefulWidget {
  const SpecimenForm({
    required this.form,
    required this.options,
    required this.trainers,
    this.initialShiny = false,
    super.key,
  });

  final FormDetail form;
  final SpecimenOptions options;
  final List<Trainer> trainers;
  final bool initialShiny;

  @override
  ConsumerState<SpecimenForm> createState() => _SpecimenFormState();
}

class _SpecimenFormState extends ConsumerState<SpecimenForm> {
  final _nickname = TextEditingController();
  final _observation = TextEditingController();
  late SpecimenDraft _draft = SpecimenDraft(
    form: widget.form.id,
    isShiny: widget.initialShiny,
  );
  bool _saving = false;
  ValidationFailure? _validation;
  String? _error;

  @override
  void dispose() {
    _nickname.dispose();
    _observation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final form = widget.form;
    final options = widget.options;
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: PokemonSprite(
                url: _draft.isShiny ? form.shinySpriteUrl : form.spriteUrl,
                size: 96,
              ),
            ),
            if (form.isShinylocked)
              Text(
                'Atenção: esta forma é shiny-locked.',
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            TextField(
              controller: _nickname,
              decoration: InputDecoration(
                labelText: 'Apelido',
                errorText: _validation?.errorFor('nickname'),
              ),
            ),
            const SizedBox(height: 12),
            _dropdown(
              label: 'Habilidade',
              field: 'ability',
              value: _draft.ability,
              choices: [
                for (final a in form.abilities)
                  Choice(
                    value: a.ability,
                    label:
                        '${prettifyName(a.ability)}${a.isHidden ? ' (oculta)' : ''}',
                  ),
              ],
              onChanged: (v) => _draft = _draft.copyWith(ability: v),
            ),
            _dropdown(
              label: 'Gênero',
              field: 'gender',
              value: _draft.gender,
              choices: options.gender,
              onChanged: (v) => _draft = _draft.copyWith(gender: v),
            ),
            _dropdown(
              label: 'Natureza',
              field: 'nature',
              value: _draft.nature,
              choices: options.nature,
              onChanged: (v) => _draft = _draft.copyWith(nature: v),
            ),
            _dropdown(
              label: 'Idioma',
              field: 'language',
              value: _draft.language,
              choices: options.language,
              onChanged: (v) => _draft = _draft.copyWith(language: v),
            ),
            _dropdown(
              label: 'Pokébola',
              field: 'pokeball',
              value: _draft.pokeball,
              choices: options.pokeball,
              onChanged: (v) => _draft = _draft.copyWith(pokeball: v),
            ),
            _dropdown(
              label: 'Treinador original (OT)',
              field: 'ot',
              value: _draft.ot?.toString(),
              choices: [
                for (final t in widget.trainers)
                  Choice(value: '${t.id}', label: t.label),
              ],
              onChanged: (v) =>
                  _draft = _draft.copyWith(ot: v == null ? null : int.parse(v)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('Data de captura'),
              subtitle: Text(
                _draft.capturedAt == null
                    ? 'Não informada'
                    : MaterialLocalizations.of(context)
                          .formatMediumDate(_draft.capturedAt!),
              ),
              onTap: _pickDate,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Shiny'),
              value: _draft.isShiny,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(isShiny: v)),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              secondary: const Text(alphaEmoji, style: TextStyle(fontSize: 20)),
              title: const Text('Alfa'),
              value: _draft.isAlpha,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(isAlpha: v)),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Veio do Pokémon GO'),
              value: _draft.isFromGo,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(isFromGo: v)),
            ),
            TextField(
              controller: _observation,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Observação',
                errorText: _validation?.errorFor('observation'),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar e depositar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String field,
    required String? value,
    required List<Choice> choices,
    required ValueChanged<String?> onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String>(
      key: ValueKey('field-$field'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        errorText: _validation?.errorFor(field),
      ),
      items: [
        const DropdownMenuItem(child: Text('—')),
        for (final c in choices)
          DropdownMenuItem(value: c.value, child: Text(c.label)),
      ],
      onChanged: (v) => setState(() => onChanged(v)),
    ),
  );

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _draft.capturedAt ?? now,
      firstDate: DateTime(1996),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _draft = _draft.copyWith(capturedAt: picked));
    }
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _validation = null;
      _error = null;
    });
    final draft = _draft.copyWith(
      nickname: _nickname.text.trim(),
      observation: _observation.text.trim(),
    );
    try {
      final created = await ref.read(specimenRepositoryProvider).create(draft);
      if (mounted) Navigator.of(context).pop(created);
    } on AppFailure catch (failure) {
      setState(() {
        _saving = false;
        _validation = failure is ValidationFailure ? failure : null;
        _error = failure.message;
      });
    }
  }
}
