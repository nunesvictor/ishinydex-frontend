import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/responsive/breakpoints.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/utils/origin_mark.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/mark_icons.dart';
import 'package:ishinydex/core/widgets/origin_mark_chip.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/settings/settings_providers.dart';
import 'package:ishinydex/features/shiny_hunts/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/shiny_hunt_providers.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/capture_date_field.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/choice_select.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/hunt_record_section.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/new_trainer_dialog.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Cadastro de um specimen da forma [form], ou edição do specimen
/// [specimenId] quando informado. Retorna o [Specimen] criado/editado.
class SpecimenFormPage extends ConsumerWidget {
  const SpecimenFormPage({
    required this.form,
    this.specimenId,
    this.initialShiny = false,
    this.depositAfterSave = true,
    this.fromHunt,
    super.key,
  });

  final FormRef form;
  final int? specimenId;
  final bool initialShiny;

  /// "Encontrei!" de uma caçada (#164): o cadastro vem preenchido por ela,
  /// que é apagada ao salvar.
  final ShinyHunt? fromHunt;

  /// `false` no cadastro avulso do inventário: o botão diz só "Salvar".
  final bool depositAfterSave;

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
          id == null
              ? context.l10n.newFormSpecimen(form.displayName)
              : context.l10n.editSpecimen,
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
            depositAfterSave: depositAfterSave,
            fromHunt: fromHunt,
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
    this.depositAfterSave = true,
    this.fromHunt,
    super.key,
  });

  final FormDetail form;
  final SpecimenOptions options;
  final List<Trainer> trainers;

  /// Specimen em edição; `null` no cadastro.
  final Specimen? initial;
  final bool initialShiny;
  final bool depositAfterSave;
  final ShinyHunt? fromHunt;

  @override
  ConsumerState<SpecimenForm> createState() => _SpecimenFormState();
}

class _SpecimenFormState extends ConsumerState<SpecimenForm> {
  late final _nickname = TextEditingController(text: widget.initial?.nickname);
  late final _observation = TextEditingController(
    text: widget.initial?.observation,
  );
  late SpecimenDraft _draft = switch ((widget.initial, widget.fromHunt)) {
    (final Specimen specimen, _) => SpecimenDraft.fromSpecimen(specimen),
    (null, final ShinyHunt hunt) => _fromHunt(
      SpecimenDraft(
        form: widget.form.id,
        capturedAt: ref.read(shinyHuntActionsProvider).today(),
      ),
      hunt,
    ),
    (null, null) => SpecimenDraft(
      form: widget.form.id,
      isShiny: widget.initialShiny,
    ),
  };

  /// A caçada que este cadastro encerra (apagada ao salvar).
  late int? _finishing = widget.fromHunt?.id;

  /// "Não" na pergunta "É o fim da caçada?".
  bool _huntDismissed = false;

  /// O cadastro com os dados da [hunt]: shiny, o registro da caçada e o OT
  /// do save dela (se o OT ainda não foi escolhido).
  SpecimenDraft _fromHunt(SpecimenDraft draft, ShinyHunt hunt) {
    final save = (ref.read(savesProvider).value ?? const <Save>[])
        .where((s) => s.id == hunt.save)
        .firstOrNull;
    final record = switch (ref.read(huntOddsProvider)(hunt)) {
      (:final rule, :final hasCharm) => hunt.toRecord(
        ref.read(shinyHuntActionsProvider).now(),
        rule: rule,
        hasCharm: hasCharm,
      ),
      null => hunt.toRecord(ref.read(shinyHuntActionsProvider).now()),
    };
    return draft.copyWith(
      isShiny: true,
      ot: draft.ot ?? save?.trainer.id,
      // Caçado como a pré-evolução (#315): o registro guarda qual.
      hunt: record.copyWith(
        huntedForm: hunt.form == widget.form.id ? null : hunt.form,
      ),
    );
  }

