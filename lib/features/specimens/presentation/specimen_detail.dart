import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/utils/origin_mark.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/confirm_dialog.dart';
import 'package:ishinydex/core/widgets/more_actions.dart';
import 'package:ishinydex/core/widgets/origin_mark_chip.dart';
import 'package:ishinydex/core/widgets/success_icon.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/detail_body.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/form_sheet.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/location_flow.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_form_page.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/specimen_extras.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/specimen_headline.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Detalhe do specimen em tela própria (layout compacto).
class SpecimenDetailPage extends StatelessWidget {
  const SpecimenDetailPage({required this.specimenId, super.key});

  final int specimenId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.specimenTitle)),
    body: SpecimenDetailView(
      specimenId: specimenId,
      onReleased: () => context.go(Routes.specimens),
    ),
  );
}

/// Dados completos do specimen no corpo comum dos detalhes ([DetailBody]:
/// abas Espécime e Espécie), com a barra de ações: Editar e "Mais ações" (Ver no dex,
/// enviar ou trazer de volta, retirar do slot e libertar). Usado na tela
/// própria (compacto) e no painel ao lado da lista.
class SpecimenDetailView extends ConsumerWidget {
  const SpecimenDetailView({
    required this.specimenId,
    required this.onReleased,
    super.key,
  });

  final int specimenId;

  /// Chamado depois de libertar (o specimen deixou de existir).
  final VoidCallback onReleased;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(specimenProvider(specimenId))) {
        AsyncData(:final value) => _Details(
          specimen: value,
          onReleased: onReleased,
        ),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(specimenProvider(specimenId)),
        ),
        _ => const LoadingView(),
      };
}

class _Details extends ConsumerWidget {
  const _Details({required this.specimen, required this.onReleased});

  final Specimen specimen;
  final VoidCallback onReleased;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final form = specimen.formRef;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            // No PC, o painel passa de 1.000 px: sem limite, os campos e o
            // cartão de status se espalham pela largura toda (#250).
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: DetailBody(
                  spriteUrl: specimen.spriteUrl,
                  semanticLabel: specimen.displayName,
                  title: SpecimenHeadline(
                    name: specimen.displayName,
                    pokeballSpriteUrl: specimen.pokeballSpriteUrl,
                    pokeballLabel: specimen.pokeball == null
                        ? null
                        : prettifyName(specimen.pokeball!),
                    gender: specimen.gender,
                    isShiny: specimen.isShiny,
                    isAlpha: specimen.isAlpha,
                    isFromGo: specimen.isFromGo,
                    style: theme.textTheme.titleLarge,
                  ),
                  subtitle: form == null
                      ? null
                      : '${form.displayName} · ${form.dexNumber}',
                  formId: form?.id,
                  tabsKey: ValueKey('tabs-${specimen.id}'),
                  highlightAbility: specimen.ability,
                  chips: [
                    if (specimen.isDeposited)
                      Chip(
                        avatar: const SuccessIcon(Icons.inventory_2),
                        label: Text(context.l10n.depositedLabel),
                      )
                    else
                      Chip(
                        avatar: const Icon(Icons.radio_button_unchecked),
                        label: Text(context.l10n.availableLabel),
                      ),
                    if (OriginMark.fromSlug(specimen.originMark)
                        case final mark?)
                      OriginMarkChip(mark),
                    if (specimen.isVisitingChampions) const ChampionsChip(),
                    ?languageTag(context, ref, specimen.language),
                    ?homeTagOf(ref, specimen.location),
                  ],
                  fields: specimenFields(context, ref, specimen),
                  footer: specimenFooter(
                    save: specimen.location,
                    since: specimen.locationSince,
                    specimen: specimen,
                  ),
                  nature: specimen.nature,
                  // Fora de um dex não há slot: a forma tocada abre a ficha.
                  onOpenForm: (other) => showFormSheet(context, other),
                ),
              ),
            ),
          ),
        ),
        DetailActionBar(
          primary: form == null
              ? null
              : FilledButton.icon(
                  onPressed: () => _edit(context, ref, form),
                  icon: const Icon(Icons.edit),
                  label: Text(context.l10n.editSpecimen),
                ),
          actions: [
            if (specimen.isDeposited)
              MoreAction(
                icon: Icons.catching_pokemon,
                label: context.l10n.seeInDex,
                onSelected: () => _openInDex(context, ref),
              ),
            ...locationActions(
              context,
              ref,
              id: specimen.id,
              name: specimen.displayName,
              away: specimen.isAway,
              visiting: specimen.isVisitingChampions,
              location: specimen.location,
            ),
            if (specimen.slot case final slotId?)
              MoreAction(
                icon: Icons.move_up,
                label: context.l10n.withdrawFromSlot,
                subtitle: context.l10n.withdrawStaysAvailable,
                onSelected: () => _withdraw(context, ref, slotId),
              ),
            releaseAction(
              context.l10n,
              visiting: specimen.isVisitingChampions,
              onSelected: () => _release(context, ref),
            ),
          ],
        ),
      ],
    );
  }

  /// Tira do slot sem apagar; "Desfazer" deposita de novo no mesmo slot.
  Future<void> _withdraw(
    BuildContext context,
    WidgetRef ref,
    int slotId,
  ) async {
    final repository = ref.read(personalDexRepositoryProvider);
    void refresh() {
      ref.invalidate(specimenProvider(specimen.id));
      ref.read(slotActionsProvider).specimensChanged();
    }

    try {
      await repository.withdraw(slotId);
      refresh();
    } on AppFailure catch (failure) {
      if (context.mounted) _notify(context, context.failureText(failure));
      return;
    }
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final l10n = context.l10n;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.withdrawn(specimen.displayName)),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () async {
            try {
              await repository.deposit(slotId: slotId, specimenId: specimen.id);
              refresh();
            } on AppFailure catch (failure) {
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.problems(failure.problems))),
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _openInDex(BuildContext context, WidgetRef ref) async {
    try {
      final slot = await ref
          .read(personalDexRepositoryProvider)
          .fetchSlot(specimen.slot!);
      final dexId = slot.personalDex;
      if (!context.mounted) return;
      if (dexId == null) {
        _notify(context, context.l10n.slotNotInDex);
        return;
      }
      context.go(Routes.dex(dexId, boxId: slot.box.id, slotId: slot.id));
    } on AppFailure catch (failure) {
      if (context.mounted) _notify(context, context.failureText(failure));
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, FormRef form) async {
    final edited = await Navigator.of(context, rootNavigator: true)
        .push<Specimen>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) =>
                SpecimenFormPage(form: form, specimenId: specimen.id),
          ),
        );
    if (edited == null) return;
    ref.invalidate(specimenProvider(specimen.id));
    ref.read(slotActionsProvider).specimensChanged();
    if (context.mounted) _notify(context, context.l10n.specimenUpdated);
  }

  Future<void> _release(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      icon: Icons.warning_amber_rounded,
      title: context.l10n.releaseQuestion(specimen.displayName),
      message: specimen.isDeposited
          ? context.l10n.releaseMessage
          : context.l10n.releaseAvailableMessage,
      confirmLabel: context.l10n.releaseAction,
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(slotActionsProvider).releaseSpecimen(specimen.id);
      if (context.mounted) _notify(context, context.l10n.specimenReleased);
      onReleased();
    } on AppFailure catch (failure) {
      if (context.mounted) _notify(context, context.failureText(failure));
    }
  }

  void _notify(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
}
