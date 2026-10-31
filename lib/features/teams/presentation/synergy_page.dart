import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/responsive/breakpoints.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/utils/pokemon_types.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/core/widgets/type_chip.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/moves/domain/moves_data.dart';
import 'package:ishinydex/features/moves/presentation/moves_widgets.dart';
import 'package:ishinydex/features/teams/domain/models.dart';
import 'package:ishinydex/features/teams/domain/synergy.dart';
import 'package:ishinydex/features/teams/domain/team_rules.dart';
import 'package:ishinydex/features/teams/presentation/team_widgets.dart';
import 'package:ishinydex/features/teams/teams_providers.dart';

/// As regras da geração do jogo: sem o Fairy até a 5ª.
SynergyRules _rulesFor(Catalog catalog, String group) => SynergyRules(
  withFairy: (generationRank(catalog.versionGroupGeneration(group)) ?? 9) >= 6,
);

SynergyMove _synergyMove(
  MoveInfo move,
  String form,
  String group,
  Catalog catalog,
) {
  final stats = move.statsIn(group, catalog.versionGroupOrder);
  return (
    name: move.name,
    label: move.label,
    type: moveTypeFor(move.name, form, stats.type),
    category: move.category,
    power: stats.power,
  );
}

/// Os membros do time como a sinergia os vê: os tipos e a habilidade da
/// forma, os golpes de dano (com o tipo no jogo), a velocidade no nível 50,
/// o Trick Room e o Tera.
List<SynergyMember> synergyMembers(Team team, Catalog catalog, MovesData data) {
  final group = team.versionGroup;
  return [
    for (final m in team.members)
      () {
        final detail = catalog.formDetail(m.form);
        final nature = natureOf(catalog, m.nature);
        final speedBase = detail.stats
            .where((s) => s.stat == 'speed')
            .firstOrNull
            ?.baseStat;
        final moves = memberMoves(m, data);
        return SynergyMember(
          name: m.formRef?.displayName ?? detail.name,
          types: [for (final t in detail.types) t.type],
          ability: groupsWithoutAbilities.contains(group) ? null : m.ability,
          moves: [
            for (final move in moves)
              if (move.category != 'status')
                _synergyMove(move, detail.name, group, catalog),
          ],
          speed: statValue(
            'speed',
            base: speedBase ?? 0,
            level: TeamMember.defaultLevel,
            ev: m.ev('speed'),
            iv: m.iv('speed'),
            factor: natureFactor(
              'speed',
              increased: nature?.increased,
              decreased: nature?.decreased,
            ),
          ),
          trickRoom: m.moves.contains('trick-room'),
          tera: teraGroups.contains(group) ? m.tera : null,
        );
      }(),
  ];
}

Synergy teamSynergy(Team team, Catalog catalog, MovesData data) => Synergy.of(
  synergyMembers(team, catalog, data),
  rules: _rulesFor(catalog, team.versionGroup),
);

String _signed(int points) => switch (points) {
  > 0 => '+$points',
  < 0 => '−${-points}',
  _ => '0',
};

String _types(List<String> types) => types.map(typeLabel).join(', ');

/// A linha do cartão: os buracos e quem leva 4× do primeiro tipo.
String _summary(AppLocalizations l10n, Synergy synergy) {
  final holes = synergy.issues.whereType<HoleIssue>().length;
  final quads = synergy.issues.whereType<QuadIssue>().toList();
  final first = quads.firstOrNull?.type;
  final names = [
    for (final q in quads)
      if (q.type == first) q.member,
  ];
  return [
    if (holes == 0) l10n.synergyNoHoles else l10n.synergyHoles(holes),
    if (first != null)
      l10n.synergyQuadLine(names.length, names.join(', '), typeLabel(first)),
  ].join(' · ');
}

/// A nota no time: o número, a linha e o atalho para a sinergia.
class SynergyCard extends StatelessWidget {
  const SynergyCard({
    required this.team,
    required this.catalog,
    required this.data,
    super.key,
  });

  final Team team;
  final Catalog catalog;
  final MovesData data;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final synergy = teamSynergy(team, catalog, data);
    return Card.filled(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('team-synergy'),
        onTap: () => context.go(Routes.teamSynergy(team.id)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            spacing: 12,
            children: [
              _ScoreRing(score: synergy.score, size: 48),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      l10n.synergyScore(synergy.score),
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      _summary(l10n, synergy),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score, required this.size});

  final int score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: size / 10,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          Text(
            '$score',
            style:
                (size > 60
                        ? theme.textTheme.headlineMedium
                        : theme.textTheme.titleMedium)
                    ?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
          ),
        ],
      ),
    );
  }
}

