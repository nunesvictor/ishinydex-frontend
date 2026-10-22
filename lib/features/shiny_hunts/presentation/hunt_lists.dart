import 'dart:async';
import 'dart:math' as math;

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
        // A que está com o cronômetro rodando vai para o topo; depois, a
        // última retomada (#279).
        final resumed = paused ? null : ref.watch(resumedHuntProvider);
        int rank(ShinyHunt h) => h.running
            ? 0
            : h.id == resumed?.id
            ? 1
            : 2;
        final hunts = [
          for (final h in all)
            if (h.paused == paused) h,
        ]..sort((a, b) => rank(a).compareTo(rank(b)));
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
            final columns = huntColumns(constraints.maxWidth);
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
                // Em fileiras de [columns] cards de largura igual, que
                // preenchem a linha; na fileira, todos com a altura do mais
                // alto (o de cronômetro é mais alto que o de contador).
                for (var i = 0; i < hunts.length; i += columns)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 16,
                        children: [
                          for (var j = i; j < i + columns; j++)
                            Expanded(
                              child: j < hunts.length
                                  ? _Highlight(
                                      key: ValueKey(
                                        hunts[j].id == resumed?.id
                                            ? resumed
                                            : hunts[j].id,
                                      ),
                                      on: hunts[j].id == resumed?.id,
                                      child: HuntCard(
                                        hunt: hunts[j],
                                        locked:
                                            running != null &&
                                            running.id != hunts[j].id,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                        ],
                      ),
                    ),
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

/// O destaque do cartão retomado (#279): um contorno na cor principal que
/// some em 2 s. A chave muda a cada retomada, e o destaque recomeça.
class _Highlight extends StatelessWidget {
  const _Highlight({required this.on, required this.child, super.key});

  final bool on;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!on) return child;
    final color = Theme.of(context).colorScheme.primary;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: const Duration(seconds: 2),
      curve: Curves.easeIn,
      child: child,
      builder: (context, t, child) => DecoratedBox(
        key: const ValueKey('hunt-resumed-highlight'),
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: t), width: 3),
        ),
        child: child,
      ),
    );
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

/// Quantos cards de caçada cabem lado a lado em [width] (#312): cada um com
/// pelo menos [huntCardMinWidth], além das margens de 16 e do espaço de 16
/// entre eles. No celular, um; no iPad em retrato, dois; no PC, três ou
/// mais.
int huntColumns(double width) =>
    math.max(1, ((width - 32 + 16) / (huntCardMinWidth + 16)).floor());

/// A largura mínima de um card de caçada nas telas largas.
const huntCardMinWidth = 340.0;
