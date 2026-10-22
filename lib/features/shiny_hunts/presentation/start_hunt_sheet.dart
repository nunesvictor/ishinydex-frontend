import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/domain/shiny_odds.dart';
import 'package:ishinydex/features/shiny_hunts/shiny_hunt_providers.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_labels.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/choice_select.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Abre a folha "Começar caçada" da [form], ou "Editar caçada" de [editing].
/// Devolve a caçada gravada, ou `null` se desistiu.
Future<ShinyHunt?> showHuntSheet(
  BuildContext context, {
  FormRef? form,
  ShinyHunt? editing,
}) => showModalBottomSheet<ShinyHunt>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => HuntSheet(form: form ?? editing!.formRef!, editing: editing),
);

class HuntSheet extends ConsumerStatefulWidget {
  const HuntSheet({required this.form, this.editing, super.key});

  final FormRef form;
  final ShinyHunt? editing;

  @override
  ConsumerState<HuntSheet> createState() => _HuntSheetState();
}

class _HuntSheetState extends ConsumerState<HuntSheet> {
  late ShinyHunt _hunt =
      widget.editing ??
      ShinyHunt(
        id: 0,
        form: widget.form.id,
        startedAt: ref.read(shinyHuntActionsProvider).today(),
      );
  bool _saving = false;
  String? _error;

