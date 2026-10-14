import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/widgets/game_icon.dart';
import 'package:ishinydex/core/widgets/mark_icons.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/shiny_hunts/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/domain/shiny_odds.dart';
import 'package:ishinydex/features/shiny_hunts/presentation/start_hunt_sheet.dart';
import 'package:ishinydex/features/shiny_hunts/shiny_hunt_providers.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_form_page.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/home_tag.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

void _notify(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

/// Roda uma ação da caçada e mostra a falha, se houver.
Future<void> runHuntAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } on AppFailure catch (failure) {
    if (context.mounted) _notify(context, context.failureText(failure));
  }
}

/// "Encontrei!": abre o cadastro do espécime preenchido pela caçada; ao
/// salvar, a caçada sai da lista (o formulário a apaga).
Future<void> finishHunt(BuildContext context, ShinyHunt hunt) =>
    Navigator.of(context).push(
      MaterialPageRoute<Specimen>(
        builder: (_) => SpecimenFormPage(
          form: hunt.formRef!,
          fromHunt: hunt,
          depositAfterSave: false,
        ),
      ),
    );

/// Um cartão de caçada (#164): sprite, jogo e método, desde quando, e a
/// contagem com +1 grande (mobile first), −1 e tocar no número para
/// digitar; em horas, o cronômetro. Pausada: Retomar ou Excluir. [locked]:
/// outro cronômetro roda, e os controles ficam desabilitados.
class HuntCard extends ConsumerStatefulWidget {
  const HuntCard({required this.hunt, this.locked = false, super.key});

  final ShinyHunt hunt;
  final bool locked;

  @override
  ConsumerState<HuntCard> createState() => _HuntCardState();
}

class _HuntCardState extends ConsumerState<HuntCard> {
  Timer? _tick;

  /// Segurar +1/−1 (#209): o passo de cada repetição, os passos já dados e
  /// o que ainda não foi gravado. A contagem mostra o pendente na hora; a
  /// gravação é uma só, ao soltar.
  Timer? _repeat;
  int _repeats = 0;
  int _pending = 0;

  /// Os primeiros passos vão devagar; depois, acelera.
  static const _slowRepeats = 4;
  static const _slow = Duration(milliseconds: 400);
  static const _fast = Duration(milliseconds: 100);

  @override
  void initState() {
    super.initState();
    _syncTick();
  }

  @override
  void didUpdateWidget(HuntCard old) {
    super.didUpdateWidget(old);
    // A contagem gravada chegou: o pendente do segurar já está nela.
    if (old.hunt.count != widget.hunt.count && _repeat?.isActive != true) {
      _pending = 0;
    }
    _syncTick();
  }