/// A sinergia do time [teamId] (#374): a nota com as três partes, o que
/// tira pontos, o Tera de cada membro, as sugestões e as tabelas de defesa,
/// cobertura e equilíbrio. No PC, as tabelas ficam numa segunda coluna.
class SynergyPage extends ConsumerWidget {
  const SynergyPage({required this.teamId, super.key});

  final int teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final team = ref
        .watch(teamsProvider)
        .value
        ?.where((t) => t.id == teamId)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.synergyTitle),
            if (team != null)
              Text(
                team.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('synergy-how'),
            tooltip: l10n.synergyHow,
            icon: const Icon(Icons.help_outline),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l10n.synergyHow),
                content: Text(l10n.synergyHowText),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.ok),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: switch (ref.watch(teamsProvider)) {
        AsyncData() when team == null => EmptyView(
          message: l10n.problemNotFound,
        ),
        AsyncData() => MovesGate(
          builder: (data, catalog) => _SynergyBody(
            team: team!,
            catalog: catalog,
            data: data,
            owned: ref.watch(ownedFormsProvider).value ?? const {},
          ),
        ),
        AsyncError(:final error) => ErrorView(error: error),
        _ => const LoadingView(),
      },
    );
  }
}

class _SynergyBody extends StatelessWidget {
  const _SynergyBody({
    required this.team,
    required this.catalog,
    required this.data,
    required this.owned,
  });

  final Team team;
  final Catalog catalog;
  final MovesData data;
  final Set<int> owned;

  @override
  Widget build(BuildContext context) {
    final synergy = teamSynergy(team, catalog, data);
    final summary = [
      _Score(synergy: synergy),
      SynergyIssues(synergy: synergy),
      if (synergy.members.any((m) => m.tera != null))
        _Tera(team: team, synergy: synergy),
      _MoveSuggestions(
        team: team,
        synergy: synergy,
        catalog: catalog,
        data: data,
      ),
      _FormSuggestions(
        team: team,
        synergy: synergy,
        catalog: catalog,
        data: data,
        owned: owned,
      ),
    ];
    final tables = [
      _DefenseTable(team: team, synergy: synergy),
      _Coverage(synergy: synergy),
      _Balance(team: team, synergy: synergy),
    ];
    const gap = SizedBox(height: 24);
    List<Widget> spaced(List<Widget> items) => [
      for (final (i, item) in items.indexed) ...[if (i > 0) gap, item],
    ];
    if (WindowSize.of(context).isCompact) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: spaced([...summary, ...tables]),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 32,
        children: [
          Expanded(child: Column(children: spaced(summary))),
          Expanded(child: Column(children: spaced(tables))),
        ],
      ),
    );
  }
}

/// O título e a explicação de uma seção.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.hint});

  final String title;
  final String? hint;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        if (hint case final hint?)
          Text(
            hint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ...children,
      ],
    );
  }
}

class _Score extends StatelessWidget {
  const _Score({required this.synergy});

