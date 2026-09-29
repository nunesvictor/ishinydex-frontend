import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/choice_select.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Cadastro de um specimen da forma [form], ou edição do specimen
/// [specimenId] quando informado. Retorna o [Specimen] criado/editado.
class SpecimenFormPage extends ConsumerWidget {
  const SpecimenFormPage({
    required this.form,
    this.specimenId,
    this.initialShiny = false,
    super.key,
  });

  final FormRef form;
  final int? specimenId;
  final bool initialShiny;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = specimenId;
    final detail = ref.watch(formDetailProvider(form.id));
    final options = ref.watch(specimenOptionsProvider);
    final trainers = ref.watch(trainersProvider);
    // No cadastro não há o que carregar: já começa "pronto" com null.
    final specimen = id == null
        ? const AsyncData<Specimen?>(null)
        : ref.watch(specimenProvider(id)).whenData<Specimen?>((s) => s);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          id == null ? 'Novo ${form.displayName}' : 'Editar espécime',
        ),
      ),
      body: switch ((detail, options, trainers, specimen)) {
        (
          AsyncData(value: final d),
          AsyncData(value: final o),
          AsyncData(value: final t),
          AsyncData(value: final s),
        ) =>
          SpecimenForm(
            form: d,
            options: o,
            trainers: t,
            initial: s,
            initialShiny: initialShiny,
          ),
        (AsyncError(:final error), _, _, _) ||
        (_, AsyncError(:final error), _, _) ||
        (_, _, AsyncError(:final error), _) ||
        (_, _, _, AsyncError(:final error)) => ErrorView(
          error: error,
          onRetry: () {
            ref
              ..invalidate(formDetailProvider(form.id))
              ..invalidate(specimenOptionsProvider)
              ..invalidate(trainersProvider);
            if (id != null) ref.invalidate(specimenProvider(id));
          },
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
    this.initial,
    this.initialShiny = false,
    super.key,
  });

  final FormDetail form;
  final SpecimenOptions options;
  final List<Trainer> trainers;

  /// Specimen em edição; `null` no cadastro.
  final Specimen? initial;
  final bool initialShiny;

  @override
  ConsumerState<SpecimenForm> createState() => _SpecimenFormState();
}

class _SpecimenFormState extends ConsumerState<SpecimenForm> {
  late final _nickname = TextEditingController(text: widget.initial?.nickname);
  late final _observation = TextEditingController(
    text: widget.initial?.observation,
  );
  late SpecimenDraft _draft = switch (widget.initial) {
    final Specimen specimen => SpecimenDraft.fromSpecimen(specimen),
    null => SpecimenDraft(form: widget.form.id, isShiny: widget.initialShiny),
  };
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
                  : Text(
                      widget.initial == null ? 'Salvar e depositar' : 'Salvar',
                    ),
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
    child: ChoiceSelect(
      key: ValueKey('field-$field'),
      label: label,
      value: value,
      choices: choices,
      errorText: _validation?.errorFor(field),
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
      final repository = ref.read(specimenRepositoryProvider);
      final initial = widget.initial;
      final saved = initial == null
          ? await repository.create(draft)
          : await repository.update(initial.id, draft);
      if (mounted) Navigator.of(context).pop(saved);
    } on AppFailure catch (failure) {
      setState(() {
        _saving = false;
        _validation = failure is ValidationFailure ? failure : null;
        _error = failure.message;
      });
    }
  }
}