  Future<void> _pickStart() async {
    final today = ref.read(shinyHuntActionsProvider).today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _hunt.startedAt ?? today,
      firstDate: DateTime(1996),
      lastDate: today,
    );
    if (picked != null) {
      setState(() => _hunt = _hunt.copyWith(startedAt: picked));
    }
  }

  /// Trocar o início depois de informado muda a duração: confirma antes.
  Future<bool> _confirmStart() async {
    final before = widget.editing?.startedAt;
    if (before == null || before == _hunt.startedAt) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: Text(context.l10n.huntChangeStartQuestion),
        content: Text(context.l10n.huntChangeStartMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.changeAction),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  /// Fecha a folha e abre Ajustes → Meus saves.
  void _addSave(BuildContext context) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go(Routes.saves);
  }

  Future<void> _submit() async {
    if (!await _confirmStart() || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await ref.read(shinyHuntActionsProvider).save(_hunt);
      if (mounted) Navigator.of(context).pop(saved);
    } on AppFailure catch (failure) {
      setState(() {
        _saving = false;
        _error = context.failureText(failure);
      });
    }
  }

  void _setModifier(String id, int value) => setState(
    () => _hunt = _hunt.copyWith(modifiers: {..._hunt.modifiers, id: value}),
  );

  /// Um modificador das odds (#221): até 4 opções em segmentos, mais numa
  /// lista; o numérico (Search Level) num campo.
  Widget _modifier(ThemeData theme, OddsModifier m) {
    final value = _hunt.modifiers[m.id] ?? m.min ?? 0;
    if (m.isNumber) {
      return TextFormField(
        key: ValueKey('field-hunt-mod-${m.id}'),
        initialValue: '$value',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: context.catalogText(m.label, m.labels),
          helperText: m.followsCount ? context.l10n.modifierFollowsCount : null,
        ),
        onChanged: (text) => _setModifier(
          m.id,
          (int.tryParse(text) ?? 0).clamp(m.min ?? 0, m.max ?? 1 << 30),
        ),
      );
    }
    if (m.options.length > 4) {
      return ChoiceSelect(
        key: ValueKey('field-hunt-mod-${m.id}'),
        label: context.catalogText(m.label, m.labels),
        value: '$value',
        choices: [
          for (final (i, o) in m.options.indexed)
            Choice(value: '$i', label: context.catalogText(o.label, o.labels)),
        ],
        onChanged: (v) => _setModifier(m.id, int.tryParse(v ?? '') ?? 0),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Text(
          context.catalogText(m.label, m.labels),
          style: theme.textTheme.labelLarge,
        ),
        SegmentedButton<int>(
          key: ValueKey('field-hunt-mod-${m.id}'),
          segments: [
            for (final (i, o) in m.options.indexed)
              ButtonSegment(
                value: i,
                label: Text(context.catalogText(o.label, o.labels)),
              ),
          ],
          selected: {value},
          showSelectedIcon: false,
          onSelectionChanged: (v) => _setModifier(m.id, v.single),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final huntable = ref.watch(huntableInProvider);
    // Só os saves de jogos onde a forma pode ser caçada (o já escolhido
    // fica, ao editar).
    final allSaves = ref.watch(savesProvider).value;
    final saves = [
      for (final s in allSaves ?? const <Save>[])
        if (s.id == _hunt.save || huntable(widget.form.id, s.trainer.version))
          s,
    ];
    final save = saves.where((s) => s.id == _hunt.save).firstOrNull;
    final methodsFor = ref.watch(shinyMethodsProvider);
    // Só pelo HOME, por ovo (#314): os métodos de ovo.
    final methods = methodsFor(save?.trainer.version, formId: widget.form.id);
    final method = methodsFor(null)
        .where((m) => m.id == _hunt.method)
        .firstOrNull;
    final units = method?.units ?? const ['encounters', 'hours'];
    final start = _hunt.startedAt;
    final rule = ref.watch(oddsRuleProvider)(_hunt.method, save);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Text(
              widget.editing == null
                  ? context.l10n.huntStart
                  : context.l10n.huntEdit,
              style: theme.textTheme.headlineSmall,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: PokemonSprite(
                url: widget.form.spriteFor(shiny: true),
                size: 48,
              ),
              title: Text(widget.form.displayName),
              subtitle: Text(widget.form.dexNumber),
            ),
            // Sem nenhum save (#246): a caçada vale do mesmo jeito; o save
            // só traz os métodos e as odds do jogo.
            if (allSaves != null && allSaves.isEmpty)
              _NoSaveHint(onAdd: () => _addSave(context)),
            if (saves.isNotEmpty)
              ChoiceSelect(
                key: const ValueKey('field-hunt-save'),
                label: context.l10n.fieldGame,
                value: _hunt.save?.toString(),
                choices: [
                  for (final s in saves)
                    Choice(
                      value: '${s.id}',
                      label: s.isOneWay
                          ? context.l10n.saveOneWay(s.title)
                          : s.title,
                    ),
                ],
                onChanged: (v) => setState(
                  () => _hunt = _hunt.copyWith(
                    save: int.tryParse(v ?? ''),
                    modifiers: const {},
                  ),
                ),
              ),
            if (methods.isNotEmpty)
              ChoiceSelect(
                key: const ValueKey('field-hunt-method'),
                label: context.l10n.fieldMethod,
                value: _hunt.method,
                choices: [
                  for (final m in {...methods, ?method})
                    Choice(
                      value: m.id,
                      label: context.catalogText(m.label, m.labels),
                    ),
                ],
                onChanged: (id) {
                  final picked = methods.where((m) => m.id == id).firstOrNull;
                  final units = picked?.units ?? const ['encounters', 'hours'];
                  setState(
                    () => _hunt = _hunt.copyWith(
                      method: id,
                      modifiers: const {},
                      unit: units.contains(_hunt.unit)
                          ? _hunt.unit
                          : units.first,
                    ),
                  );
                },
              ),
            if (rule != null) ...[
              for (final m in rule.visibleModifiers(_hunt.modifiers))
                _modifier(theme, m),
              _OddsPreview(hunt: _hunt, rule: rule, save: save!),
            ],
            Text(context.l10n.countIn, style: theme.textTheme.labelLarge),
            SegmentedButton<String>(
              key: const ValueKey('field-hunt-unit'),
              segments: [
                for (final u in units)
                  ButtonSegment(
                    value: u,
                    label: Text(context.l10n.huntUnit(u)),
                  ),
              ],
              selected: {
                if (units.contains(_hunt.unit)) _hunt.unit else units.first,
              },
              showSelectedIcon: units.length > 1,
              onSelectionChanged: (v) =>
                  setState(() => _hunt = _hunt.copyWith(unit: v.single)),
            ),
            ListTile(
              key: const ValueKey('field-hunt-start'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(context.l10n.fieldStart),
              subtitle: Text(
                start == null
                    ? context.l10n.huntStartOptional
                    : MaterialLocalizations.of(context)
                          .formatCompactDate(start),
              ),
              trailing: start == null
                  ? null
                  : IconButton(
                      tooltip: context.l10n.huntClearStart,
                      onPressed: () => setState(
                        () => _hunt = _hunt.copyWith(startedAt: null),
                      ),
                      icon: const Icon(Icons.close),
                    ),
              onTap: _pickStart,
            ),
            if (_error case final error?)
              Text(error, style: TextStyle(color: theme.colorScheme.error)),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(
                widget.editing == null
                    ? context.l10n.huntStartAction
                    : context.l10n.save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// O Charm (vindo do save) e a prévia das odds na folha da caçada.
class _OddsPreview extends StatelessWidget {
  const _OddsPreview({
    required this.hunt,
    required this.rule,
    required this.save,
  });

  final ShinyHunt hunt;
  final OddsRule rule;
  final Save save;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chance = hunt.chance(rule, hasCharm: save.hasShinyCharm);
    final charm = !rule.charmCounts
        ? context.l10n.charmNotForMethod
        : !save.canHaveShinyCharm
        ? context.l10n.charmNoneInGame
        : rule.charmApplies(hunt.form, hasCharm: save.hasShinyCharm)
        ? context.l10n.charmYes
        : save.hasShinyCharm
        ? context.l10n.charmNotForEncounter
        : context.l10n.charmNo;
    return Row(
      spacing: 12,
      children: [
        const Icon(Icons.auto_awesome, size: 20),
        Expanded(child: Text(charm, style: theme.textTheme.bodyMedium)),
        Text(
          chance > 0 ? oddsLabel(chance, context.l10n.localeName) : '—',
          key: const ValueKey('hunt-odds-preview'),
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// A dica da folha sem nenhum save, com o atalho para Ajustes → Meus saves.
class _NoSaveHint extends StatelessWidget {
  const _NoSaveHint({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                Expanded(child: Text(context.l10n.huntNoSaveHint)),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onAdd,
                child: Text(context.l10n.huntAddSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
