import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/game_icon.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Aba "Espécie": linha evolutiva, outras formas, os jogos do HOME em cuja
/// pokédex ela está e uma grade com gênero, captura, ciclos de ovo, estreia,
/// altura e peso.
///
/// Num dex ([dexId]), cada forma da linha evolutiva e das outras formas leva
/// ao slot dela ([onOpenSlot]); a que não está no dex fica esmaecida. Fora
/// de um dex (inventário, ficha da forma), não há slot: com [onOpenForm],
/// tocar abre a ficha da forma.
class SpeciesInfo extends ConsumerWidget {
  const SpeciesInfo({
    required this.form,
    this.dexId,
    this.onOpenSlot,
    this.onOpenForm,
    super.key,
  });

  final FormDetail form;
  final int? dexId;
  final ValueChanged<Slot>? onOpenSlot;
  final ValueChanged<FormRef>? onOpenForm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final related = [
      for (final stage in form.evolutionChain) ...stage,
      ...form.otherForms,
    ];
    final dexId = this.dexId;
    // Formas relacionadas → slot no dex. `null` = ainda não se sabe (ou fora
    // de um dex): nada esmaecido nem tocável.
    final slots = dexId == null || related.isEmpty
        ? null
        : ref
              .watch(
                formSlotsProvider((
                  dexId: dexId,
                  formIds: related.map((f) => f.id).toSet().join(','),
                )),
              )
              .value;
    final slotOf = {
      for (final slot in slots ?? const <Slot>[])
        if (slot.form case final f?) f.id: slot,
    };
    Widget item(FormRef ref, {required Widget child}) {
      final slot = slotOf[ref.id];
      final openSlot = onOpenSlot;
      final openForm = onOpenForm;
      final onTap = ref.id == form.id
          ? null
          : dexId != null
          ? (slot == null || openSlot == null ? null : () => openSlot(slot))
          : (openForm == null ? null : () => openForm(ref));
      return Opacity(
        opacity: slots != null && slot == null ? 0.45 : 1,
        child: InkWell(
          key: ValueKey('species-form-${ref.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: child,
        ),
      );
    }

    final facts = _facts();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        if (form.evolutionChain.isNotEmpty) ...[
          Text('Linha evolutiva', style: theme.textTheme.titleSmall),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final (i, stage) in form.evolutionChain.indexed) ...[
                if (i > 0) const Icon(Icons.chevron_right, size: 18),
                for (final ref in stage)
                  item(
                    ref,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        // A forma atual em destaque.
                        color: ref.id == form.id
                            ? theme.colorScheme.secondaryContainer
                            : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          PokemonSprite(url: ref.spriteUrl, size: 44),
                          Text(
                            ref.displayName,
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ],
        if (form.otherForms.isNotEmpty) ...[
          Text('Outras formas', style: theme.textTheme.titleSmall),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final ref in form.otherForms)
                item(
                  ref,
                  child: Chip(
                    avatar: PokemonSprite(url: ref.spriteUrl, size: 24),
                    label: Text(
                      ref.formName.isEmpty
                          ? ref.displayName
                          : prettifyName(ref.formName),
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (form.pokedexes.isNotEmpty) ...[
          Text('Na pokédex de', style: theme.textTheme.titleSmall),
          _Pokedexes(form.pokedexes),
        ],
        if (facts.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              // Três por linha no celular; mais nas telas largas.
              final columns = constraints.maxWidth >= 480 ? 6 : 3;
              final width =
                  (constraints.maxWidth - 8 * (columns - 1)) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (label, value) in facts)
                    SizedBox(
                      width: width,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label, style: theme.textTheme.labelSmall),
                              Text(
                                value,
                                style: theme.textTheme.labelLarge,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  List<(String, String)> _facts() => [
    if (form.genderRate case final rate?) ('Gênero', genderRatio(rate)),
    if (form.captureRate case final rate?) ('Captura', '$rate'),
    if (form.hatchCounter case final cycles?) ('Ciclos de ovo', '$cycles'),
    if (form.debutVersions.isNotEmpty)
      ('Estreia', form.debutVersions.map(prettifyName).join(' e ')),
    if (form.height case final height?) ('Altura', '${decimal(height / 10)} m'),
    if (form.weight case final weight?) ('Peso', '${decimal(weight / 10)} kg'),
  ];
}

/// Os jogos em cuja pokédex a espécie está, com cada pokédex e o número. Os
/// ícones ficam sempre coloridos (o cinza é das caçadas); os jogos em que o
/// usuário tem save vêm primeiro, com fundo e um selo.
class _Pokedexes extends ConsumerWidget {
  const _Pokedexes(this.games);

  final List<GamePokedex> games;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final owned = {
      for (final save in ref.watch(savesProvider).value ?? const <Save>[])
        ?save.trainer.version,
    };
    List<String> mine(GamePokedex game) => [
      ...game.versions.where(owned.contains),
    ];
    final ordered = [
      ...games.where((g) => mine(g).isNotEmpty),
      ...games.where((g) => mine(g).isEmpty),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        for (final game in ordered)
          DecoratedBox(
            decoration: BoxDecoration(
              color: mine(game).isEmpty
                  ? null
                  : theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                spacing: 12,
                children: [
                  // Largura de dois ícones: os nomes ficam alinhados. Um jogo
                  // só (Legends: Arceus, Z-A) fica no meio dessa largura.
                  SizedBox(
                    width: 47,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 3,
                      children: [
                        for (final version in game.versions) GameIcon(version),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(
                          game.versions.map(versionLabel).join(' / '),
                          style: theme.textTheme.bodyLarge,
                        ),
                        if (mine(game) case final versions
                            when versions.isNotEmpty)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              child: Text(
                                '${versions.length > 1 ? 'Seus' : 'Seu'}: '
                                '${versions.map(versionLabel).join(', ')}',
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                          ),
                        Text(
                          game.entries.map((e) => e.description).join(' · '),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        Text(
          'Estar na pokédex não garante que dá para capturar: pode ser só '
          'por evolução, troca ou evento.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Proporção de gênero a partir do `gender_rate` (oitavos de fêmea; -1 =
/// sem gênero): "♂ 87,5% · ♀ 12,5%", "Só macho", "Só fêmea".
String genderRatio(int rate) => switch (rate) {
  < 0 => 'Sem gênero',
  0 => 'Só macho',
  >= 8 => 'Só fêmea',
  _ => '♂ ${decimal((8 - rate) * 12.5)}% · ♀ ${decimal(rate * 12.5)}%',
};

/// Número com vírgula e sem ",0": 1.7 → "1,7"; 50.0 → "50".
String decimal(num value) => value == value.roundToDouble()
    ? '${value.round()}'
    : '$value'.replaceAll('.', ',');
