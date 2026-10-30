import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Envolve uma forma da linha: o toque (abre o slot ou a ficha) e o
/// esmaecido de quem não está no dex, como em `SpeciesInfo`.
typedef EvolutionItemBuilder = Widget Function(
  FormRef ref, {
  required Widget child,
});

/// A linha evolutiva com os métodos (#368).
///
/// Na horizontal, como antes, quando a linha não tem ramos e todo método é
/// curto (só o nível, só o item ou só a troca): o método vai em cima da
/// seta. Senão, na vertical, uma evolução por linha, com a frase inteira; o
/// ⓘ abre os métodos de cada jogo e o link "Veja mais". Sem métodos
/// (catálogo antigo), a linha de antes.
class EvolutionLine extends StatelessWidget {
  const EvolutionLine({required this.form, required this.item, super.key});

  final FormDetail form;
  final EvolutionItemBuilder item;

  @override
  Widget build(BuildContext context) {
    final chain = form.evolutionChain;
    final edges = form.evolutionEdges;
    final horizontal =
        edges.every((e) => e.methods.isEmpty) ||
        (chain.every((stage) => stage.length == 1) &&
            edges.every((e) => e.texts.isEmpty && (e.main?.isShort ?? true)));
    return horizontal ? _horizontal(context) : _vertical(context);
  }

