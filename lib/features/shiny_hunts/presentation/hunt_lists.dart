import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  const HuntCards({required this.paused, super.key});

  final bool paused;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return switch (ref.watch(shinyHuntsProvider)) {
      AsyncData(value: final all) => () {
        final hunts = [
          for (final h in all)
            if (h.paused == paused) h,
        ];
        final running = paused
            ? null
            : hunts.where((h) => h.running).firstOrNull;
        final empty = paused
            ? 'Nenhuma caçada pausada. Desistir de uma a traz para cá, com a '
                  'contagem guardada.'
            : 'Nenhuma caçada em andamento. Comece por um item de Faltam ou '
                  'pelo botão abaixo.';
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
                      'Caçadas que você deixou de lado. A contagem fica '
                      'guardada.',
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
                        'Cronômetro de ${running.formRef?.displayName} '
                        'rodando. As outras caçadas ficam bloqueadas até '
                        'você parar.',
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

/// "Começar caçada" da aba Em andamento: desabilitado com um cronômetro
/// rodando (não se começa outra caçada no meio de uma contada no relógio).
class StartHuntButton extends ConsumerWidget {
  const StartHuntButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = (ref.watch(shinyHuntsProvider).value ?? const <ShinyHunt>[])
        .any((h) => h.running);
    return FloatingActionButton.extended(
      heroTag: 'start-hunt',
      onPressed: running ? null : () => unawaited(startHuntFromPicker(context)),
      icon: const Icon(Icons.add),
      label: const Text('Começar caçada'),
    );
  }
}