  /// Treinadores do select; os criados aqui entram sem recarregar a tela,
  /// para não perder o que já foi preenchido.
  late final List<Trainer> _trainers = [...widget.trainers];
  bool _saving = false;

  /// Erro do campo de data digitável; enquanto houver, não dá para salvar.
  Problem? _dateError;
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
                context.l10n.shinyLockedWarning,
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
                labelText: context.l10n.fieldNickname,
                errorText: context.fieldError(_validation, 'nickname'),
              ),
            ),
            const SizedBox(height: 12),
            _dropdown(
              label: context.l10n.fieldAbility,
              field: 'ability',
              value: _draft.ability,
              choices: [
                for (final a in form.abilities)
                  Choice(
                    value: a.ability,
                    label: a.isHidden
                        ? context.l10n.hiddenAbility(prettifyName(a.ability))
                        : prettifyName(a.ability),
                  ),
              ],
              onChanged: (v) => _draft = _draft.copyWith(ability: v),
            ),
            _dropdown(
              label: context.l10n.factGender,
              field: 'gender',
              value: _draft.gender,
              choices: options.gender,
              onChanged: (v) => _draft = _draft.copyWith(gender: v),
            ),
            _dropdown(
              label: context.l10n.fieldNature,
              field: 'nature',
              value: _draft.nature,
              choices: options.nature,
              onChanged: (v) => _draft = _draft.copyWith(nature: v),
            ),
            _dropdown(
              label: context.l10n.language,
              field: 'language',
              value: _draft.language,
              choices: options.language,
              onChanged: (v) => _draft = _draft.copyWith(language: v),
            ),
            _dropdown(
              label: context.l10n.filterPokeball,
              field: 'pokeball',
              value: _draft.pokeball,
              choices: options.pokeball,
              onChanged: (v) => _draft = _draft.copyWith(pokeball: v),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Expanded(
                  child: _dropdown(
                    label: context.l10n.originalTrainerOt,
                    field: 'ot',
                    value: _draft.ot?.toString(),
                    choices: [
                      for (final t in _trainers)
                        Choice(value: '${t.id}', label: t.label),
                    ],
                    onChanged: (v) => _setOt(v == null ? null : int.parse(v)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: IconButton.filledTonal(
                    tooltip: context.l10n.newTrainer,
                    onPressed: _newTrainer,
                    icon: const Icon(Icons.person_add_alt_1),
                  ),
                ),
              ],
            ),
            ?_originMark(),
            ?_originWarning(),
            _captureDate(),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              secondary: const ShinyIcon(size: 24, semanticLabel: null),
              title: Text(context.l10n.markShiny),
              value: _draft.isShiny,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(isShiny: v)),
            ),
            ?_huntQuestion(),
            ?_huntRecord(),
            ?_alpha(),
            TextField(
              controller: _observation,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: context.l10n.fieldObservation,
                errorText: context.fieldError(_validation, 'observation'),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving || _alphaBlocked ? null : _submit,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      widget.initial == null && widget.depositAfterSave
                          ? context.l10n.saveAndDeposit
                          : context.l10n.save,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Versão do jogo do OT escolhido.
  String? get _otVersion => _versionOf(_draft.ot);

  String? _versionOf(int? ot) => [
    for (final t in _trainers)
      if (t.id == ot) t.version,
  ].firstOrNull;

  /// A marca de origem que o espécime vai ter, como o backend a calcula
  /// (#360): o GO escolhido; senão, a do jogo do OT; sem jogo, a escolhida.
  String? get _mark {
    final version = _otVersion;
    if (_draft.markChoice == OriginMark.go.slug) return OriginMark.go.slug;
    if (version != null) return OriginMark.fromVersion(version)?.slug;
    return _draft.markChoice;
  }

  /// A marca é a do GO: OT do GO, GO Park ou a escolhida (#360).
  bool get _isGo => _mark == OriginMark.go.slug;

  /// A forma pode ser alfa com esta marca (#362).
  bool get _alphaAllowed =>
      ref.watch(alphaAllowedProvider)(widget.form.id, _mark);

  /// Alfa ligado sem poder ser (ex.: o OT mudou): salvar fica bloqueado.
  bool get _alphaBlocked => _draft.isAlpha && !_alphaAllowed;

  /// O switch "Alfa" (#362): só quando a marca e a forma permitem; ligado
  /// sem poder, fica com o erro (não desliga sozinho).
  Widget? _alpha() {
    if (!_alphaAllowed && !_draft.isAlpha) return null;
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      secondary: const AlphaIcon(size: 24, semanticLabel: null),
      title: Text(context.l10n.markAlpha),
      subtitle: _alphaBlocked
          ? Text(
              context.l10n.problemAlphaNotAllowed,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          : null,
      value: _draft.isAlpha,
      onChanged: (v) => setState(() => _draft = _draft.copyWith(isAlpha: v)),
    );
  }

  /// Troca o OT e só mantém a marca escolhida que ainda vale: com OT sem
  /// jogo, qualquer uma; com OT do Let's Go, o GO Park; senão, a do jogo.
  void _setOt(int? ot) {
    final version = _versionOf(ot);
    final choice = _draft.markChoice;
    _draft = _draft.copyWith(
      ot: ot,
      markChoice: switch (version) {
        null => choice,
        final v when letsGoVersions.contains(v) =>
          choice == OriginMark.go.slug ? choice : null,
        _ => null,
      },
    );
  }

  /// A marca de origem (#360). Com OT sem jogo (presentes do HOME,
  /// eventos), escolher; com OT do Let's Go, o switch do GO Park; com OT de
  /// outro jogo, só a linha com a marca dele, para conferir.
  Widget? _originMark() {
    final theme = Theme.of(context);
    final hintStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final version = _otVersion;
    if (version == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            ChoiceSelect(
              key: const ValueKey('field-mark-choice'),
              label: context.l10n.originMarkField,
              value: _draft.markChoice,
              choices: [
                for (final mark in OriginMark.values)
                  Choice(value: mark.slug, label: mark.label),
              ],
              leadingOf: (choice) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: OriginMarkIcon(OriginMark.fromSlug(choice.value)!),
              ),
              errorText: context.fieldError(_validation, 'mark_choice'),
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(markChoice: v)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(context.l10n.originMarkChoiceHint, style: hintStyle),
            ),
          ],
        ),
      );
    }
    final goPark = letsGoVersions.contains(version);
    final viaPark = goPark && _draft.markChoice == OriginMark.go.slug;
    final mark = viaPark ? OriginMark.go : OriginMark.fromVersion(version);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mark != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              spacing: 6,
              children: [
                IconTheme.merge(
                  data: IconThemeData(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  child: ExcludeSemantics(
                    child: OriginMarkIcon(mark, size: 16),
                  ),
                ),
                Flexible(
                  child: Text(
                    viaPark
                        ? context.l10n.originMarkGoPark
                        : context.l10n.originMarkFromOt(mark.label),
                    style: hintStyle,
                  ),
                ),
              ],
            ),
          ),
        if (goPark)
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            secondary: const GoIcon(size: 24, semanticLabel: null),
            title: Text(context.l10n.goParkTitle),
            subtitle: Text(context.l10n.goParkSubtitle),
            value: viaPark,
            onChanged: (v) => setState(
              () => _draft = _draft.copyWith(
                markChoice: v ? OriginMark.go.slug : null,
              ),
            ),
          ),
      ],
    );
  }

  /// O registro da caçada (#163), só com Shiny ligado. Desligar não apaga o
  /// que foi preenchido, mas ele não é salvo (o backend descarta).
  Widget? _huntRecord() {
    if (!_draft.isShiny) return null;
    final version = _otVersion;
    final methods = ref.watch(shinyMethodsProvider);
    return HuntRecordSection(
      // A resposta "Sim" troca o registro: a seção recomeça com ele.
      key: ValueKey('hunt-section-$_finishing'),
      value: _draft.hunt,
      methods: methods(version, fromGo: _isGo, formId: widget.form.id),
      allMethods: methods(null),
      forms: [
        ...ref.watch(preEvolutionsProvider)(widget.form.id),
        ?ref.watch(formRefOfProvider)(widget.form.id),
      ],
      game: version == null ? null : versionLabel(version),
      capturedAt: _draft.capturedAt,
      errorFor: (field) => context.fieldError(_validation, field),
      onChanged: (hunt) => setState(() => _draft = _draft.copyWith(hunt: hunt)),
    );
  }

  /// No cadastro direto de um shiny de uma forma com caçada em andamento:
  /// "É o fim da caçada?". Sim traz os dados dela e a encerra ao salvar.
  Widget? _huntQuestion() {
    if (widget.initial != null ||
        _finishing != null ||
        _huntDismissed ||
        !_draft.isShiny) {
      return null;
    }
    final hunt = (ref.watch(shinyHuntsProvider).value ?? const <ShinyHunt>[])
        .where((h) => !h.paused && h.aims(widget.form.id))
        .firstOrNull;
    if (hunt == null) return null;
    final theme = Theme.of(context);
    return Card.filled(
      key: const ValueKey('hunt-question'),
      color: theme.colorScheme.secondaryContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l10n.huntEndQuestion(prettifyName(widget.form.name))),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _huntDismissed = true),
                  child: Text(context.l10n.no),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _finishing = hunt.id;
                    _draft = _fromHunt(_draft, hunt);
                  }),
                  child: Text(context.l10n.yes),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Aviso (não erro) quando o Pokémon não está na pokédex do jogo do OT:
  /// pode ser um OT errado, ou um evento. Salvar continua valendo.
  Widget? _originWarning() {
    final version = _otVersion;
    if (version == null ||
        ref.watch(originFitsProvider)(widget.form.id, version)) {
      return null;
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 20,
                color: theme.colorScheme.onTertiaryContainer,
              ),
              Expanded(
                child: Text(
                  context.l10n.notInGamePokedex(
                    prettifyName(widget.form.name),
                    versionLabel(version),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
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
      errorText: context.fieldError(_validation, field),
      onChanged: (v) => setState(() => onChanged(v)),
    ),
  );

  /// No PC a data é digitável; no celular, tocar abre o calendário. Nos
  /// dois casos, no formato do idioma do app.
  Widget _captureDate() {
    final pattern = CaptureDatePattern(
      Localizations.localeOf(context).toString(),
    );
    if (isDesktopPlatform(Theme.of(context).platform)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CaptureDateField(
          key: const ValueKey('field-captured-at'),
          value: _draft.capturedAt,
          pattern: pattern,
          onChanged: (date, error) {
            _draft = _draft.copyWith(capturedAt: date);
            _dateError = error;
          },
          onPickFromCalendar: _pickDate,
        ),
      );
    }
    final date = _draft.capturedAt;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event),
      title: Text(context.l10n.captureDate),
      subtitle: Text(
        date == null ? context.l10n.notInformedFeminine : pattern.format(date),
      ),
      onTap: _pickDate,
    );
  }

  Future<void> _newTrainer() async {
    final created = await showNewTrainerDialog(context);
    if (created == null || !mounted) return;
    setState(() {
      _trainers.add(created);
      _setOt(created.id);
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _draft.capturedAt ?? now,
      firstDate: DateTime(1996),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _draft = _draft.copyWith(capturedAt: picked);
        _dateError = null;
      });
    }
  }

  Future<void> _submit() async {
    if (_dateError != null) {
      setState(() => _error = context.l10n.fixCaptureDate);
      return;
    }
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
      if (_finishing case final huntId?) {
        await ref.read(shinyHuntActionsProvider).delete(huntId);
      }
      if (mounted) Navigator.of(context).pop(saved);
    } on AppFailure catch (failure) {
      setState(() {
        _saving = false;
        _validation = failure is ValidationFailure ? failure : null;
        _error = context.failureText(failure);
      });
    }
  }
}
