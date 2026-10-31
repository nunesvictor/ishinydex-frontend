import 'package:flutter/material.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/widgets/game_icon.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/moves/domain/moves_data.dart';
import 'package:ishinydex/features/moves/presentation/moves_widgets.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/teams/domain/models.dart';
import 'package:ishinydex/features/teams/domain/team_rules.dart';

/// Os ícones das versões do jogo, um sobre o outro, como no mock.
class TeamGameIcons extends StatelessWidget {
  const TeamGameIcons(this.catalog, this.group, {this.size = 20, super.key});

  final Catalog catalog;
  final String group;
  final double size;

  @override
  Widget build(BuildContext context) {
    final versions = catalog.versionsOfGroup(group);
    final step = size * 0.6;
    return SizedBox(
      width: versions.isEmpty ? 0 : size + step * (versions.length - 1),
      height: size,
      child: Stack(
        children: [
          for (final (i, version) in versions.indexed)
            Positioned(
              left: step * i,
              child: GameIcon(version, size: size),
            ),
        ],
      ),
    );
  }
}

/// O nível do time: o de todos, ou "Níveis variados".
String teamLevelText(BuildContext context, Team team) {
  final levels = {for (final m in team.members) m.level};
  return switch (levels.length) {
    0 => context.l10n.teamLevel(TeamMember.defaultLevel),
    1 => context.l10n.teamLevel(levels.single),
    _ => context.l10n.teamLevelMixed,
  };
}

/// Os jogos que aceitam time, do mais novo ao mais antigo.
List<String> teamGroups(Catalog catalog) => newestFirst([
  for (final group in catalog.versionGroupNames)
    if (catalog.versionsOfGroup(group).isNotEmpty &&
        catalog.heldItemsIn(group).isNotEmpty &&
        groupHasTeams(group, generation: catalog.versionGroupGeneration(group)))
      group,
], catalog);

/// A forma [formId] entra num time do jogo [group]: aprende golpes nele e
/// não é mega nem só de batalha.
bool formInGame(MovesData data, Catalog catalog, int formId, String group) =>
    !catalog.isBattleForm(formId) &&
    catalog
        .movesPokemonIds(formId)
        .any((pokemon) => data.learnset(pokemon, group).isNotEmpty);

/// Os golpes do membro, na ordem dos slots (os que o pacote não tem ficam
/// de fora).
List<MoveInfo> memberMoves(TeamMember member, MovesData data) => [
  for (final name in member.moves) ?data.moveNamed(name),
];

/// O time no texto do Showdown, com os nomes em inglês.
String teamShowdownText(Team team, Catalog catalog, MovesData data) =>
    showdownText([
      for (final m in team.members)
        (
          species: switch (catalog.pokemonNames(m.form)) {
            final names? => showdownSpecies(
              pokemon: names.pokemon,
              species: names.species,
              isDefault: names.isDefault,
            ),
            null => m.formRef?.displayName ?? '',
          },
          item: switch (m.item) {
            final item? => catalog.heldItem(item)?.label ?? item,
            null => null,
          },
          ability: switch (m.ability) {
            final ability? => abilityLabel(ability),
            null => null,
          },
          level: m.level,
          tera: m.tera,
          evs: m.evs,
          ivs: m.ivs,
          nature: switch (natureOf(catalog, m.nature)) {
            final nature? => nature.labels['en'] ?? nature.label,
            null => null,
          },
          moves: [for (final move in memberMoves(m, data)) move.label],
        ),
    ]);

/// A natureza [value] do catálogo.
Choice? natureOf(Catalog catalog, String? value) =>
    catalog.options.nature.where((n) => n.value == value).firstOrNull;
