import 'package:flutter/material.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/form_details.dart';

/// Detalhes do slot selecionado com as ações: depositar (slot faltante) ou
/// editar/libertar o specimen (slot registrado).
class SlotDetailPanel extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
            '#${form.pokeapiId.toString().padLeft(4, '0')}'
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
                if (specimen.isShiny)
                  const Chip(avatar: Text(shinyEmoji), label: Text('Shiny')),
                if (specimen.isAlpha)
                  const Chip(avatar: Text(alphaEmoji), label: Text('Alfa')),
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
            Text(
              specimen.displayName,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
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
