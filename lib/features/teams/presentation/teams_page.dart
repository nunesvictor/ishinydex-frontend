import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/moves/moves_providers.dart';
import 'package:ishinydex/features/moves/presentation/moves_widgets.dart';
import 'package:ishinydex/features/teams/domain/models.dart';
import 'package:ishinydex/features/teams/presentation/team_widgets.dart';
import 'package:ishinydex/features/teams/teams_providers.dart';

/// A aba Times (#231): os times, cada um preso a um jogo, e o "Novo time".
class TeamsPage extends ConsumerWidget {
  const TeamsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navTeams)),
      body: MovesGate(
        builder: (data, catalog) => switch (ref.watch(teamsProvider)) {
          AsyncData(value: final teams) when teams.isEmpty => _Empty(
            onCreate: () => createTeam(context, ref, catalog),
          ),
          AsyncData(value: final teams) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            children: [
              for (final team in teams)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TeamCard(team: team, catalog: catalog),
                ),
            ],
          ),
          AsyncError(:final error) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(teamsProvider),
          ),
          _ => const LoadingView(),
        },
      ),
      floatingActionButton: switch ((
        ref.watch(teamsProvider).value,
        ref.watch(movesProvider),
        ref.watch(fakeBackendProvider).catalog,
      )) {
        (final teams?, MovesReady(), final catalog?) when teams.isNotEmpty =>
          FloatingActionButton.extended(
            onPressed: () => createTeam(context, ref, catalog),
            icon: const Icon(Icons.add),
            label: Text(l10n.teamNew),
          ),
        _ => null,
      },
    );
  }
}

/// Nenhum time: o que é o team builder e o "Novo time".
class _Empty extends StatelessWidget {
  const _Empty({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Icon(
              Icons.groups_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            Text(l10n.teamsEmpty, style: theme.textTheme.titleLarge),
            Text(
              l10n.teamsEmptyHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: Text(l10n.teamNew),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.team, required this.catalog});

  final Team team;
  final Catalog catalog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card.filled(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('team-${team.id}'),
        onTap: () => context.go(Routes.team(team.id)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: Text(
                      team.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  TeamGameIcons(catalog, team.versionGroup),
                ],
              ),
              Text(
                [
                  gameLabel(catalog, team.versionGroup),
                  context.l10n.teamMembersCount(team.members.length),
                  teamLevelText(context, team),
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: muted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (team.members.isNotEmpty)
                Wrap(
                  spacing: 4,
                  children: [
                    for (final m in team.members)
                      PokemonSprite(
                        url: m.formRef?.spriteUrl ?? '',
                        size: 48,
                        semanticLabel: m.formRef?.displayName,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pede o nome e o jogo do time novo, cria e abre o time.
Future<void> createTeam(
  BuildContext context,
  WidgetRef ref,
  Catalog catalog,
) async {
  final groups = teamGroups(catalog);
  final picked = await showDialog<({String name, String group})>(
    context: context,
    builder: (context) => _NewTeamDialog(catalog: catalog, groups: groups),
  );
  if (picked == null || !context.mounted) return;
  try {
    final team = await ref
        .read(teamActionsProvider)
        .save(Team(id: 0, name: picked.name, versionGroup: picked.group));
    if (context.mounted) context.go(Routes.team(team.id));
  } on AppFailure catch (failure) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.failureText(failure))));
    }
  }
}

class _NewTeamDialog extends StatefulWidget {
  const _NewTeamDialog({required this.catalog, required this.groups});

  final Catalog catalog;
  final List<String> groups;

  @override
  State<_NewTeamDialog> createState() => _NewTeamDialogState();
}

class _NewTeamDialogState extends State<_NewTeamDialog> {
  final _name = TextEditingController();
  late String _group = widget.groups.first;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _create() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop((name: name, group: _group));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.teamNew),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            TextField(
              key: const ValueKey('team-name'),
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.teamName,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _create(),
            ),
            GamePicker(
              catalog: widget.catalog,
              groups: widget.groups,
              selected: _group,
              onSelected: (group) => setState(() => _group = group),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('team-create'),
          onPressed: _name.text.trim().isEmpty ? null : _create,
          child: Text(l10n.teamCreate),
        ),
      ],
    );
  }
}
