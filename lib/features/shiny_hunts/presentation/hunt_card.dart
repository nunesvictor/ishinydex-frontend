import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/widgets/game_icon.dart';
import 'package:ishinydex/core/widgets/mark_icons.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/shiny_hunts/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/presentation/start_hunt_sheet.dart';
import 'package:ishinydex/features/shiny_hunts/shiny_hunt_providers.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_form_page.dart';
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
    if (context.mounted) _notify(context, failure.message);
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

  @override
  void initState() {
    super.initState();
    _syncTick();
  }

  @override
  void didUpdateWidget(HuntCard old) {
    super.didUpdateWidget(old);
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
    super.dispose();
  }

  ShinyHuntActions get _actions => ref.read(shinyHuntActionsProvider);

  void _run(Future<void> Function() action) =>
      unawaited(runHuntAction(context, action));

  Future<void> _typeCount() async {
    final typed = await showDialog<int>(
      context: context,
      builder: (_) => _CountDialog(widget.hunt.count),
    );
    if (typed != null) {
      _run(() => _actions.save(widget.hunt.copyWith(count: typed)));
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
        : '${huntCountLabel(hunt.count, null)} '
              '${huntUnitLabels[hunt.unit] ?? hunt.unit}';
    final enabled = !widget.locked;
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
                          title: Text('Desistir (pausar)'),
                        ),
                      ),
                    ],
                  ),
              ],
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
                    child: Text(
                      countText,
                      key: const ValueKey('hunt-timer'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                  SizedBox(
                    width: 112,
                    height: 64,
                    child: hunt.running
                        ? FilledButton.tonal(
                            onPressed: () =>
                                _run(() => _actions.toggleTimer(hunt)),
                            child: const Text('Parar'),
                          )
                        : FilledButton(
                            onPressed: enabled
                                ? () => _run(() => _actions.toggleTimer(hunt))
                                : null,
                            child: const Text('Iniciar'),
                          ),
                  ),
                ],
              )
            else
              Row(
                spacing: 8,
                children: [
                  IconButton.outlined(
                    tooltip: 'Menos um',
                    onPressed: enabled
                        ? () => _run(() => _actions.add(hunt, -1))
                        : null,
                    icon: const Icon(Icons.remove),
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
                    child: FilledButton.icon(
                      onPressed: enabled
                          ? () => _run(() => _actions.add(hunt, 1))
                          : null,
                      icon: const Icon(Icons.add),
                      label: const Text('1'),
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
