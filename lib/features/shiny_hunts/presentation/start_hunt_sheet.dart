import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/shiny_hunt_providers.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
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
        title: const Text('Trocar a data de início?'),
        content: const Text(
          'A duração da caçada vai mudar. A contagem continua a mesma.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Trocar'),
          ),
        ],
      ),
    );
    return ok ?? false;
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
        _error = failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final huntable = ref.watch(huntableInProvider);
    // Só os saves de jogos onde a forma pode ser caçada (o já escolhido
    // fica, ao editar).
    final saves = [
      for (final s in ref.watch(savesProvider).value ?? const <Save>[])
        if (s.id == _hunt.save || huntable(widget.form.id, s.trainer.version))
          s,
    ];
    final save = saves.where((s) => s.id == _hunt.save).firstOrNull;
    final methodsFor = ref.watch(shinyMethodsProvider);
    final methods = methodsFor(save?.trainer.version);
    final method = methodsFor(null)
        .where((m) => m.id == _hunt.method)
        .firstOrNull;
    final units = method?.units ?? const ['encounters', 'hours'];
    final start = _hunt.startedAt;
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
              widget.editing == null ? 'Começar caçada' : 'Editar caçada',
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
            if (saves.isNotEmpty)
              ChoiceSelect(
                key: const ValueKey('field-hunt-save'),
                label: 'Jogo',
                value: _hunt.save?.toString(),
                choices: [
                  for (final s in saves)
                    Choice(value: '${s.id}', label: s.title),
                ],
                onChanged: (v) => setState(
                  () => _hunt = _hunt.copyWith(save: int.tryParse(v ?? '')),
                ),
              ),
            if (methods.isNotEmpty)
              ChoiceSelect(
                key: const ValueKey('field-hunt-method'),
                label: 'Método',
                value: _hunt.method,
                choices: [
                  for (final m in {...methods, ?method})
                    Choice(value: m.id, label: m.label),
                ],
                onChanged: (id) {
                  final picked = methods.where((m) => m.id == id).firstOrNull;
                  final units = picked?.units ?? const ['encounters', 'hours'];
                  setState(
                    () => _hunt = _hunt.copyWith(
                      method: id,
                      unit: units.contains(_hunt.unit)
                          ? _hunt.unit
                          : units.first,
                    ),
                  );
                },
              ),
            Text('Contar em', style: theme.textTheme.labelLarge),
            SegmentedButton<String>(
              key: const ValueKey('field-hunt-unit'),
              segments: [
                for (final u in units)
                  ButtonSegment(value: u, label: Text(huntUnitLabels[u] ?? u)),
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
              title: const Text('Início'),
              subtitle: Text(
                start == null
                    ? 'Opcional; dá para preencher depois'
                    : MaterialLocalizations.of(context)
                          .formatCompactDate(start),
              ),
              trailing: start == null
                  ? null
                  : IconButton(
                      tooltip: 'Limpar o início',
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
              child: Text(widget.editing == null ? 'Começar' : 'Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
