import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/responsive/breakpoints.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/settings/settings_providers.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/specimen_filters.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Abre a edição em lote de [count] espécimes: bottom sheet no compacto,
/// diálogo nos demais. Devolve as alterações ao tocar em "Revisar", ou
/// `null` se o usuário fechou.
Future<SpecimenChanges?> showBulkEditSheet(BuildContext context, int count) {
  final panel = BulkEditPanel(count: count);
  if (WindowSize.of(context).isCompact) {
    return showModalBottomSheet<SpecimenChanges>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: panel,
      ),
    );
  }
  return showDialog<SpecimenChanges>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: panel,
      ),
    ),
  );
}

/// Confirmação com o resumo do que vai mudar. `true` = aplicar.
Future<bool> confirmBulkEdit(
  BuildContext context, {
  required int count,
  required List<String> summary,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Alterar $count ${count == 1 ? 'espécime' : 'espécimes'}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            for (final line in summary) Text('• $line'),
            const SizedBox(height: 8),
            const Text('Não é possível desfazer.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    ) ??
    false;

/// Formulário do lote. Todo campo começa em "Manter"; só o que mudar vai
/// para a API.
class BulkEditPanel extends ConsumerStatefulWidget {
  const BulkEditPanel({required this.count, super.key});

  final int count;

  @override
  ConsumerState<BulkEditPanel> createState() => _BulkEditPanelState();
}

class _BulkEditPanelState extends ConsumerState<BulkEditPanel> {
  SpecimenChanges _changes = const SpecimenChanges();

  void _update(SpecimenChanges changes) => setState(() => _changes = changes);

  @override
  Widget build(BuildContext context) {
    final options =
        ref.watch(specimenOptionsProvider).value ?? const SpecimenOptions();
    final trainers = ref.watch(trainersProvider).value ?? const <Trainer>[];
    final labels = BulkLabels(context, ref, options, trainers);
    final theme = Theme.of(context);
    final count = _changes.count;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Editar ${widget.count} '
                  '${widget.count == 1 ? 'espécime' : 'espécimes'}',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: _changes.isEmpty
                    ? null
                    : () => _update(const SpecimenChanges()),
                child: const Text('Limpar'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _EditTile(
                title: 'Pokébola',
                value: labels.pokeball(_changes.pokeball),
                onTap: () => _pick(
                  'Pokébola',
                  options.pokeball,
                  _changes.pokeball,
                  canRemove: true,
                  apply: (edit) => _changes.copyWith(pokeball: edit),
                ),
              ),
              _EditTile(
                title: 'Treinador original (OT)',
                value: labels.ot(_changes.ot),
                onTap: () => _pickOt(trainers),
              ),
              _EditTile(
                title: 'Natureza',
                value: labels.choice(_changes.nature, options.nature),
                onTap: () => _pick(
                  'Natureza',
                  options.nature,
                  _changes.nature,
                  apply: (edit) => _changes.copyWith(nature: edit),
                ),
              ),
              _EditTile(
                title: 'Idioma',
                value: labels.choice(_changes.language, options.language),
                onTap: () => _pick(
                  'Idioma',
                  options.language,
                  _changes.language,
                  apply: (edit) => _changes.copyWith(language: edit),
                ),
              ),
              _EditTile(
                title: 'Data de captura',
                value: labels.capturedAt(_changes.capturedAt),
                onTap: _pickCapturedAt,
              ),
              _Section(
                title: 'Gênero',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      label: const Text(keepLabel),
                      selected: _changes.gender is Keep,
                      onSelected: (_) =>
                          _update(_changes.copyWith(gender: const Keep())),
                    ),
                    for (final gender in options.gender)
                      ChoiceChip(
                        label: Text(gender.label),
                        selected: _changes.gender == SetTo(gender.value),
                        onSelected: (_) => _update(
                          _changes.copyWith(gender: SetTo(gender.value)),
                        ),
                      ),
                  ],
                ),
              ),
              _FlagRow(
                label: '$shinyEmoji Shiny',
                edit: _changes.isShiny,
                onChanged: (edit) => _update(_changes.copyWith(isShiny: edit)),
              ),
              _FlagRow(
                label: '$alphaEmoji Alfa',
                edit: _changes.isAlpha,
                onChanged: (edit) => _update(_changes.copyWith(isAlpha: edit)),
              ),
              _FlagRow(
                label: '$goEmoji GO',
                edit: _changes.isFromGo,
                onChanged: (edit) => _update(_changes.copyWith(isFromGo: edit)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: FilledButton(
            onPressed: _changes.isEmpty
                ? null
                : () => Navigator.of(context).pop(_changes),
            child: Text(
              _changes.isEmpty
                  ? 'Nada alterado'
                  : 'Revisar $count ${count == 1 ? 'alteração' : 'alterações'}',
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pick(
    String title,
    List<Choice> choices,
    FieldEdit<String> current, {
    required SpecimenChanges Function(FieldEdit<String>) apply,
    bool canRemove = false,
  }) async {
    final picked = await showEditPicker(
      context,
      title: title,
      choices: choices,
      current: current,
      canRemove: canRemove,
    );
    if (picked != null) _update(apply(picked));
  }

  Future<void> _pickOt(List<Trainer> trainers) async {
    final current = switch (_changes.ot) {
      Keep() => const Keep<String>(),
      SetTo(:final value) => SetTo(value?.toString()),
    };
    final picked = await showEditPicker(
      context,
      title: 'Treinador original (OT)',
      choices: [
        for (final t in trainers) Choice(value: '${t.id}', label: t.label),
      ],
      current: current,
      canRemove: true,
    );
    if (picked == null) return;
    _update(
      _changes.copyWith(
        ot: switch (picked) {
          Keep() => const Keep(),
          SetTo(:final value) => SetTo(value == null ? null : int.parse(value)),
        },
      ),
    );
  }

  Future<void> _pickCapturedAt() async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Data de captura'),
        children: [
          for (final (value, label) in const [
            ('keep', keepLabel),
            ('pick', 'Escolher data…'),
            ('remove', removeLabel),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(value),
              child: Text(label),
            ),
        ],
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'keep':
        _update(_changes.copyWith(capturedAt: const Keep()));
      case 'remove':
        _update(_changes.copyWith(capturedAt: const SetTo(null)));
      case 'pick':
        final now = DateTime.now();
        final date = await showDatePicker(
          context: context,
          // Só calendário, como nos filtros: a digitação usaria o formato do
          // locale, não o escolhido nos Ajustes.
          initialEntryMode: DatePickerEntryMode.calendarOnly,
          firstDate: DateTime(CaptureDatePattern.firstYear),
          lastDate: DateTime(now.year, now.month, now.day),
        );
        if (date != null) _update(_changes.copyWith(capturedAt: SetTo(date)));
    }
  }
}

const keepLabel = 'Manter';
const removeLabel = 'Remover';

/// Textos das alterações (linhas da folha e resumo da confirmação).
class BulkLabels {
  BulkLabels(BuildContext context, WidgetRef ref, this.options, this.trainers)
    : _pattern = capturePattern(context, ref);

  final SpecimenOptions options;
  final List<Trainer> trainers;
  final CaptureDatePattern _pattern;

  String choice(FieldEdit<String> edit, List<Choice> choices) => switch (edit) {
    Keep() => keepLabel,
    SetTo(value: null) => removeLabel,
    SetTo(:final String value) => labelsOf([value], choices).single,
  };

  String pokeball(FieldEdit<String> edit) => choice(edit, options.pokeball);

  String ot(FieldEdit<int> edit) => switch (edit) {
    Keep() => keepLabel,
    SetTo(value: null) => removeLabel,
    SetTo(:final int value) =>
      trainers.where((t) => t.id == value).firstOrNull?.label ?? '#$value',
  };

  String capturedAt(FieldEdit<DateTime> edit) => switch (edit) {
    Keep() => keepLabel,
    SetTo(value: null) => removeLabel,
    SetTo(:final DateTime value) => _pattern.format(value),
  };

  static String flag(FieldEdit<bool> edit) => switch (edit) {
    Keep() => keepLabel,
    SetTo(value: true) => 'Sim',
    SetTo() => 'Não',
  };

  /// Uma linha por campo alterado: "Pokébola → Dive Ball".
  List<String> summary(SpecimenChanges c) => [
    if (c.pokeball is SetTo) 'Pokébola → ${pokeball(c.pokeball)}',
    if (c.ot is SetTo) 'OT → ${ot(c.ot)}',
    if (c.nature is SetTo) 'Natureza → ${choice(c.nature, options.nature)}',
    if (c.language is SetTo) 'Idioma → ${choice(c.language, options.language)}',
    if (c.capturedAt is SetTo) 'Data de captura → ${capturedAt(c.capturedAt)}',
    if (c.gender is SetTo) 'Gênero → ${choice(c.gender, options.gender)}',
    if (c.isShiny is SetTo) 'Shiny → ${flag(c.isShiny)}',
    if (c.isAlpha is SetTo) 'Alfa → ${flag(c.isAlpha)}',
    if (c.isFromGo is SetTo) 'GO → ${flag(c.isFromGo)}',
  ];
}

class _EditTile extends StatelessWidget {
  const _EditTile({
    required this.title,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final changed = value != keepLabel;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: Text(
        value,
        style: changed
            ? TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              )
            : null,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        child,
      ],
    ),
  );
}

/// Flag com três estados numa linha: Manter | Sim | Não.
class _FlagRow extends StatelessWidget {
  const _FlagRow({
    required this.label,
    required this.edit,
    required this.onChanged,
  });

  final String label;
  final FieldEdit<bool> edit;
  final ValueChanged<FieldEdit<bool>> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
    child: Row(
      spacing: 8,
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleSmall),
        ),
        SegmentedButton<FieldEdit<bool>>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(value: Keep(), label: Text(keepLabel)),
            ButtonSegment(value: SetTo(true), label: Text('Sim')),
            ButtonSegment(value: SetTo(false), label: Text('Não')),
          ],
          selected: {edit},
          onSelectionChanged: (s) => onChanged(s.single),
        ),
      ],
    ),
  );
}