  final Synergy synergy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    Widget part(String label, int points, int max) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            Text(
              l10n.synergyPart(points, max),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        LinearProgressIndicator(
          value: points / max,
          semanticsLabel: '$label: ${l10n.synergyPart(points, max)}',
        ),
      ],
    );
    return Row(
      spacing: 20,
      children: [
        Semantics(
          label: l10n.synergyScore(synergy.score),
          child: _ScoreRing(score: synergy.score, size: 96),
        ),
        Expanded(
          child: Column(
            spacing: 12,
            children: [
              part(
                l10n.synergyDefense,
                synergy.defense,
                SynergyRules.defenseMax,
              ),
              part(l10n.synergyAttack, synergy.attack, SynergyRules.attackMax),
              part(
                l10n.synergyBalance,
                synergy.balance,
                SynergyRules.balanceMax,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// O que tira pontos, um item por desconto.
class SynergyIssues extends StatelessWidget {
  const SynergyIssues({required this.synergy, super.key});

  final Synergy synergy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    Widget item(
      SynergyIssue issue,
      String title,
      String text, [
      List<String> types = const [],
    ]) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          SizedBox(
            width: 36,
            child: Text(
              _signed(-issue.points),
              textAlign: TextAlign.end,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.error,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final type in types) TypeChip(type, small: true),
                    Text(title, style: theme.textTheme.bodyLarge),
                  ],
                ),
                Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final items = [
      for (final issue in synergy.issues)
        switch (issue) {
          HoleIssue(:final type, :final weak, :final resisted) => item(
            issue,
            l10n.synergyHoleTitle,
            resisted
                ? l10n.synergyHoleManyText(weak.join(', '))
                : l10n.synergyHoleText(weak.join(', ')),
            [type],
          ),
          QuadIssue(:final type, :final member) => item(
            issue,
            l10n.synergyQuadTitle,
            l10n.synergyQuadText(member, typeLabel(type)),
            [type],
          ),
          UncoveredIssue(:final types) => item(
            issue,
            l10n.synergyUncoveredTitle,
            l10n.synergyUncoveredText,
            types,
          ),
          WallIssue(:final types) => item(
            issue,
            l10n.synergyWallTitle,
            l10n.synergyWallText,
            types,
          ),
          MixIssue(:final physical, :final special) => item(
            issue,
            l10n.synergyMixTitle(physical, special),
            l10n.synergyMixText,
          ),
          SpeedIssue(:final count, :final trickRoom) => item(
            issue,
            trickRoom
                ? l10n.synergySlowTitle(count)
                : l10n.synergyFastTitle(count),
            trickRoom ? l10n.synergySlowText : l10n.synergyFastText,
          ),
          RepeatedTypeIssue(:final type, :final count) => item(
            issue,
            l10n.synergyRepeatTitle,
            l10n.synergyRepeatText(count),
            [type],
          ),
          NoDamageIssue(:final member) => item(
            issue,
            l10n.synergyNoDamageTitle,
            l10n.synergyNoDamageText(member),
          ),
          EmptySlotsIssue(:final count) => item(
            issue,
            l10n.synergyEmptyTitle(count),
            l10n.synergyEmptyText,
          ),
        },
    ];
    return _Section(
      title: l10n.synergyWhy,
      children: items.isEmpty
          ? [Text(l10n.synergyNothingLost, style: theme.textTheme.bodyMedium)]
          : items,
    );
  }
}

/// Os pontos de uma linha, à direita: verde quando somam.
class _Points extends StatelessWidget {
  const _Points(this.points);

  final int points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (points) {
      > 0 => (scheme.primaryContainer, scheme.onPrimaryContainer),
      < 0 => (scheme.errorContainer, scheme.onErrorContainer),
      _ => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          _signed(points),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: foreground,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _Tera extends StatelessWidget {
  const _Tera({required this.team, required this.synergy});

  final Team team;
  final Synergy synergy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final outcomes = [
      for (final (i, m) in synergy.members.indexed)
        if (m.tera case final tera?) synergy.teraOf(i, tera),
    ]..sort((a, b) => b.delta.compareTo(a.delta));
    return _Section(
      title: l10n.synergyTera,
      hint: l10n.synergyTeraHint,
      children: [
        for (final o in outcomes)
          ListTile(
            key: ValueKey('tera-${o.index}'),
            contentPadding: EdgeInsets.zero,
            leading: PokemonSprite(
              url: team.members[o.index].formRef?.spriteUrl,
              size: 40,
            ),
            title: Row(
              spacing: 6,
              children: [
                TypeIcon(o.tera),
                Expanded(
                  child: Text(
                    l10n.synergyTeraLine(
                      synergy.members[o.index].name,
                      typeLabel(o.tera),
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              [
                if (o.closes.isNotEmpty)
                  l10n.synergyTeraCloses(_types(o.closes)),
                if (o.opens.isNotEmpty) l10n.synergyTeraOpens(_types(o.opens)),
                if (o.closes.isEmpty && o.opens.isEmpty) l10n.synergyTeraSame,
                if (o.better case final better?)
                  l10n.synergyTeraBetter(
                    typeLabel(better.type),
                    _signed(better.delta),
                  ),
              ].join(' '),
            ),
            trailing: _Points(o.delta),
          ),
      ],
    );
  }
}

class _MoveSuggestions extends StatelessWidget {
  const _MoveSuggestions({
    required this.team,
    required this.synergy,
    required this.catalog,
    required this.data,
  });

  final Team team;
  final Synergy synergy;
  final Catalog catalog;
  final MovesData data;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final group = team.versionGroup;
    final suggestions = synergy.moveSuggestions((i) {
      final member = team.members[i];
      final form = catalog.formDetail(member.form).name;
      return [
        for (final learns in formLearnset(
          data,
          catalog,
          member.form,
          group,
        ).values)
          if (learns.first.move.category != 'status')
            _synergyMove(learns.first.move, form, group, catalog),
      ];
    });
    return _Section(
      title: l10n.synergySugMoves,
      hint: l10n.synergySugMovesHint(gameLabel(catalog, group)),
      children: [
        if (suggestions.isEmpty) Text(l10n.synergyNoSuggestions),
        for (final s in suggestions)
          ListTile(
            key: ValueKey('sug-move-${s.index}-${s.move.name}'),
            contentPadding: EdgeInsets.zero,
            leading: PokemonSprite(
              url: team.members[s.index].formRef?.spriteUrl,
              size: 40,
            ),
            title: Text(
              l10n.synergyMoveOn(s.move.label, synergy.members[s.index].name),
            ),
            subtitle: Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TypeChip(s.move.type, small: true),
                Text(
                  [
                    if (s.stab) l10n.synergyStab,
                    l10n.synergyHits(_types(s.hits)),
                  ].join(' · '),
                ),
              ],
            ),
            trailing: _Points(s.gain),
            // O atalho leva ao membro, para trocar o golpe.
            onTap: () => context.go(Routes.teamMember(team.id, s.index)),
          ),
      ],
    );
  }
}

class _FormSuggestions extends StatelessWidget {
  const _FormSuggestions({
    required this.team,
    required this.synergy,
    required this.catalog,
    required this.data,
    required this.owned,
  });

  final Team team;
  final Synergy synergy;
  final Catalog catalog;
  final MovesData data;
  final Set<int> owned;

  /// Quantas formas de cada grupo aparecem.
  static const _shown = 4;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final group = team.versionGroup;
    final inTeam = {for (final m in team.members) m.form};
    final suggestions = synergy.formSuggestions({
      for (final id in catalog.formIds)
        if (!inTeam.contains(id) &&
            catalog.isDefaultForm(id) &&
            formInGame(data, catalog, id, group))
          id: [for (final t in catalog.formDetail(id).types) t.type],
    });
    return _Section(
      title: l10n.synergySugForms,
      hint: l10n.synergySugFormsHint(gameLabel(catalog, group)),
      children: [
        if (suggestions.isEmpty) Text(l10n.synergyNoSuggestions),
        for (final s in suggestions)
          () {
            // As do inventário primeiro; depois, pela Pokédex nacional.
            final forms = [for (final id in s.forms) catalog.formRef(id)]
              ..sort((a, b) {
                final owns = (owned.contains(b.id) ? 1 : 0).compareTo(
                  owned.contains(a.id) ? 1 : 0,
                );
                return owns != 0
                    ? owns
                    : (a.nationalNumber ?? 0).compareTo(b.nationalNumber ?? 0);
              });
            return Card.outlined(
              key: ValueKey('sug-form-${s.types.join('-')}'),
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Row(
                      spacing: 6,
                      children: [
                        for (final type in s.types) TypeChip(type, small: true),
                        Expanded(
                          child: Text(switch (s.replaces) {
                            final i? => l10n.synergyInPlaceOf(
                              synergy.members[i].name,
                            ),
                            null => l10n.synergyInSlot,
                          }, style: theme.textTheme.bodySmall),
                        ),
                        _Points(s.gain),
                      ],
                    ),
                    Text(
                      [
                        if (s.closes.isNotEmpty)
                          l10n.synergyTeraCloses(_types(s.closes)),
                        if (s.covers.isNotEmpty)
                          l10n.synergyCovers(_types(s.covers)),
                      ].join(' '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final f in forms.take(_shown))
                          Chip(
                            key: ValueKey('sug-form-${f.id}'),
                            avatar: PokemonSprite(url: f.spriteUrl, size: 24),
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: 4,
                              children: [
                                Text(f.displayName),
                                if (owned.contains(f.id)) ...[
                                  const Icon(Icons.check, size: 14),
                                  Text(
                                    l10n.synergyOwned,
                                    style: theme.textTheme.labelSmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        if (forms.length > _shown)
                          Text(
                            l10n.synergyMore(forms.length - _shown),
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }(),
      ],
    );
  }
}

/// O multiplicador como texto curto (4×, 2×, ½, ¼, 0); 1× fica vazio.
String _multiplier(double x) => switch (x) {
  0 => '0',
  0.25 => '¼',
  0.5 => '½',
  1 => '',
  _ => '${x.round()}×',
};

class _DefenseTable extends StatelessWidget {
  const _DefenseTable({required this.team, required this.synergy});

  final Team team;
  final Synergy synergy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final small = theme.textTheme.bodySmall;
    const cell = 36.0;
    Widget box(String text, {Color? color, Color? textColor}) => Container(
      width: cell,
      height: 28,
      alignment: Alignment.center,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: small?.copyWith(color: textColor)),
    );
    return _Section(
      title: l10n.synergyDefenseTable,
      hint: l10n.synergyDefenseHint,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 104,
                    child: Text(l10n.synergyAttackColumn, style: small),
                  ),
                  for (final m in team.members)
                    SizedBox(
                      width: cell + 2,
                      child: Center(
                        child: PokemonSprite(
                          url: m.formRef?.spriteUrl,
                          size: 28,
                          semanticLabel: m.formRef?.displayName,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: 84,
                    child: Text(
                      l10n.synergyWeakResist,
                      textAlign: TextAlign.end,
                      style: small,
                    ),
                  ),
                ],
              ),
              for (final row in synergy.rows)
                Container(
                  key: ValueKey('defense-${row.type}'),
                  color: row.hole
                      ? scheme.errorContainer.withValues(alpha: 0.4)
                      : null,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 104,
                        child: Row(
                          spacing: 4,
                          children: [
                            TypeIcon(row.type),
                            Flexible(
                              child: Text(
                                typeLabel(row.type),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: small,
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final x in row.multipliers)
                        box(
                          _multiplier(x),
                          color: x > 1
                              ? scheme.errorContainer
                              : x < 1
                              ? scheme.primaryContainer
                              : null,
                          textColor: x > 1
                              ? scheme.onErrorContainer
                              : x < 1
                              ? scheme.onPrimaryContainer
                              : null,
                        ),
                      SizedBox(
                        width: 84,
                        child: Text(
                          '${row.weak} · ${row.resist}',
                          textAlign: TextAlign.end,
                          style: small?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Coverage extends StatelessWidget {
  const _Coverage({required this.synergy});

  final Synergy synergy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return _Section(
      title: l10n.synergyCoverage,
      hint: l10n.synergyCoverageHint,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final MapEntry(key: type, value: hits)
                in synergy.coverage.entries)
              Opacity(
                key: ValueKey('coverage-$type'),
                opacity: hits.isEmpty ? 0.4 : 1,
                child: Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: TypeIcon(type),
                  label: Text(
                    '${typeLabel(type)} ${hits.length}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Balance extends StatelessWidget {
  const _Balance({required this.team, required this.synergy});

  final Team team;
  final Synergy synergy;

  /// O fim da barra de velocidade.
  static const _maxSpeed = 250;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mix = synergy.issues.whereType<MixIssue>().isEmpty;
    final repeated = synergy.issues.whereType<RepeatedTypeIssue>().isEmpty;
    final line = synergy.trickRoom
        ? SynergyRules.slowSpeed
        : SynergyRules.fastSpeed;
    Widget status(String title, String text, {required bool ok}) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        ok ? Icons.check_circle : Icons.warning_amber,
        color: ok ? scheme.primary : scheme.error,
      ),
      title: Text(title),
      subtitle: Text(text),
    );
    return _Section(
      title: l10n.synergyBalance,
      children: [
        status(
          l10n.synergyMixTitle(synergy.physical, synergy.special),
          l10n.synergyMixText,
          ok: mix,
        ),
        status(
          repeated ? l10n.synergyNoRepeat : l10n.synergyRepeatTitle,
          repeated
              ? l10n.synergyNoRepeatText
              : _types([
                  for (final r in synergy.issues.whereType<RepeatedTypeIssue>())
                    r.type,
                ]),
          ok: repeated,
        ),
        Text(l10n.synergySpeed, style: theme.textTheme.titleSmall),
        for (final (i, m) in synergy.members.indexed)
          Row(
            key: ValueKey('speed-$i'),
            spacing: 8,
            children: [
              PokemonSprite(
                url: team.members[i].formRef?.spriteUrl,
                size: 32,
                semanticLabel: m.name,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    alignment: AlignmentDirectional.centerStart,
                    children: [
                      LinearProgressIndicator(
                        value: (m.speed / _maxSpeed).clamp(0, 1),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      PositionedDirectional(
                        start: constraints.maxWidth * line / _maxSpeed,
                        child: Container(
                          width: 2,
                          height: 16,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '${m.speed}',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        Text(
          synergy.trickRoom ? l10n.synergySlowLine : l10n.synergyFastLine,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