  /// Com o cronômetro rodando, redesenha a cada 30 s.
  void _syncTick() {
    if (widget.hunt.running && _tick == null) {
      _tick = Timer.periodic(
        const Duration(seconds: 30),
        (_) => setState(() {}),
      );
    } else if (!widget.hunt.running) {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _repeat?.cancel();
    super.dispose();
  }

  void _startRepeat(int step) {
    _repeats = 0;
    _repeatStep(step);
  }

  void _repeatStep(int step) {
    // O −1 para no 0.
    if (widget.hunt.count + _pending + step < 0) return;
    setState(() => _pending += step);
    unawaited(HapticFeedback.selectionClick());
    _repeats++;
    _repeat = Timer(
      _repeats < _slowRepeats ? _slow : _fast,
      () => _repeatStep(step),
    );
  }

  /// Soltou: grava de uma vez o que andou. O pendente fica na tela até a
  /// contagem gravada chegar (ou a gravação falhar), sem piscar o valor
  /// antigo.
  void _endRepeat() {
    _repeat?.cancel();
    final delta = _pending;
    if (delta == 0) return;
    unawaited(
      runHuntAction(
        context,
        () => _actions.add(widget.hunt, delta),
      ).whenComplete(() {
        if (mounted) setState(() => _pending = 0);
      }),
    );
  }

  /// O botão de [step] com o segurar que repete.
  Widget _repeating(int step, {required bool enabled, required Widget child}) =>
      GestureDetector(
        onLongPressStart: enabled ? (_) => _startRepeat(step) : null,
        onLongPressEnd: (_) => _endRepeat(),
        onLongPressCancel: _endRepeat,
        child: child,
      );

  ShinyHuntActions get _actions => ref.read(shinyHuntActionsProvider);

  void _run(Future<void> Function() action) =>
      unawaited(runHuntAction(context, action));

  Future<void> _typeCount() async {
    final typed = await showDialog<int>(
      context: context,
      builder: (_) => _CountDialog(widget.hunt.count),
    );
    if (typed != null) {
      _run(() => _actions.setCount(widget.hunt, typed));
    }
  }

  /// Corrige o tempo de uma caçada em horas (#205): o valor digitado
  /// substitui o acumulado. Só com o cronômetro parado.
  Future<void> _typeTime() async {
    final typed = await showDialog<Duration>(
      context: context,
      builder: (_) => _DurationDialog(widget.hunt.elapsed(_actions.now())),
    );
    if (typed != null) {
      _run(
        () => _actions.save(
          widget.hunt.copyWith(accumulatedSeconds: typed.inSeconds),
        ),
      );
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir a caçada?'),
        content: Text(
          'A contagem de ${widget.hunt.formRef?.displayName ?? 'Pokémon'} '
          'será perdida.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok ?? false) _run(() => _actions.delete(widget.hunt.id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hunt = widget.hunt;
    final format = MaterialLocalizations.of(context).formatCompactDate;
    final now = _actions.now();
    final save = (ref.watch(savesProvider).value ?? const [])
        .where((s) => s.id == hunt.save)
        .firstOrNull;
    final method = ref
        .watch(shinyMethodsProvider)(null)
        .where((m) => m.id == hunt.method)
        .firstOrNull;
    final start = hunt.startedAt;
    final since = start == null
        ? 'sem data de início'
        : 'desde ${format(start)} · ${huntDuration(start, now)}';
    final countText = hunt.timed
        ? timerLabel(hunt.elapsed(now))
        : '${huntCountLabel(hunt.count + _pending, null)} '
              '${huntUnitLabels[hunt.unit] ?? hunt.unit}';
    final enabled = !widget.locked;
    final odds = ref.watch(huntOddsProvider)(hunt);
    return Card.outlined(
      key: ValueKey('hunt-card-${hunt.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            Row(
              spacing: 12,
              children: [
                PokemonSprite(
                  url: hunt.formRef?.spriteFor(shiny: true),
                  size: 48,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Row(
                        spacing: 6,
                        children: [
                          Flexible(
                            child: Text(
                              hunt.formRef?.displayName ?? '',
                              style: theme.textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const ShinyIcon(size: 14),
                        ],
                      ),
                      Row(
                        spacing: 6,
                        children: [
                          if (save?.trainer.version case final v?)
                            GameIcon(v, size: 18),
                          Flexible(
                            child: Text(
                              [?save?.game, ?method?.label].join(' · '),
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // O corte do HOME (#222): a caçada segue igual.
                          if (ref.watch(homeCutoffProvider)(
                                save?.trainer.version,
                              )
                              case final cutoff?)
                            HomeTag(cutoff),
                        ],
                      ),
                      Text(
                        hunt.paused && hunt.pausedAt != null
                            ? '$since · pausada em ${format(hunt.pausedAt!)}'
                            : since,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (!hunt.paused)
                  PopupMenuButton<String>(
                    tooltip: 'Mais ações',
                    onSelected: (action) => switch (action) {
                      'found' => unawaited(finishHunt(context, hunt)),
                      'edit' => unawaited(
                        showHuntSheet(context, editing: hunt),
                      ),
                      _ => _run(() => _actions.pause(hunt)),
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'found',
                        child: ListTile(
                          leading: ShinyIcon(size: 22),
                          title: Text('Encontrei!'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('Editar'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'pause',
                        child: ListTile(
                          leading: Icon(Icons.pause),
                          title: Text('Fazer uma pausa'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (odds != null && !hunt.paused)
              HuntOddsPanel(
                hunt: hunt,
                odds: odds,
                save: save,
                onBreak: enabled && hunt.chain > 0
                    ? () => _run(() => _actions.breakChain(hunt))
                    : null,
              ),
            if (hunt.paused)
              Row(
                spacing: 8,
                children: [
                  Expanded(child: Text(countText)),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    onPressed: _delete,
                    icon: const Icon(Icons.delete),
                    label: const Text('Excluir'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _run(() => _actions.resume(hunt)),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Retomar'),
                  ),
                ],
              )
            else if (hunt.timed)
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    // Tocar no tempo corrige o acumulado; com o relógio
                    // rodando, não (ele andaria enquanto você digita).
                    child: InkWell(
                      key: const ValueKey('hunt-time'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: enabled && !hunt.running ? _typeTime : null,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: 8,
                        children: [
                          // O ponto vermelho: o relógio está contando.
                          if (hunt.running)
                            Container(
                              key: const ValueKey('hunt-recording'),
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                countText,
                                key: const ValueKey('hunt-timer'),
                                style: theme.textTheme.headlineMedium,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 112,
                    height: 64,
                    // Parar em vermelho-claro, como um "gravando"; no tonal
                    // índigo, não parecia um botão de parar.
                    child: hunt.running
                        ? FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.errorContainer,
                              foregroundColor:
                                  theme.colorScheme.onErrorContainer,
                            ),
                            onPressed: () =>
                                _run(() => _actions.toggleTimer(hunt)),
                            icon: const Icon(Icons.stop),
                            label: const Text('Parar'),
                          )
                        : FilledButton.icon(
                            onPressed: enabled
                                ? () => _run(() => _actions.toggleTimer(hunt))
                                : null,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Iniciar'),
                          ),
                  ),
                ],
              )
            else
              Row(
                spacing: 8,
                children: [
                  _repeating(
                    -1,
                    enabled: enabled,
                    // O tooltip abriria no segurar e tomaria o gesto: no
                    // toque, só o mouse o mostra.
                    child: Tooltip(
                      message: 'Menos um (segure para repetir)',
                      triggerMode: TooltipTriggerMode.manual,
                      child: IconButton.outlined(
                        onPressed: enabled
                            ? () => _run(() => _actions.add(hunt, -1))
                            : null,
                        icon: const Icon(Icons.remove),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      key: const ValueKey('hunt-count'),
                      onPressed: enabled ? _typeCount : null,
                      child: Text(countText, style: theme.textTheme.titleLarge),
                    ),
                  ),
                  SizedBox(
                    width: 112,
                    height: 64,
                    child: _repeating(
                      1,
                      enabled: enabled,
                      child: FilledButton.icon(
                        onPressed: enabled
                            ? () => _run(() => _actions.add(hunt, 1))
                            : null,
                        icon: const Icon(Icons.add),
                        label: const Text('1'),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Digitar a contagem (tocar no número).
class _CountDialog extends StatefulWidget {
  const _CountDialog(this.count);

  final int count;

  @override
  State<_CountDialog> createState() => _CountDialogState();
}

class _CountDialogState extends State<_CountDialog> {
  late final _controller = TextEditingController(text: '${widget.count}');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Contagem'),
    content: TextField(
      key: const ValueKey('hunt-count-input'),
      controller: _controller,
      autofocus: true,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () =>
            Navigator.of(context).pop(int.tryParse(_controller.text)),
        child: const Text('OK'),
      ),
    ],
  );
}

/// Horas e minutos de uma caçada em horas (#205).
class _DurationDialog extends StatefulWidget {
  const _DurationDialog(this.elapsed);

  final Duration elapsed;

  @override
  State<_DurationDialog> createState() => _DurationDialogState();
}

class _DurationDialogState extends State<_DurationDialog> {
  late final _hours = TextEditingController(text: '${widget.elapsed.inHours}');
  late final _minutes = TextEditingController(
    text: '${widget.elapsed.inMinutes % 60}',
  );

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Tempo da caçada'),
    content: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        SizedBox(
          width: 88,
          child: TextField(
            key: const ValueKey('hunt-hours-input'),
            controller: _hours,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Horas'),
          ),
        ),
        SizedBox(
          width: 72,
          child: TextField(
            key: const ValueKey('hunt-minutes-input'),
            controller: _minutes,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            decoration: const InputDecoration(labelText: 'Min'),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(
          Duration(
            hours: int.tryParse(_hours.text) ?? 0,
            minutes: int.tryParse(_minutes.text) ?? 0,
          ),
        ),
        child: const Text('OK'),
      ),
    ],
  );
}

/// As odds no cartão (#221): a chance do próximo encontro, por que (Charm,
/// cadeia, a nota da regra), a cadeia com o "Quebrou" e a barra da chance
/// acumulada com o múltiplo. Em horas, só as odds.
class HuntOddsPanel extends StatelessWidget {
  const HuntOddsPanel({
    required this.hunt,
    required this.odds,
    this.save,
    this.onBreak,
    super.key,
  });

  final ShinyHunt hunt;
  final HuntOdds odds;
  final Save? save;
  final VoidCallback? onBreak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (:rule, :hasCharm) = odds;
    final chance = hunt.chance(rule, hasCharm: hasCharm);
    final charmOn = rule.charmApplies(hunt.form, hasCharm: hasCharm);
    final why = [
      if (rule.hasChain && hunt.chain > 0) 'cadeia ${hunt.chain}',
      if (rule.modifiers.any((m) => m.isNumber))
        for (final m in rule.modifiers)
          if (m.isNumber) '${m.label} ${hunt.modifiers[m.id] ?? m.min ?? 0}',
      if (charmOn)
        'Shiny Charm (do save)'
      else if (hasCharm && rule.charmCounts)
        'O Charm não vale para este encontro'
      else if (hasCharm)
        'O Charm não vale neste método',
      if (hunt.timed) 'em horas: só as odds',
    ];
    final miss = hunt.missChance(rule, hasCharm: hasCharm);
    final percent = ((1 - miss) * 100).round();
    final multiple = hunt.multiple(rule, hasCharm: hasCharm);
    final number = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Row(
          spacing: 10,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              chance > 0 ? oddsLabel(chance) : 'não pode ser shiny',
              key: const ValueKey('hunt-odds'),
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (why.isNotEmpty)
              Flexible(
                child: Text(why.join(' · '), style: theme.textTheme.bodySmall),
              ),
          ],
        ),
        if (rule.hasChain && !hunt.timed)
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Cadeia atual '),
                      TextSpan(
                        text: '${hunt.chain}',
                        style: theme.textTheme.titleMedium,
                      ),
                      TextSpan(
                        text:
                            '\nmaior cadeia: ${hunt.bestChain} · '
                            '${number.format(hunt.count)} no total',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              OutlinedButton(onPressed: onBreak, child: const Text('Quebrou')),
            ],
          ),
        if (!hunt.timed && hunt.count > 0) ...[
          LinearProgressIndicator(
            key: const ValueKey('hunt-odds-progress'),
            value: 1 - miss,
            borderRadius: BorderRadius.circular(4),
          ),
          Text(
            '$percent% das caçadas já teriam terminado · '
            '${multiple.toStringAsFixed(1).replaceAll('.', ',')}× '
            'as odds'
            '${hunt.estimated ? ' (estimativa: contagem digitada)' : ''}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