/// Escolha única com "Manter" (e "Remover", se [canRemove]) no topo; busca
/// quando há muitas opções. Devolve `null` se o usuário fechou.
Future<FieldEdit<String>?> showEditPicker(
  BuildContext context, {
  required String title,
  required List<Choice> choices,
  required FieldEdit<String> current,
  bool canRemove = false,
}) => showDialog<FieldEdit<String>>(
  context: context,
  builder: (context) => _EditPickerDialog(
    title: title,
    choices: choices,
    current: current,
    canRemove: canRemove,
  ),
);

class _EditPickerDialog extends StatefulWidget {
  const _EditPickerDialog({
    required this.title,
    required this.choices,
    required this.current,
    required this.canRemove,
  });

  final String title;
  final List<Choice> choices;
  final FieldEdit<String> current;
  final bool canRemove;

  @override
  State<_EditPickerDialog> createState() => _EditPickerDialogState();
}

class _EditPickerDialogState extends State<_EditPickerDialog> {
  static const _searchFrom = 8;

  String _search = '';

  @override
  Widget build(BuildContext context) {
    final search = foldForSearch(_search.trim());
    final options = <(FieldEdit<String>, String, String?)>[
      if (search.isEmpty) ...[
        (const Keep(), keepLabel, null),
        if (widget.canRemove) (const SetTo(null), removeLabel, null),
      ],
      for (final c in widget.choices)
        if (foldForSearch(c.label).contains(search))
          (SetTo(c.value), c.label, c.spriteUrl),
    ];
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.only(top: 8, bottom: 8),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.choices.length >= _searchFrom)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Buscar',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (text) => setState(() => _search = text),
                ),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final (edit, label, sprite) in options)
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      selected: edit == widget.current,
                      leading: Icon(
                        edit == widget.current
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      trailing: sprite == null
                          ? null
                          : PokemonSprite(url: sprite, size: 28),
                      title: Text(label),
                      onTap: () => Navigator.of(context).pop(edit),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
