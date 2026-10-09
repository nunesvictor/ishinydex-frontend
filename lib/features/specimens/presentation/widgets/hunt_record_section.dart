import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/choice_select.dart';

/// Seção recolhível "Registro da caçada" do formulário do espécime (#163):
/// método, contagem com a unidade, início e link do post. Só aparece com
/// Shiny ligado (quem decide é o formulário). Ao abrir pela primeira vez, o
/// início vem com hoje.
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

  Future<void> _pickStart() async {
    final now = widget.today ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _hunt.startedAt ?? now,
      firstDate: DateTime(1996),
      lastDate: now,
    );
    if (picked != null) _set(_hunt.copyWith(startedAt: picked));
  }

  void _expanded(bool open) {
    if (open && widget.value == null) {
      final now = widget.today ?? DateTime.now();
      _set(HuntRecord(startedAt: DateTime(now.year, now.month, now.day)));
    }
  }

  String get _summary {
    final hunt = widget.value;
    if (hunt == null || hunt.isBlank) {
      return 'Opcional: método, contagem, início e post';
    }
    return [
      ?_method(hunt.method)?.label,
      if (hunt.count case final count?) huntCountLabel(count, hunt.unit),
    ].join(' · ');
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
            ? 'Não existe em ${widget.game ?? 'o jogo do OT'}'
            : null);
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const ValueKey('hunt-record'),
        initiallyExpanded: !(widget.value?.isBlank ?? true),
        onExpansionChanged: _expanded,
        leading: Icon(Icons.track_changes, color: theme.colorScheme.primary),
        title: const Text('Registro da caçada'),
        subtitle: Text(_summary),
        shape: const Border(),
        // Respiro no topo: o rótulo do primeiro campo flutua acima da borda.
        childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          if (widget.methods.isNotEmpty || hunt.method != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ChoiceSelect(
                key: const ValueKey('field-hunt-method'),
                label: 'Método',
                value: hunt.method,
                choices: [
                  for (final m in {...widget.methods, ?_method(hunt.method)})
                    Choice(value: m.id, label: m.label),
                ],
                errorText: methodError,
                onChanged: _pickMethod,
              ),
            ),
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
                    decoration: const InputDecoration(labelText: 'Horas'),
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
                    decoration: const InputDecoration(labelText: 'Min'),
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
                      labelText: 'Contagem',
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
                        label: Text(huntUnitLabels[u] ?? u),
                      ),
                  ],
                  selected: {_unit},
                  showSelectedIcon: _units.length > 1,
                  onSelectionChanged: (v) => _changeUnit(v.single),
                ),
              ),
            ),
          ),
          if (widget.methods.isNotEmpty && widget.game != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Métodos de ${widget.game}, o jogo do OT',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ListTile(
            key: const ValueKey('field-hunt-start'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: const Text('Início da caçada'),
            subtitle: Text(
              widget.errorFor?.call('huntStartedAt') ??
                  switch ((start, end)) {
                    (null, _) => 'Não informado',
                    (final s?, final e?) =>
                      '${MaterialLocalizations.of(context).formatCompactDate(s)}'
                          ' · ${huntDuration(s, e)} até a captura',
                    (final s?, null) => MaterialLocalizations.of(
                      context,
                    ).formatCompactDate(s),
                  },
            ),
            trailing: start == null
                ? null
                : IconButton(
                    tooltip: 'Limpar o início',
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
              labelText: 'Link do post',
              helperText: 'Opcional · ex.: o post no r/ShinyPokemon',
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
