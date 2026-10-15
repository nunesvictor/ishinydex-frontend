import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/features/shiny_hunts/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/presentation/hunt_card.dart';
import 'package:ishinydex/features/shiny_hunts/presentation/start_hunt_sheet.dart';
import 'package:ishinydex/features/shiny_hunts/shiny_hunt_providers.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/form_picker.dart';

/// Escolhe a forma e abre a folha "Começar caçada".
Future<void> startHuntFromPicker(BuildContext context) async {
  final form = await showFormPicker(context);
  if (form != null && context.mounted) {
    await showHuntSheet(context, form: form);
  }
}

/// As caçadas da aba ([paused] = Pausadas; senão, Em andamento). Em andamento
/// com um cronômetro rodando, as outras ficam bloqueadas, e uma faixa avisa.
/// No celular, uma coluna; no PC, cartões em grade.
class HuntCards extends ConsumerWidget {
  const HuntCards({required this.paused, this.hasDex = true, super.key});

  final bool paused;

  /// Há shiny dex: a dica da aba vazia aponta para o Faltam.
  final bool hasDex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return switch (ref.watch(shinyHuntsProvider)) {
      AsyncData(value: final all) => () {
        // A que está com o cronômetro rodando vai para o topo.
        final hunts = [
          for (final h in all)
            if (h.paused == paused && h.running) h,
          for (final h in all)
            if (h.paused == paused && !h.running) h,
        ];
        final running = paused
            ? null
            : hunts.where((h) => h.running).firstOrNull;
        final empty = paused
            ? context.l10n.huntsPausedEmpty
            : hasDex
            ? context.l10n.huntsActiveEmpty
            : context.l10n.huntsActiveEmptyNoDex;
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final cardWidth = wide ? 340.0 : constraints.maxWidth - 32;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                if (paused)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      context.l10n.huntsPausedNote,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                if (running != null)
                  Card.filled(
                    key: const ValueKey('hunt-running-banner'),
                    color: theme.colorScheme.errorContainer,
                    child: ListTile(
                      leading: Icon(
                        Icons.timer,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      title: Text(
                        context.l10n.huntTimerRunning(
                          running.formRef?.displayName ?? '',
                        ),
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                if (hunts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(empty, textAlign: TextAlign.center),
                  ),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    for (final h in hunts)
                      SizedBox(
                        width: cardWidth,
                        child: HuntCard(
                          hunt: h,
                          locked: running != null && running.id != h.id,
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        );
      }(),
      AsyncError(:final error) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(shinyHuntsProvider),
      ),
      _ => const LoadingView(),
    };
  }
}

/// "Começar caçada" da aba Ativas: some com um cronômetro rodando (não se
/// começa outra caçada no meio de uma contada no relógio; desabilitado, o
/// botão parecia ativo).
class StartHuntButton extends ConsumerWidget {
  const StartHuntButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = (ref.watch(shinyHuntsProvider).value ?? const <ShinyHunt>[])
        .any((h) => h.running);
    if (running) return const SizedBox.shrink();
    return FloatingActionButton.extended(
      heroTag: 'start-hunt',
      onPressed: () => unawaited(startHuntFromPicker(context)),
      icon: const Icon(Icons.add),
      label: Text(context.l10n.huntStart),
    );
  }
}
