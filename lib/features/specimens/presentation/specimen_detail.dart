import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/utils/origin_mark.dart';
import 'package:ishinydex/core/widgets/action_sheet.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/confirm_dialog.dart';
import 'package:ishinydex/core/widgets/origin_mark_chip.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/form_info_tabs.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/location_flow.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_form_page.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/specimen_headline.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Detalhe do specimen em tela própria (layout compacto).
class SpecimenDetailPage extends StatelessWidget {
  const SpecimenDetailPage({required this.specimenId, super.key});

  final int specimenId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Espécime')),
    body: SpecimenDetailView(
      specimenId: specimenId,
      onReleased: () => context.go(Routes.specimens),
    ),
  );
}

/// Dados completos do specimen, nas abas do detalhe (resumo, status e
/// espécie), com a barra de ações: Editar e "Mais ações" (Ver no dex,
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
    final options = ref.watch(specimenOptionsProvider).value;
    final trainers = ref.watch(trainersProvider).value;
    final form = specimen.formRef;
    final ot = trainers?.where((t) => t.id == specimen.ot).firstOrNull;
    final fields = <(String, String?)>[
      ('Habilidade', choiceLabel(null, specimen.ability)),
      ('Natureza', choiceLabel(options?.nature, specimen.nature)),
      ('Gênero', choiceLabel(options?.gender, specimen.gender)),
      ('Idioma', choiceLabel(options?.language, specimen.language)),
      ('Treinador original', ot?.label),
      (
        'Data de captura',
        specimen.capturedAt == null
            ? null
            : MaterialLocalizations.of(context)
                  .formatCompactDate(specimen.capturedAt!),
      ),
      ('Observação', specimen.observation),
    ];
    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            if (specimen.isDeposited)
              const Chip(
                avatar: Icon(Icons.inventory_2, color: Colors.green),
                label: Text('Depositado'),
              )
            else
              const Chip(
                avatar: Icon(Icons.radio_button_unchecked),
                label: Text('Disponível'),
              ),
            if (OriginMark.fromSlug(specimen.originMark) case final mark?)
              OriginMarkChip(mark),
          ],
        ),
        const SizedBox(height: 8),
        for (final (name, value) in fields)
          if (value != null && value.isNotEmpty)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(name),
              subtitle: Text(value),
            ),
        if (specimen.location case final save?)
          LocationTile(save: save, since: specimen.locationSince),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: PokemonSprite(
                    url: specimen.spriteUrl,
                    size: 112,
                    semanticLabel: specimen.displayName,
                  ),
                ),
                const SizedBox(height: 8),
                SpecimenHeadline(
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
                  center: true,
                ),
                if (form != null)
                  Text(
                    '${form.displayName} · ${form.dexNumber}',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 12),
                if (form == null)
                  summary
                else
                  // Fora de um dex: a aba Espécie só mostra (não navega).
                  FormInfoTabs(
                    key: ValueKey('tabs-${specimen.id}'),
                    formId: form.id,
                    summary: summary,
                    nature: specimen.nature,
                  ),
              ],
            ),
          ),
        ),
        DetailActionBar(
          primary: form == null
              ? null
              : FilledButton.icon(
                  onPressed: () => _edit(context, ref, form),
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar espécime'),
                ),
          onMore: () => showActionSheet(
            context,
            title: specimen.displayName,
            actions: [
              if (specimen.isDeposited)
                SheetAction(
                  icon: Icons.catching_pokemon,
                  label: 'Ver no dex',
                  onSelected: () => _openInDex(context, ref),
                ),
              locationAction(
                context,
                ref,
                specimenId: specimen.id,
                name: specimen.displayName,
                away: specimen.isAway,
              ),
              if (specimen.slot case final slotId?)
                SheetAction(
                  icon: Icons.move_up,
                  label: 'Retirar do slot',
                  subtitle: 'Fica disponível no inventário',
                  onSelected: () => _withdraw(context, ref, slotId),
                ),
              SheetAction(
                icon: Icons.warning_amber_rounded,
                label: 'Libertar',
                subtitle: 'Apaga o cadastro (pede confirmação)',
                destructive: true,
                onSelected: () => _release(context, ref),
              ),
            ],
          ),
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
      if (context.mounted) _notify(context, failure.message);
      return;
    }
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('${specimen.displayName} retirado do slot.'),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () async {
            try {
              await repository.deposit(slotId: slotId, specimenId: specimen.id);
              refresh();
            } on AppFailure catch (failure) {
              messenger.showSnackBar(SnackBar(content: Text(failure.message)));
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
        _notify(context, 'O slot deste espécime não pertence a um dex.');
        return;
      }
      context.go(Routes.dex(dexId, boxId: slot.box.id, slotId: slot.id));
    } on AppFailure catch (failure) {
      if (context.mounted) _notify(context, failure.message);
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
    if (context.mounted) _notify(context, 'Espécime atualizado.');
  }

  Future<void> _release(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      icon: Icons.warning_amber_rounded,
      title: 'Libertar ${specimen.displayName}?',
      message: specimen.isDeposited
          ? 'O cadastro deste espécime será apagado e o slot ficará '
                'faltante. Esta ação não pode ser desfeita.'
          : 'O cadastro deste espécime será apagado. Esta ação não pode ser '
                'desfeita.',
      confirmLabel: 'Libertar',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(slotActionsProvider).releaseSpecimen(specimen.id);
      if (context.mounted) _notify(context, 'Espécime libertado.');
      onReleased();
    } on AppFailure catch (failure) {
      if (context.mounted) _notify(context, failure.message);
    }
  }

  void _notify(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
}
