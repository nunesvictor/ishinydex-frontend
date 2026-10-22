import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_labels.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/choice_select.dart';

/// Seção recolhível "Registro da caçada" do formulário do espécime (#163):
/// método, contagem com a unidade, início e link do post. Só aparece com
/// Shiny ligado (quem decide é o formulário). O início vem vazio (#294): uma
/// caçada já concluída raramente começou hoje; o "Encontrei!" já traz o
/// início da própria caçada.
class HuntRecordSection extends StatefulWidget {
  const HuntRecordSection({
    required this.value,
    required this.methods,
    required this.allMethods,
    required this.onChanged,
    this.game,
    this.capturedAt,
    this.errorFor,
    this.today,
    this.forms = const [],
    super.key,
  });

  final HuntRecord? value;

  /// Os métodos do jogo do OT; vazio = sem escolha de método (GO).
  final List<ShinyMethod> methods;

  /// Todos os métodos, para o nome de um escolhido que não é do jogo.
  final List<ShinyMethod> allMethods;
  final ValueChanged<HuntRecord?> onChanged;

  /// Nome do jogo do OT, para a dica do método.
  final String? game;
  final DateTime? capturedAt;
  final String? Function(String field)? errorFor;

  /// Hoje (nos testes, fixo).
  final DateTime? today;

  /// As pré-evoluções e a própria forma, nessa ordem (#315). Com mais de
  /// uma, o campo "Forma caçada": a do espécime é o padrão.
  final List<FormRef> forms;

  @override
  State<HuntRecordSection> createState() => _HuntRecordSectionState();
}

class _HuntRecordSectionState extends State<HuntRecordSection> {
  late final _count = TextEditingController(text: _countText());
  late final _hours = TextEditingController(text: _hoursText(hours: true));
  late final _minutes = TextEditingController(text: _hoursText(hours: false));
  late final _url = TextEditingController(text: widget.value?.postUrl);

  HuntRecord get _hunt => widget.value ?? const HuntRecord();

  String? _countText() =>
      _hunt.unit == 'hours' ? null : _hunt.count?.toString();

  String? _hoursText({required bool hours}) {
    final count = _hunt.count;
    if (_hunt.unit != 'hours' || count == null) return null;
    return (hours ? count ~/ 60 : count % 60).toString();
  }

  @override
  void dispose() {
    _count.dispose();
    _hours.dispose();
    _minutes.dispose();
    _url.dispose();
    super.dispose();
  }

  void _set(HuntRecord hunt) => widget.onChanged(hunt);

  ShinyMethod? _method(String? id) =>
      widget.allMethods.where((m) => m.id == id).firstOrNull;

  List<String> get _units =>
      _method(_hunt.method)?.units ?? const ['encounters', 'hours'];

  String get _unit => _units.contains(_hunt.unit) ? _hunt.unit! : _units.first;

  void _pickMethod(String? id) {
    final units = _method(id)?.units ?? const ['encounters', 'hours'];
    final unit = units.contains(_hunt.unit) ? _hunt.unit : units.first;
    _changeUnit(unit, _hunt.copyWith(method: id));
  }

  /// Trocar entre horas e outra unidade apaga a contagem (minutos não viram
  /// encontros).
  void _changeUnit(String? unit, [HuntRecord? base]) {
    var hunt = (base ?? _hunt).copyWith(unit: unit);
    if ((unit == 'hours') != (_hunt.unit == 'hours') && _hunt.unit != null) {
      hunt = hunt.copyWith(count: null);
      _count.clear();
      _hours.clear();
      _minutes.clear();
    }
    _set(hunt);
  }

  void _countChanged() {
    final int? count;
    if (_unit == 'hours') {
      final (h, m) = (int.tryParse(_hours.text), int.tryParse(_minutes.text));
      count = h == null && m == null ? null : (h ?? 0) * 60 + (m ?? 0);
    } else {
      count = int.tryParse(_count.text);
    }
    _set(_hunt.copyWith(count: count, unit: _unit));
  }

  /// O início vai até a data da captura (#294); sem ela, até hoje.
  Future<void> _pickStart() async {
    final now = widget.today ?? DateTime.now();
    final captured = widget.capturedAt;
    final last = captured != null && captured.isBefore(now) ? captured : now;
    final start = _hunt.startedAt;
    final picked = await showDatePicker(
      context: context,
      initialDate: start != null && !start.isAfter(last) ? start : last,
      firstDate: DateTime(1996),
      lastDate: last,
    );
    if (picked != null) _set(_hunt.copyWith(startedAt: picked));
  }

  String get _summary {
    final hunt = widget.value;
    if (hunt == null || hunt.isBlank) {
      return context.l10n.huntRecordOptional;
    }
    return [
      if (_method(hunt.method) case final m?)
        context.catalogText(m.label, m.labels),
      if (hunt.count case final count?)
        context.l10n.huntCount(count, hunt.unit),
    ].join(' · ');
  }

