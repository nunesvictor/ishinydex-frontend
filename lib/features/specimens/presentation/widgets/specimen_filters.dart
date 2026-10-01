import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/responsive/breakpoints.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/utils/origin_mark.dart';
import 'package:ishinydex/core/widgets/origin_mark_chip.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/settings/data/date_format_storage.dart';
import 'package:ishinydex/features/settings/settings_providers.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Abre os filtros avançados do inventário: bottom sheet no compacto,
/// diálogo nos demais. Retorna a consulta nova ao aplicar, ou `null` se o
/// usuário fechou sem aplicar (as mudanças são descartadas).
Future<SpecimenQuery?> showSpecimenFilters(
  BuildContext context,
  SpecimenQuery query,
) {
  final panel = SpecimenFiltersPanel(initial: query);
  if (WindowSize.of(context).isCompact) {
    return showModalBottomSheet<SpecimenQuery>(
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
  return showDialog<SpecimenQuery>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: panel,
      ),
    ),
  );
}

/// Conteúdo da folha de filtros. Edita um rascunho da consulta; só o botão
/// "Mostrar resultados" devolve o rascunho para a tela.
///
/// Para caber no celular: conjuntos pequenos (tipo, geração, marca de
/// origem, gênero) viram chips; a ordem e os conjuntos grandes (pokébolas, OTs, naturezas,
/// idiomas) viram uma linha compacta que abre um seletor.
class SpecimenFiltersPanel extends ConsumerStatefulWidget {
  const SpecimenFiltersPanel({required this.initial, super.key});

  final SpecimenQuery initial;

  @override
  ConsumerState<SpecimenFiltersPanel> createState() =>
      _SpecimenFiltersPanelState();
}

class _SpecimenFiltersPanelState extends ConsumerState<SpecimenFiltersPanel> {
  late SpecimenQuery _draft = widget.initial;
  late final _ability = TextEditingController(text: widget.initial.ability);

  @override
  void dispose() {
    _ability.dispose();
    super.dispose();
  }

  void _update(SpecimenQuery draft) => setState(() => _draft = draft);

  void _clear() {
    _ability.clear();
    _update(_draft.clearAdvanced());
  }

