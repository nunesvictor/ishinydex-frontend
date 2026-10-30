import 'package:flutter/material.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/core/widgets/type_chip.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/moves/domain/moves_data.dart';
import 'package:ishinydex/features/moves/presentation/moves_widgets.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/form_sheet.dart';

/// Abre o golpe [move] no jogo [group] (#369), por cima de tudo: a aba
/// Golpes pode estar numa folha ou no painel do slot.
Future<void> openMove(BuildContext context, MoveInfo move, String group) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => MovePage(move: move, group: group),
      ),
    );

/// O golpe (#369): tipo e categoria, poder / precisão / PP no jogo, o alvo,
/// o efeito (em inglês, como na PokéAPI) e quem aprende no jogo, com o
/// modo. Tocar numa forma abre a ficha dela.
class MovePage extends StatelessWidget {
  const MovePage({required this.move, required this.group, super.key});

  final MoveInfo move;
  final String group;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(move.label)),
    body: MovesGate(
      builder: (data, catalog) => ListView(
        padding: const EdgeInsets.all(16),
        children: [_body(context, data, catalog)],
      ),
    ),
  );

  Widget _body(BuildContext context, MovesData data, Catalog catalog) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final stats = move.statsIn(group, catalog.versionGroupOrder);
    final generation = catalog.versionGroupGeneration(group);
    final learners =
        [
          for (final MapEntry(key: pokemon, value: learns)
              in data.learnersOf(move, group).entries)
            if (catalog.formOfPokemon(pokemon) case final form?) (form, learns),
        ]..sort(
          (a, b) =>
              (a.$1.nationalNumber ?? 0).compareTo(b.$1.nationalNumber ?? 0),
        );
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    Widget labeled(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Text(label, style: muted),
        Text(value, style: theme.textTheme.bodyLarge),
      ],
    );
    Widget stat(String label, int? value) => Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(label, style: muted),
              Text(
                value?.toString() ?? '—',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TypeChip(stats.type),
            Chip(
              avatar: MoveCategoryIcon(move.category, height: 18),
              label: Text(moveCategoryLabel(l10n, move.category)),
            ),
          ],
        ),
        Row(
          spacing: 8,
          children: [
            stat(l10n.movePower, stats.power),
            stat(l10n.moveAccuracy, stats.accuracy),
            stat('PP', stats.pp),
          ],
        ),
        if (move.target.isNotEmpty)
          labeled(l10n.moveTargetLabel, moveTargetLabel(l10n, move.target)),
        if (move.effect.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(l10n.moveEffect, style: muted),
              Text(
                move.effect,
                locale: const Locale('en'),
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            l10n.moveLearners(gameLabel(catalog, group), learners.length),
            style: theme.textTheme.titleSmall,
          ),
        ),
        Column(
          children: [
            for (final (form, learns) in learners)
              ListTile(
                key: ValueKey('learner-${form.id}'),
                contentPadding: EdgeInsets.zero,
                leading: PokemonSprite(url: form.spriteUrl, size: 40),
                title: Text(form.displayName),
                trailing: Text(
                  learnHow(l10n, learns, generation),
                  style: muted?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                onTap: () => showFormSheet(context, form),
              ),
          ],
        ),
      ],
    );
  }
}

/// O alvo de um golpe, como a PokéAPI o chama (`selected-pokemon`).
String moveTargetLabel(AppLocalizations l10n, String target) =>
    switch (target) {
      'selected-pokemon' => l10n.moveTargetSelectedPokemon,
      'all-opponents' => l10n.moveTargetAllOpponents,
      'user' => l10n.moveTargetUser,
      'ally' => l10n.moveTargetAlly,
      'users-field' => l10n.moveTargetUsersField,
      'user-or-ally' => l10n.moveTargetUserOrAlly,
      'opponents-field' => l10n.moveTargetOpponentsField,
      'random-opponent' => l10n.moveTargetRandomOpponent,
      'all-other-pokemon' => l10n.moveTargetAllOtherPokemon,
      'selected-pokemon-me-first' => l10n.moveTargetMeFirst,
      'all-allies' => l10n.moveTargetAllAllies,
      'entire-field' => l10n.moveTargetEntireField,
      'user-and-allies' => l10n.moveTargetUserAndAllies,
      'all-pokemon' => l10n.moveTargetAllPokemon,
      'specific-move' => l10n.moveTargetSpecificMove,
      'fainting-pokemon' => l10n.moveTargetFaintingPokemon,
      _ => prettifyName(target),
    };
