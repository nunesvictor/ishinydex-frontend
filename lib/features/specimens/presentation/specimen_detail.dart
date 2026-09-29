import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/confirm_dialog.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_form_page.dart';
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

/// Dados completos do specimen com as ações Editar, Libertar e Ver no dex.
/// Usado na tela própria (compacto) e no painel ao lado da lista.
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
    String? label(List<Choice>? choices, String? value) {
      if (value == null || value.isEmpty) return null;
      for (final c in choices ?? const <Choice>[]) {
        if (c.value == value) return c.label;
      }
      return prettifyName(value);
    }

    final ot = trainers?.where((t) => t.id == specimen.ot).firstOrNull;
    final fields = <(String, String?)>[
      ('Habilidade', label(null, specimen.ability)),
      ('Natureza', label(options?.nature, specimen.nature)),
      ('Gênero', label(options?.gender, specimen.gender)),
      ('Idioma', label(options?.language, specimen.language)),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: PokemonSprite(
              url: specimen.spriteUrl,
              size: 128,
              semanticLabel: specimen.displayName,
            ),
          ),
          const SizedBox(height: 8),
          // Selos junto do nome, como no admin ("Bulba ✨💢").
          Text(
            [
              specimen.displayName,
              if (specimen.isShiny) shinyEmoji,
              if (specimen.isAlpha) alphaEmoji,
              if (specimen.isFromGo) goEmoji,
            ].join(' '),
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          if (form != null)
            Text(
              '${form.displayName} · '
              '#${form.pokeapiId.toString().padLeft(4, '0')}',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 12),
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
              if (specimen.isShiny)
                const Chip(avatar: Text(shinyEmoji), label: Text('Shiny')),
              if (specimen.isAlpha)
                const Chip(avatar: Text(alphaEmoji), label: Text('Alfa')),
              if (specimen.isFromGo)
                const Chip(avatar: Text(goEmoji), label: Text('Pokémon GO')),
              if (specimen.pokeball != null)
                Chip(
                  avatar: PokemonSprite(
                    url: specimen.pokeballSpriteUrl,
                    size: 20,
                  ),
                  label: Text(prettifyName(specimen.pokeball!)),
                ),
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
          const SizedBox(height: 16),
          if (specimen.isDeposited) ...[
            FilledButton.tonalIcon(
              onPressed: () => _openInDex(context, ref),
              icon: const Icon(Icons.catching_pokemon),
              label: const Text('Ver no dex'),
            ),
            const SizedBox(height: 8),
          ],
          if (form != null) ...[
            FilledButton.icon(
              onPressed: () => _edit(context, ref, form),
              icon: const Icon(Icons.edit),
              label: const Text('Editar espécime'),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: () => _release(context, ref),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error),
            ),
            icon: const Icon(Icons.warning_amber_rounded),
            label: const Text('Libertar'),
          ),
        ],
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