  /// "Forma caçada" (#315): o Naganadel caçado como Poipole.
  Widget _huntedForm(ThemeData theme, HuntRecord hunt) {
    final own = widget.forms.last.id;
    final current = hunt.huntedForm ?? own;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(context.l10n.huntedFormLabel, style: theme.textTheme.labelLarge),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in widget.forms)
                ChoiceChip(
                  key: ValueKey('field-hunted-form-${f.id}'),
                  avatar: PokemonSprite(
                    url: f.spriteFor(shiny: true),
                    size: 24,
                  ),
                  label: Text(f.displayName),
                  selected: f.id == current,
                  onSelected: (_) => widget.onChanged(
                    hunt.copyWith(huntedForm: f.id == own ? null : f.id),
                  ),
                ),
            ],
          ),
          Text(
            widget.errorFor?.call('huntHuntedForm') ??
                context.l10n.huntedFormHint,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hunt = _hunt;
    final start = hunt.startedAt;
    final end = widget.capturedAt;
    final digits = [FilteringTextInputFormatter.digitsOnly];
    final methodError =
        widget.errorFor?.call('huntMethod') ??
        (hunt.method != null &&
                widget.methods.isNotEmpty &&
                !widget.methods.any((m) => m.id == hunt.method)
            ? context.l10n.methodNotIn(widget.game ?? context.l10n.theOtGame)
            : null);
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const ValueKey('hunt-record'),
        initiallyExpanded: !(widget.value?.isBlank ?? true),
        leading: Icon(Icons.track_changes, color: theme.colorScheme.primary),
        title: Text(context.l10n.huntRecord),
        subtitle: Text(_summary),
        shape: const Border(),
        // Respiro no topo: o rótulo do primeiro campo flutua acima da borda.
        childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          if (widget.forms.length > 1) _huntedForm(theme, hunt),
          if (widget.methods.isNotEmpty || hunt.method != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ChoiceSelect(
                key: const ValueKey('field-hunt-method'),
                label: context.l10n.fieldMethod,
                value: hunt.method,
                choices: [
                  for (final m in {...widget.methods, ?_method(hunt.method)})
                    Choice(
                      value: m.id,
                      label: context.catalogText(m.label, m.labels),
                    ),
                ],
                errorText: methodError,
                onChanged: _pickMethod,
              ),
            ),
          // Com métodos para escolher, a contagem espera o método (#293): as
          // unidades são as dele. Uma contagem já salva sem método aparece.
          if (widget.methods.isNotEmpty &&
              hunt.method == null &&
              hunt.count == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                context.l10n.huntPickMethodFirst,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                if (_unit == 'hours') ...[
                  SizedBox(
                    width: 72,
                    child: TextField(
                      key: const ValueKey('field-hunt-hours'),
                      controller: _hours,
                      keyboardType: TextInputType.number,
                      inputFormatters: digits,
                      decoration: InputDecoration(
                        labelText: context.l10n.hoursLabel,
                      ),
                      onChanged: (_) => _countChanged(),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: TextField(
                      key: const ValueKey('field-hunt-minutes'),
                      controller: _minutes,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        ...digits,
                        LengthLimitingTextInputFormatter(2),
                      ],
                      decoration: InputDecoration(
                        labelText: context.l10n.minutesLabel,
                      ),
                      onChanged: (_) => _countChanged(),
                    ),
                  ),
                ] else
                  SizedBox(
                    width: 128,
                    child: TextField(
                      key: const ValueKey('field-hunt-count'),
                      controller: _count,
                      keyboardType: TextInputType.number,
                      inputFormatters: digits,
                      decoration: InputDecoration(
                        labelText: context.l10n.huntCountTitle,
                        errorText: widget.errorFor?.call('huntCount'),
                      ),
                      onChanged: (_) => _countChanged(),
                    ),
                  ),
              ],
            ),
            // Unidades numa linha própria: lado a lado com a contagem, passam
            // da largura do iPhone.
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    key: const ValueKey('field-hunt-unit'),
                    segments: [
                      for (final u in _units)
                        ButtonSegment(
                          value: u,
                          label: Text(context.l10n.huntUnit(u)),
                        ),
                    ],
                    selected: {_unit},
                    showSelectedIcon: _units.length > 1,
                    onSelectionChanged: (v) => _changeUnit(v.single),
                  ),
                ),
              ),
            ),
          ],
          if (widget.methods.isNotEmpty && widget.game != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                context.l10n.methodsOf(widget.game!),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ListTile(
            key: const ValueKey('field-hunt-start'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(context.l10n.huntStartTitle),
            subtitle: Text(
              widget.errorFor?.call('huntStartedAt') ??
                  switch ((start, end)) {
                    (null, _) => context.l10n.notInformed,
                    (final s?, final e?) => context.l10n.untilCapture(
                      MaterialLocalizations.of(context).formatCompactDate(s),
                      context.l10n.huntDuration(s, e),
                    ),
                    (final s?, null) => MaterialLocalizations.of(
                      context,
                    ).formatCompactDate(s),
                  },
            ),
            trailing: start == null
                ? null
                : IconButton(
                    tooltip: context.l10n.huntClearStart,
                    onPressed: () => _set(hunt.copyWith(startedAt: null)),
                    icon: const Icon(Icons.close),
                  ),
            onTap: _pickStart,
          ),
          TextField(
            key: const ValueKey('field-hunt-post'),
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: context.l10n.postLink,
              prefixIcon: const Icon(Icons.link),
              errorText: widget.errorFor?.call('huntPostUrl'),
            ),
            onChanged: (v) => _set(hunt.copyWith(postUrl: v.trim())),
          ),
        ],
      ),
    );
  }
}