  @override
  Widget build(BuildContext context) {
    final options =
        ref.watch(specimenOptionsProvider).value ?? const SpecimenOptions();
    final trainers = ref.watch(trainersProvider).value ?? const <Trainer>[];
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text('Filtros', style: theme.textTheme.titleLarge),
              ),
              TextButton(
                onPressed: _draft.advancedCount == 0 ? null : _clear,
                child: const Text('Limpar'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _PickerTile(
                title: 'Ordenar por',
                summary: _draft.ordering.label,
                onTap: _pickOrdering,
              ),
              _PickerTile(
                title: 'Pokébola',
                any: 'Todas',
                summary: _pokeballSummary(_draft, options),
                onTap: () => _pickPokeballs(options),
              ),
              _PickerTile(
                title: 'Treinador original (OT)',
                summary: _otSummary(_draft, trainers),
                onTap: () => _pickOts(trainers),
              ),
              _PickerTile(
                title: 'Natureza',
                any: 'Todas',
                summary: summarize(labelsOf(_draft.natures, options.nature)),
                onTap: () => _pickStrings(
                  'Natureza',
                  options.nature,
                  _draft.natures,
                  (values) => _draft.copyWith(natures: values),
                ),
              ),
              _PickerTile(
                title: 'Idioma',
                summary: summarize(
                  labelsOf(_draft.languages, options.language),
                ),
                onTap: () => _pickStrings(
                  'Idioma',
                  options.language,
                  _draft.languages,
                  (values) => _draft.copyWith(languages: values),
                ),
              ),
              _Section(
                title: 'Tipo (até ${SpecimenQuery.maxTypes})',
                child: _chips([
                  for (final type in options.type)
                    FilterChip(
                      avatar: type.spriteUrl == null
                          ? null
                          : PokemonSprite(url: type.spriteUrl, size: 18),
                      label: Text(type.label),
                      selected: _draft.types.contains(type.value),
                      onSelected: _canToggleType(type.value)
                          ? (on) => _update(
                              _draft.copyWith(
                                types: _toggle(_draft.types, type.value, on),
                              ),
                            )
                          : null,
                    ),
                ]),
              ),
              _Section(
                title: 'Geração',
                child: _chips([
                  for (final generation in options.generation)
                    FilterChip(
                      label: Text(generationNumber(generation.value)),
                      tooltip: generation.label,
                      selected: _draft.generations.contains(generation.value),
                      onSelected: (on) => _update(
                        _draft.copyWith(
                          generations: _toggle(
                            _draft.generations,
                            generation.value,
                            on,
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
              _Section(
                title: 'Marca de origem',
                child: _chips([
                  for (final choice in options.originMark)
                    FilterChip(
                      avatar: switch (OriginMark.fromSlug(choice.value)) {
                        final mark? => OriginMarkIcon(mark, size: 18),
                        null => null,
                      },
                      label: Text(choice.label),
                      // A sigla no chip; o nome dos jogos no tooltip.
                      tooltip: OriginMark.fromSlug(choice.value)?.games,
                      selected: _draft.originMarks.contains(choice.value),
                      onSelected: (on) => _update(
                        _draft.copyWith(
                          originMarks: _toggle(
                            _draft.originMarks,
                            choice.value,
                            on,
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
              _Section(
                title: 'Gênero',
                child: _chips([
                  for (final gender in options.gender)
                    FilterChip(
                      label: Text(gender.label),
                      selected: _draft.genders.contains(gender.value),
                      onSelected: (on) => _update(
                        _draft.copyWith(
                          genders: _toggle(_draft.genders, gender.value, on),
                        ),
                      ),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: TextField(
                  controller: _ability,
                  decoration: const InputDecoration(
                    labelText: 'Habilidade',
                    hintText: 'Parte do nome, ex.: levitate',
                    isDense: true,
                  ),
                  onChanged: (text) => _update(_draft.copyWith(ability: text)),
                ),
              ),
              _CaptureRangeTile(
                after: _draft.capturedAfter,
                before: _draft.capturedBefore,
                onChanged: (after, before) => _update(
                  _draft.copyWith(capturedAfter: after, capturedBefore: before),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(_draft),
            child: const Text('Mostrar resultados'),
          ),
        ),
      ],
    );
  }

  Widget _chips(List<Widget> chips) =>
      Wrap(spacing: 8, runSpacing: 4, children: chips);

  bool _canToggleType(String type) =>
      _draft.types.contains(type) ||
      _draft.types.length < SpecimenQuery.maxTypes;

  static List<T> _toggle<T>(List<T> values, T value, bool on) =>
      on ? [...values, value] : [...values.where((v) => v != value)];

  Future<void> _pickOrdering() async {
    final picked = await showDialog<SpecimenOrdering>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Ordenar por'),
        children: [
          for (final ordering in SpecimenOrdering.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(ordering),
              child: Row(
                spacing: 12,
                children: [
                  Icon(
                    ordering == _draft.ordering
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  Flexible(child: Text(ordering.label)),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked != null) _update(_draft.copyWith(ordering: picked));
  }

  Future<void> _pickPokeballs(SpecimenOptions options) async {
    final picked = await showChoicePicker(
      context,
      title: 'Pokébola',
      choices: [
        const Choice(value: SpecimenQuery.noneParam, label: 'Sem pokébola'),
        ...options.pokeball,
      ],
      selected: {
        ..._draft.pokeballs,
        if (_draft.withoutPokeball) SpecimenQuery.noneParam,
      },
    );
    if (picked == null) return;
    _update(
      _draft.copyWith(
        pokeballs: [...picked.where((v) => v != SpecimenQuery.noneParam)],
        withoutPokeball: picked.contains(SpecimenQuery.noneParam),
      ),
    );
  }

  Future<void> _pickOts(List<Trainer> trainers) async {
    final picked = await showChoicePicker(
      context,
      title: 'Treinador original (OT)',
      choices: [
        const Choice(value: SpecimenQuery.noneParam, label: 'Sem OT'),
        for (final t in trainers) Choice(value: '${t.id}', label: t.label),
      ],
      selected: {
        for (final id in _draft.ots) '$id',
        if (_draft.withoutOt) SpecimenQuery.noneParam,
      },
    );
    if (picked == null) return;
    _update(
      _draft.copyWith(
        ots: [...picked.map(int.tryParse).nonNulls],
        withoutOt: picked.contains(SpecimenQuery.noneParam),
      ),
    );
  }

  Future<void> _pickStrings(
    String title,
    List<Choice> choices,
    List<String> selected,
    SpecimenQuery Function(List<String>) apply,
  ) async {
    final picked = await showChoicePicker(
      context,
      title: title,
      choices: choices,
      selected: selected.toSet(),
    );
    if (picked != null) _update(apply([...picked]));
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

/// Linha compacta: o nome do filtro e o que está escolhido. Tocar abre o
/// seletor.
class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.title,
    required this.summary,
    required this.onTap,
    this.any = 'Todos',
  });

  final String title;
  final String? summary;
  final VoidCallback onTap;

  /// Texto quando nada está escolhido ("Todos"/"Todas").
  final String any;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    title: Text(title, style: Theme.of(context).textTheme.titleSmall),
    subtitle: Text(summary ?? any),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

/// Intervalo de datas de captura (calendário de intervalo do Material),
/// exibido no formato escolhido nos Ajustes.
class _CaptureRangeTile extends ConsumerWidget {
  const _CaptureRangeTile({
    required this.after,
    required this.before,
    required this.onChanged,
  });

  final DateTime? after;
  final DateTime? before;
  final void Function(DateTime? after, DateTime? before) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pattern = capturePattern(context, ref);
    final hasRange = after != null || before != null;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 24, right: 12),
      title: Text(
        'Data de captura',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      subtitle: Text(
        hasRange ? captureRangeLabel(pattern, after, before) : 'Qualquer data',
      ),
      trailing: hasRange
          ? IconButton(
              tooltip: 'Limpar datas',
              onPressed: () => onChanged(null, null),
              icon: const Icon(Icons.clear),
            )
          : const Icon(Icons.date_range),
      onTap: () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        // Só calendário: a digitação do Material usa o formato do locale
        // (dd/mm), e o app mostra datas no formato escolhido nos Ajustes
        // (padrão mm/dd, como no HOME). Tocando não há o que confundir.
        final range = await showDateRangePicker(
          context: context,
          initialEntryMode: DatePickerEntryMode.calendarOnly,
          firstDate: DateTime(CaptureDatePattern.firstYear),
          lastDate: today,
          initialDateRange: after != null && before != null
              ? DateTimeRange(start: after!, end: before!)
              : null,
          helpText: 'Capturados entre',
          saveText: 'OK',
        );
        if (range != null) onChanged(range.start, range.end);
      },
    );
  }
}

/// Seletor de múltipla escolha com busca (ignora maiúsculas e acentos).
/// Retorna os valores marcados ao confirmar, ou `null` ao cancelar.
Future<Set<String>?> showChoicePicker(
  BuildContext context, {
  required String title,
  required List<Choice> choices,
  required Set<String> selected,
}) => showDialog<Set<String>>(
  context: context,
  builder: (context) =>
      _ChoicePickerDialog(title: title, choices: choices, selected: selected),
);

class _ChoicePickerDialog extends StatefulWidget {
  const _ChoicePickerDialog({
    required this.title,
    required this.choices,
    required this.selected,
  });

  final String title;
  final List<Choice> choices;
  final Set<String> selected;

  @override
  State<_ChoicePickerDialog> createState() => _ChoicePickerDialogState();
}

class _ChoicePickerDialogState extends State<_ChoicePickerDialog> {
  /// Com poucas opções a busca só ocuparia espaço.
  static const _searchFrom = 8;

  late final Set<String> _selected = {...widget.selected};
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final search = foldForSearch(_search.trim());
    final visible = [
      for (final c in widget.choices)
        if (foldForSearch(c.label).contains(search)) c,
    ];
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.only(top: 8),
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
                  for (final c in visible)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      value: _selected.contains(c.value),
                      secondary: c.spriteUrl == null
                          ? null
                          : PokemonSprite(url: c.spriteUrl, size: 28),
                      title: Text(c.label),
                      onChanged: (on) => setState(
                        () => on!
                            ? _selected.add(c.value)
                            : _selected.remove(c.value),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(_selected.clear),
          child: const Text('Nenhum'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

/// Chips dos filtros avançados ativos, numa linha rolável; o X de cada um
/// limpa aquele filtro. Não ocupa espaço quando não há filtro ativo.
class ActiveFilterChips extends ConsumerWidget {
  const ActiveFilterChips({
    required this.query,
    required this.onChanged,
    super.key,
  });

  final SpecimenQuery query;
  final ValueChanged<SpecimenQuery> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.advancedCount == 0) return const SizedBox.shrink();
    final options =
        ref.watch(specimenOptionsProvider).value ?? const SpecimenOptions();
    final trainers = ref.watch(trainersProvider).value ?? const <Trainer>[];
    final pattern = capturePattern(context, ref);
    final q = query;
    final chips = <(String, SpecimenQuery)>[
      if (q.ordering != SpecimenOrdering.box)
        (q.ordering.label, q.copyWith(ordering: SpecimenOrdering.box)),
      if (q.hasPokeballFilter)
        (
          _pokeballSummary(q, options)!,
          q.copyWith(pokeballs: const [], withoutPokeball: false),
        ),
      if (q.types.isNotEmpty)
        (
          labelsOf(q.types, options.type).join(' / '),
          q.copyWith(types: const []),
        ),
      if (q.hasOtFilter)
        (
          'OT: ${_otSummary(q, trainers)}',
          q.copyWith(ots: const [], withoutOt: false),
        ),
      if (q.generations.isNotEmpty)
        (
          'Geração ${q.generations.map(generationNumber).join(', ')}',
          q.copyWith(generations: const []),
        ),
      if (q.originMarks.isNotEmpty)
        (
          'Origem: ${summarize(labelsOf(q.originMarks, options.originMark))}',
          q.copyWith(originMarks: const []),
        ),
      if (q.genders.isNotEmpty)
        (
          summarize(labelsOf(q.genders, options.gender))!,
          q.copyWith(genders: const []),
        ),
      if (q.natures.isNotEmpty)
        (
          summarize(labelsOf(q.natures, options.nature))!,
          q.copyWith(natures: const []),
        ),
      if (q.languages.isNotEmpty)
        (
          summarize(labelsOf(q.languages, options.language))!,
          q.copyWith(languages: const []),
        ),
      if (q.ability.trim().isNotEmpty)
        ('Habilidade: ${q.ability.trim()}', q.copyWith(ability: '')),
      if (q.hasCaptureFilter)
        (
          captureRangeLabel(pattern, q.capturedAfter, q.capturedBefore),
          q.copyWith(capturedAfter: null, capturedBefore: null),
        ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        spacing: 8,
        children: [
          for (final (label, cleared) in chips)
            InputChip(
              label: Text(label),
              visualDensity: VisualDensity.compact,
              deleteButtonTooltipMessage: 'Remover filtro',
              onDeleted: () => onChanged(cleared),
            ),
        ],
      ),
    );
  }
}

/// Labels dos [values] segundo as [choices] (valor sem label: formatado).
List<String> labelsOf(List<String> values, List<Choice> choices) => [
  for (final value in values)
    choices.where((c) => c.value == value).firstOrNull?.label ??
        prettifyName(value),
];

/// `[]` → `null`; `["A"]` → `"A"`; `["A", "B", "C"]` → `"A +2"`.
String? summarize(List<String> labels) => switch (labels) {
  [] => null,
  [final only] => only,
  [final first, ...final rest] => '$first +${rest.length}',
};

/// `"generation-iv"` → `"IV"`.
String generationNumber(String generation) =>
    generation.replaceFirst('generation-', '').toUpperCase();

/// `"01/02/2026 – 03/04/2026"`, `"Desde 01/02/2026"` ou `"Até 03/04/2026"`.
String captureRangeLabel(
  CaptureDatePattern pattern,
  DateTime? after,
  DateTime? before,
) => switch ((after, before)) {
  (final DateTime a, final DateTime b) =>
    '${pattern.format(a)} – ${pattern.format(b)}',
  (final DateTime a, null) => 'Desde ${pattern.format(a)}',
  (null, final DateTime b) => 'Até ${pattern.format(b)}',
  (null, null) => '',
};

/// Formato de data escolhido nos Ajustes (o mesmo do formulário).
CaptureDatePattern capturePattern(BuildContext context, WidgetRef ref) =>
    CaptureDatePattern(
      ref.watch(captureDateFormatProvider).value ?? CaptureDateFormat.home,
      Localizations.localeOf(context).toString(),
    );

String? _pokeballSummary(SpecimenQuery q, SpecimenOptions options) =>
    summarize([
      if (q.withoutPokeball) 'Sem pokébola',
      ...labelsOf(q.pokeballs, options.pokeball),
    ]);

String? _otSummary(SpecimenQuery q, List<Trainer> trainers) => summarize([
  if (q.withoutOt) 'Sem OT',
  for (final id in q.ots)
    trainers.where((t) => t.id == id).firstOrNull?.name ?? '#$id',
]);