  Widget _horizontal(BuildContext context) {
    final theme = Theme.of(context);
    final edgeTo = {for (final e in form.evolutionEdges) e.toId: e};
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final (i, stage) in form.evolutionChain.indexed) ...[
          if (i > 0)
            switch (edgeTo[stage.first.id]?.main) {
              final method? => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    evolutionMethodText(context.l10n, method),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              null => const Icon(Icons.chevron_right, size: 18),
            },
          for (final ref in stage)
            item(
              ref,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    Text(ref.displayName, style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _vertical(BuildContext context) {
    final theme = Theme.of(context);
    final forms = {
      for (final stage in form.evolutionChain)
        for (final ref in stage) ref.id: ref,
    };
    final children = <int, List<EvolutionEdge>>{};
    for (final edge in form.evolutionEdges) {
      (children[edge.fromId] ??= []).add(edge);
    }
    final root = form.evolutionChain.first.first;
    BoxDecoration? current(FormRef ref) => ref.id == form.id
        ? BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          )
        : null;

    final rows = <Widget>[
      item(
        root,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: current(root),
          child: Row(
            spacing: 12,
            children: [
              PokemonSprite(url: root.spriteUrl, size: 48),
              Expanded(
                child: Text(root.displayName, style: theme.textTheme.bodyLarge),
              ),
            ],
          ),
        ),
      ),
    ];
    void addChildren(int id, int depth, Set<int> seen) {
      for (final edge in children[id] ?? const <EvolutionEdge>[]) {
        final to = forms[edge.toId];
        if (to == null || !seen.add(to.id)) continue;
        rows.add(
          _EvolutionRow(
            edge: edge,
            from: forms[edge.fromId] ?? root,
            to: to,
            depth: depth,
            decoration: current(to),
            item: item,
          ),
        );
        addChildren(to.id, depth + 1, seen);
      }
    }

    addChildren(root.id, 0, {root.id});
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// Uma evolução na linha vertical: a seta, a forma, a frase e o ⓘ.
class _EvolutionRow extends StatelessWidget {
  const _EvolutionRow({
    required this.edge,
    required this.from,
    required this.to,
    required this.depth,
    required this.decoration,
    required this.item,
  });

  final EvolutionEdge edge;
  final FormRef from;
  final FormRef to;
  final int depth;
  final BoxDecoration? decoration;
  final EvolutionItemBuilder item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final method = edge.main;
    final text = evolutionEdgeText(context, edge);
    return Padding(
      padding: EdgeInsets.only(left: 12.0 + 28 * depth),
      child: Row(
        children: [
          Icon(Icons.subdirectory_arrow_right, size: 20, color: muted),
          const SizedBox(width: 8),
          Expanded(
            child: item(
              to,
              child: Container(
                constraints: const BoxConstraints(minHeight: 64),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: decoration,
                child: Row(
                  spacing: 8,
                  children: [
                    PokemonSprite(url: to.spriteUrl, size: 48),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 2,
                          children: [
                            Text(
                              to.displayName,
                              style: theme.textTheme.bodyLarge,
                            ),
                            if (text != null)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: 6,
                                children: [
                                  if (method?.itemSpriteUrl case final url?
                                      when edge.texts.isEmpty)
                                    Image.network(
                                      url,
                                      width: 20,
                                      height: 20,
                                      filterQuality: FilterQuality.none,
                                      errorBuilder: (_, _, _) =>
                                          const SizedBox(width: 20),
                                    ),
                                  Expanded(
                                    child: Text(
                                      text,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(color: muted),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (edge.hasMore)
            IconButton(
              key: ValueKey('evolution-info-${to.id}'),
              tooltip: context.l10n.evolutionHowItEvolves,
              icon: Icon(Icons.info_outline, color: muted),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (_) => EvolutionSheet(edge: edge, from: from, to: to),
              ),
            ),
        ],
      ),
    );
  }
}

/// A folha do ⓘ (#368): o método de cada jogo, com o mostrado em destaque, e
/// o link "Veja mais na Bulbapedia".
class EvolutionSheet extends ConsumerWidget {
  const EvolutionSheet({
    required this.edge,
    required this.from,
    required this.to,
    super.key,
  });

  final EvolutionEdge edge;
  final FormRef from;
  final FormRef to;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final main = edge.main;
    // O mostrado primeiro; depois, do jogo mais novo ao mais antigo.
    final methods = [
      ?main,
      for (final m in edge.methods.reversed)
        if (!identical(m, main)) m,
    ];
    final link = edge.link;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              spacing: 8,
              children: [
                PokemonSprite(url: from.spriteUrl, size: 40),
                Flexible(
                  child: Text(
                    from.displayName,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                PokemonSprite(url: to.spriteUrl, size: 40),
                Flexible(
                  child: Text(to.displayName, style: theme.textTheme.bodyLarge),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
              child: Text(
                l10n.evolutionHowItEvolves,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            for (final method in methods)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Row(
                      spacing: 8,
                      children: [
                        Flexible(
                          child: Text(
                            evolutionGameLabel(method),
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        if (identical(method, main))
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              child: Text(
                                l10n.evolutionShown,
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      identical(method, main)
                          ? evolutionEdgeText(context, edge)!
                          : evolutionMethodText(l10n, method),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            if (link != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => ref.read(openLinkProvider)(link),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(l10n.evolutionSeeMore),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Os grupos de versões das DLCs, que se chamam pelo nome do grupo.
const _dlcGroups = {
  'the-isle-of-armor',
  'the-crown-tundra',
  'the-teal-mask',
  'the-indigo-disk',
  'mega-dimension',
};

/// O jogo de um método: as versões do grupo ("Scarlet / Violet"); nas DLCs
/// e sem as versões, o nome do grupo ("The Teal Mask").
String evolutionGameLabel(EvolutionMethod method) =>
    method.versions.isEmpty || _dlcGroups.contains(method.versionGroup)
    ? prettifyName(method.versionGroup)
    : method.versions.map(versionLabel).join(' / ');

/// A frase de uma ligação: a curada no idioma do app (os casos bizarros) ou
/// a do método mostrado; `null` sem métodos.
String? evolutionEdgeText(BuildContext context, EvolutionEdge edge) {
  final method = edge.main;
  if (method == null) return null;
  final generated = evolutionMethodText(context.l10n, method);
  return edge.texts.isEmpty
      ? generated
      : context.catalogText(generated, edge.texts);
}

/// A frase de um método, montada pelo gatilho e pelas condições ("Amizade
/// alta, de dia"). Itens, golpes, tipos, lugares e espécies em inglês.
String evolutionMethodText(AppLocalizations l10n, EvolutionMethod m) {
  final number = NumberFormat.decimalPattern(l10n.localeName);
  final main = switch (m.trigger) {
    'level-up' when m.minLevel != null => l10n.evolutionLevel(m.minLevel!),
    'level-up' when m.minHappiness != null => l10n.evolutionHighFriendship,
    'level-up' when m.minAffection != null => l10n.evolutionHighAffection,
    'level-up' when m.minBeauty != null => l10n.evolutionHighBeauty,
    'level-up' => l10n.evolutionLevelUp,
    'use-item' => m.item ?? prettifyName(m.trigger),
    'trade' when m.tradeSpecies != null => l10n.evolutionTradeFor(
      m.tradeSpecies!,
    ),
    'trade' => l10n.evolutionTrade,
    'spin' => l10n.evolutionSpin,
    'in-battle-level-up' => l10n.evolutionInBattle(m.minLevel ?? 1),
    'recoil-damage' => l10n.evolutionRecoil(m.minDamageTaken ?? 0),
    'take-damage' => l10n.evolutionTakeDamage(m.minDamageTaken ?? 0),
    'use-move' => l10n.evolutionUseMove(m.usedMove ?? '', m.minMoveCount ?? 1),
    'agile-style-move' => l10n.evolutionAgileStyle(
      m.usedMove ?? '',
      m.minMoveCount ?? 1,
    ),
    'strong-style-move' => l10n.evolutionStrongStyle(
      m.usedMove ?? '',
      m.minMoveCount ?? 1,
    ),
    'gimmighoul-coins' => l10n.evolutionGimmighoulCoins,
    'tower-of-darkness' => l10n.evolutionTowerOfDarkness,
    'tower-of-waters' => l10n.evolutionTowerOfWaters,
    'meltan-candies' => l10n.evolutionMeltanCandies,
    'three-critical-hits' => l10n.evolutionThreeCriticalHits,
    'three-defeated-bisharp' => l10n.evolutionThreeBisharp,
    'shed' => l10n.evolutionShed,
    _ => prettifyName(m.trigger),
  };
  final levelUp = m.trigger == 'level-up';
  final conditions = [
    // No nível com amizade (o Pichu na Gen II só pela amizade), a amizade
    // entra como condição.
    if (levelUp && m.minLevel != null && m.minHappiness != null)
      l10n.evolutionHighFriendship.toLowerCase(),
    if (m.heldItem != null) l10n.evolutionHolding(m.heldItem!),
    if (m.knownMove != null) l10n.evolutionKnowing(m.knownMove!),
    if (m.knownMoveType != null)
      l10n.evolutionKnowingType(prettifyName(m.knownMoveType!)),
    if (m.timeOfDay case final time?)
      switch (time) {
        'day' => l10n.evolutionDay,
        'night' => l10n.evolutionNight,
        'dusk' => l10n.evolutionDusk,
        'full-moon' => l10n.evolutionFullMoon,
        _ => prettifyName(time),
      },
    if (m.location != null) l10n.evolutionAt(m.location!),
    if (m.nearSpecialRock ?? false) l10n.evolutionNearRock,
    if (m.region != null) l10n.evolutionInRegion(prettifyName(m.region!)),
    if (m.gender case final gender?)
      switch (gender) {
        'female' => l10n.evolutionFemaleOnly,
        _ => l10n.evolutionMaleOnly,
      },
    if (m.relativePhysicalStats case final stats?)
      switch (stats.sign) {
        1 => l10n.evolutionAttackHigher,
        -1 => l10n.evolutionAttackLower,
        _ => l10n.evolutionAttackEqual,
      },
    if (m.allowedNatures.isNotEmpty)
      l10n.evolutionNatures(m.allowedNatures.map(prettifyName).join(', ')),
    if (m.needsOverworldRain ?? false) l10n.evolutionRain,
    if (m.needsMultiplayer ?? false) l10n.evolutionMultiplayer,
    if (m.turnUpsideDown ?? false) l10n.evolutionUpsideDown,
    if (m.partySpecies != null) l10n.evolutionPartySpecies(m.partySpecies!),
    if (m.partyType != null)
      l10n.evolutionPartyType(prettifyName(m.partyType!)),
    if (m.minSteps != null) l10n.evolutionSteps(number.format(m.minSteps)),
    if (m.chance case final chance?)
      l10n.evolutionChance(number.format(chance)),
  ];
  if (conditions.isEmpty) return main;
  // "Subir de nível sabendo Barb Barrage", "Troca segurando Prism Scale":
  // sem vírgula depois do genérico.
  final first = main == l10n.evolutionLevelUp || main == l10n.evolutionTrade
      ? ' '
      : ', ';
  return '$main$first${conditions.join(', ')}';
}
