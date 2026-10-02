import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/utils/origin_mark.dart';
import 'package:ishinydex/core/widgets/origin_mark_chip.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/form_details.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/location_flow.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/specimen_headline.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Detalhes do slot selecionado com as ações: depositar (slot faltante) ou
/// editar/libertar o specimen (slot registrado).
///
/// O slot traz só o resumo do specimen (`SpecimenSummary`); gênero,
/// natureza e Pokémon GO vêm do specimen completo (`GET /specimens/{id}/`),
/// carregado à parte. Enquanto ele não chega (ou se falhar), o painel mostra
/// o resumo e as ações normalmente.
class SlotDetailPanel extends ConsumerWidget {
  const SlotDetailPanel({
    required this.slot,
    required this.onDeposit,
    required this.onEdit,
    required this.onRelease,
    super.key,
  });

  final Slot? slot;
  final VoidCallback onDeposit;
  final VoidCallback onEdit;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = slot;
    final form = current?.form;
    if (current == null || form == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Selecione um slot para ver os detalhes.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final theme = Theme.of(context);
    final specimen = current.specimen;
    final full = specimen == null
        ? null
        : ref.watch(specimenProvider(specimen.id)).value;
    final nature = choiceLabel(
      ref.watch(specimenOptionsProvider).value?.nature,
      full?.nature,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: PokemonSprite(
              url: current.spriteUrl,
              size: 128,
              semanticLabel: form.displayName,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            form.displayName,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          Text(
            '${form.dexNumber}'
            '${form.formName.isEmpty ? '' : ' · ${prettifyName(form.formName)}'}',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          Text(
            '${current.box.name} · linha ${current.row + 1}, coluna ${current.col + 1}',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FormDetails(
            formId: form.id,
            highlightAbility: current.specimen?.ability,
          ),
          const SizedBox(height: 16),
          if (specimen == null)
            const Chip(
              avatar: Icon(Icons.radio_button_unchecked),
              label: Text('Faltante'),
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                const Chip(
                  avatar: Icon(Icons.check_circle, color: Colors.green),
                  label: Text('Registrado'),
                ),
                if (OriginMark.fromSlug(full?.originMark) case final mark?)
                  OriginMarkChip(mark),
                if (nature != null)
                  // O ícone sozinho não diz o que é: o tooltip explica
                  // ("Natureza") no hover/toque longo e no leitor de tela.
                  Tooltip(
                    message: 'Natureza',
                    child: Chip(
                      avatar: const Icon(Icons.psychology_outlined),
                      label: Text(nature),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SpecimenHeadline(
              name: specimen.displayName,
              pokeballSpriteUrl: specimen.pokeballSpriteUrl,
              pokeballLabel: specimen.pokeball == null
                  ? null
                  : prettifyName(specimen.pokeball!),
              gender: full?.gender,
              isShiny: specimen.isShiny,
              isAlpha: specimen.isAlpha,
              style: theme.textTheme.titleMedium,
              center: true,
            ),
          ],
          const SizedBox(height: 16),
          if (specimen == null)
            FilledButton.icon(
              onPressed: onDeposit,
              icon: const Icon(Icons.move_to_inbox),
              label: const Text('Depositar'),
            )
          else ...[
            if (specimen.location case final save?) ...[
              LocationTile(save: save, since: specimen.locationSince),
              const SizedBox(height: 8),
            ],
            LocationActions(
              specimenId: specimen.id,
              name: specimen.displayName,
              away: specimen.location != null,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit),
              label: const Text('Editar espécime'),
            ),
            const SizedBox(height: 8),
            // Ação destrutiva: cor de erro do tema e ícone de alerta.
            OutlinedButton.icon(
              onPressed: onRelease,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error),
              ),
              icon: const Icon(Icons.warning_amber_rounded),
              label: const Text('Libertar'),
            ),
          ],
        ],
      ),
    );
  }
}

/// ♂/♀ com rótulo para o leitor de tela; sem ícone para `genderless` (e
/// quando o gênero não foi informado).
