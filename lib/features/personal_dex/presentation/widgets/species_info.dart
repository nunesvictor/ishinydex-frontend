import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/chip_icons.dart';
import 'package:ishinydex/core/widgets/game_icon.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/core/widgets/version_tag.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_labels.dart';
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
    this.beforeFacts,
    super.key,
  });

  final FormDetail form;

  /// Entra entre "Na pokédex de" e os dados da espécie: o quadro Tipos em
  /// batalha (#274).
  final Widget? beforeFacts;
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

    final facts = _facts(context.l10n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        if (form.evolutionChain.isNotEmpty) ...[
          Text(context.l10n.evolutionLine, style: theme.textTheme.titleSmall),
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
          Text(
            context.l10n.speciesOtherForms,
            style: theme.textTheme.titleSmall,
          ),
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
          Text(context.l10n.inPokedexOf, style: theme.textTheme.titleSmall),
          _Pokedexes(form.pokedexes),
        ],
        ?beforeFacts,
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

  List<(String, String)> _facts(AppLocalizations l10n) => [
    if (form.genderRate case final rate?)
      (l10n.factGender, genderRatio(l10n, rate)),
    if (form.captureRate case final rate?) (l10n.factCatchRate, '$rate'),
    if (form.hatchCounter case final cycles?) (l10n.factEggCycles, '$cycles'),
    if (form.debutVersions.isNotEmpty)
      (
        l10n.factDebut,
        joinLabels(l10n, [...form.debutVersions.map(prettifyName)]),
      ),
    if (form.height case final height?)
      (l10n.factHeight, '${decimal(l10n, height / 10)} m'),
    if (form.weight case final weight?)
      (l10n.factWeight, '${decimal(l10n, weight / 10)} kg'),
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
    // Os saves do usuário em que a forma aparece: num exclusivo (o
    // Koraidon só no Scarlet), o save da outra versão não conta.
    List<String> mine(GamePokedex game) => [
      ...(game.exclusiveTo.isEmpty ? game.versions : game.exclusiveTo).where(
        owned.contains,
      ),
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
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              game.versions.map(versionLabel).join(' / '),
                              style: theme.textTheme.bodyLarge,
                            ),
                            // "exclusivo Scarlet", como a comunidade diz
                            // ("Scarlet exclusive"), na cor da versão (#203).
                            for (final version in game.exclusiveTo)
                              VersionTag(
                                context.l10n.exclusiveTo(versionLabel(version)),
                                version: version,
                              ),
                          ],
                        ),
                        if (mine(game) case final versions
                            when versions.isNotEmpty)
                          // "Seu: Violet": com um jogo só, na cor dele.
                          VersionTag(
                            context.l10n.yourGames(
                              versions.length,
                              versions.map(versionLabel).join(', '),
                            ),
                            version: versions.length == 1
                                ? versions.single
                                : null,
                          ),
                        Text(
                          game.entries
                              .map(
                                (e) => context.l10n.pokedexEntry(
                                  e,
                                  context.catalogText(e.label, e.labels),
                                ),
                              )
                              .join(' · '),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        Text(context.l10n.pokedexNoGuarantee, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Proporção de gênero a partir do `gender_rate` (oitavos de fêmea; -1 =
/// sem gênero): "♂ 87,5% · ♀ 12,5%", "Só macho", "Só fêmea".
String genderRatio(AppLocalizations l10n, int rate) => switch (rate) {
  < 0 => l10n.genderless,
  0 => l10n.maleOnly,
  >= 8 => l10n.femaleOnly,
  _ =>
    '♂ ${decimal(l10n, (8 - rate) * 12.5)}% · '
        '♀ ${decimal(l10n, rate * 12.5)}%',
};

/// Número no formato do idioma, sem ",0": 1.7 → "1,7" (en: "1.7");
/// 50.0 → "50".
String decimal(AppLocalizations l10n, num value) =>
    NumberFormat('0.###', l10n.localeName).format(value);
