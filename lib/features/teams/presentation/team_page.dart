import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/responsive/breakpoints.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/utils/pokemon_types.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/confirm_dialog.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/core/widgets/type_chip.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/moves/domain/moves_data.dart';
import 'package:ishinydex/features/moves/presentation/moves_widgets.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/form_picker.dart';
import 'package:ishinydex/features/teams/domain/models.dart';
import 'package:ishinydex/features/teams/domain/team_rules.dart';
import 'package:ishinydex/features/teams/presentation/member_editor.dart';
import 'package:ishinydex/features/teams/presentation/synergy_page.dart';
import 'package:ishinydex/features/teams/presentation/team_pickers.dart';
import 'package:ishinydex/features/teams/presentation/team_widgets.dart';
import 'package:ishinydex/features/teams/teams_providers.dart';

/// O time [teamId] (#231): o jogo, o nível, os membros e a exportação. No
/// compacto, cada membro abre numa tela própria ([MemberPage]); nos demais,
/// o membro escolhido fica ao lado da lista.
class TeamPage extends ConsumerStatefulWidget {
  const TeamPage({required this.teamId, super.key});

  final int teamId;

  @override
  ConsumerState<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends ConsumerState<TeamPage> {
  /// O membro aberto ao lado da lista (fora do compacto).
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final team = _teamOf(ref, widget.teamId);
    return switch (ref.watch(teamsProvider)) {
      AsyncData() when team == null => Scaffold(
        appBar: AppBar(),
        body: EmptyView(message: context.l10n.problemNotFound),
      ),
      AsyncData() => _page(team!),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          error: error,
          onRetry: () => ref.invalidate(teamsProvider),
        ),
      ),
      _ => const Scaffold(body: LoadingView()),
    };
  }

  Widget _page(Team team) {
    final l10n = context.l10n;
    final compact = WindowSize.of(context).isCompact;
    return MovesGate(
      builder: (data, catalog) {
        final selected = team.members.isEmpty
            ? null
            : _selected.clamp(0, team.members.length - 1);
        final list = _MemberList(
          team: team,
          data: data,
          catalog: catalog,
          selected: compact ? null : selected,
          onOpen: (index) => compact
              ? context.go(Routes.teamMember(team.id, index))
              : setState(() => _selected = index),
        );
        return Scaffold(
          appBar: AppBar(
            title: Text(team.name),
            actions: [
              if (!groupsWithoutExport.contains(team.versionGroup))
                IconButton(
                  key: const ValueKey('team-export'),
                  tooltip: l10n.teamExport,
                  icon: const Icon(Icons.ios_share),
                  onPressed: team.members.isEmpty
                      ? null
                      : () => showExportSheet(
                          context,
                          teamShowdownText(team, catalog, data),
                        ),
                ),
              _TeamMenu(team: team),
            ],
          ),
          body: compact || selected == null
              ? list
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 440, child: list),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: MemberEditor(
                        key: ValueKey(('member', selected)),
                        team: team,
                        index: selected,
                        data: data,
                        catalog: catalog,
                        onRemoved: () => setState(() => _selected = 0),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

Team? _teamOf(WidgetRef ref, int id) =>
    ref.watch(teamsProvider).value?.where((t) => t.id == id).firstOrNull;

/// O membro [index] do time [teamId], numa tela própria (no compacto).
class MemberPage extends ConsumerWidget {
  const MemberPage({required this.teamId, required this.index, super.key});

  final int teamId;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final team = _teamOf(ref, teamId);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.memberTitle)),
      body: switch (ref.watch(teamsProvider)) {
        AsyncData() when team == null || index >= team.members.length =>
          EmptyView(message: l10n.problemNotFound),
        AsyncData() => MovesGate(
          builder: (data, catalog) => MemberEditor(
            team: team!,
            index: index,
            data: data,
            catalog: catalog,
            onRemoved: () => context.go(Routes.team(teamId)),
          ),
        ),
        AsyncError(:final error) => ErrorView(error: error),
        _ => const LoadingView(),
      },
    );
  }
}

/// Renomear e excluir o time.
class _TeamMenu extends ConsumerWidget {
  const _TeamMenu({required this.team});

  final Team team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      key: const ValueKey('team-menu'),
      onSelected: (action) async {
        switch (action) {
          case 'rename':
            final name = await _askName(context, team.name);
            if (name == null || !context.mounted) return;
            await _run(
              context,
              () =>
                  ref.read(teamActionsProvider).save(team.copyWith(name: name)),
            );
          case _:
            final confirmed = await showConfirmDialog(
              context,
              title: l10n.teamDeleteQuestion(team.name),
              message: l10n.teamDeleteDetail,
              confirmLabel: l10n.teamDelete,
              destructive: true,
            );
            if (!confirmed || !context.mounted) return;
            await _run(context, () async {
              await ref.read(teamActionsProvider).delete(team.id);
              if (context.mounted) context.go(Routes.teams);
            });
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          key: const ValueKey('team-rename'),
          value: 'rename',
          child: Text(l10n.teamRename),
        ),
        PopupMenuItem(
          key: const ValueKey('team-delete'),
          value: 'delete',
          child: Text(l10n.teamDelete),
        ),
      ],
    );
  }
}

Future<void> _run(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } on AppFailure catch (failure) {
    if (context.mounted) showTeamFailure(context, failure);
  }
}

Future<String?> _askName(BuildContext context, String current) =>
    showDialog<String>(
      context: context,
      builder: (context) => _NameDialog(current: current),
    );

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.current});

  final String current;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _text = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = _text.text.trim();
    return AlertDialog(
      title: Text(l10n.teamRename),
      content: TextField(
        key: const ValueKey('team-name'),
        controller: _text,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.teamName,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('team-name-save'),
          onPressed: name.isEmpty
              ? null
              : () => Navigator.of(context).pop(name),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// O jogo, o nível (tocar troca o de todos), quantos são e os membros; o
/// "Adicionar Pokémon" enquanto cabe.
class _MemberList extends ConsumerWidget {
  const _MemberList({
    required this.team,
    required this.data,
    required this.catalog,
    required this.selected,
    required this.onOpen,
  });

  final Team team;
  final MovesData data;
  final Catalog catalog;
  final int? selected;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final group = team.versionGroup;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(
              avatar: TeamGameIcons(catalog, group),
              label: Text(gameLabel(catalog, group)),
            ),
            ActionChip(
              key: const ValueKey('team-level'),
              label: Text(teamLevelText(context, team)),
              onPressed: team.members.isEmpty
                  ? null
                  : () async {
                      final level = await showNumberDialog(
                        context,
                        title: l10n.teamSetLevelTitle,
                        hint: l10n.memberLevelHint,
                        initial: team.members.first.level,
                        min: 1,
                        max: 100,
                      );
                      if (level == null || !context.mounted) return;
                      await _run(
                        context,
                        () => ref
                            .read(teamActionsProvider)
                            .save(
                              team.copyWith(
                                members: [
                                  for (final m in team.members)
                                    m.copyWith(level: level),
                                ],
                              ),
                            ),
                      );
                    },
            ),
            Text(
              l10n.teamMembersCount(team.members.length),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (team.members.isNotEmpty)
          SynergyCard(team: team, catalog: catalog, data: data),
        if (groupsWithoutExport.contains(group))
          Card.outlined(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.teamNoExport, style: theme.textTheme.bodyMedium),
            ),
          ),
        if (team.members.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              l10n.teamNoMembers,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final (i, member) in team.members.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MemberCard(
              key: ValueKey('member-$i'),
              member: member,
              group: group,
              data: data,
              catalog: catalog,
              selected: i == selected,
              onTap: () => onOpen(i),
            ),
          ),
        if (!team.isFull)
          OutlinedButton.icon(
            key: const ValueKey('team-add'),
            icon: const Icon(Icons.add),
            label: Text(l10n.teamAddMember),
            onPressed: () async {
              final form = await showFormPicker(
                context,
                allow: (f) => formInGame(data, catalog, f.id, group),
              );
              if (form == null || !context.mounted) return;
              final abilities = catalog.formDetail(form.id).abilities;
              await _run(context, () async {
                await ref
                    .read(teamActionsProvider)
                    .saveMember(
                      team,
                      team.members.length,
                      TeamMember(
                        form: form.id,
                        formRef: form,
                        ability:
                            abilities.length == 1 &&
                                !groupsWithoutAbilities.contains(group)
                            ? abilities.single.ability
                            : null,
                      ),
                    );
                onOpen(team.members.length);
              });
            },
          ),
      ],
    );
  }
}

/// Um membro na lista do time: a forma, os tipos, o espécime ligado, o
/// Tera, o item com a habilidade e os golpes.
class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.group,
    required this.data,
    required this.catalog,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final TeamMember member;
  final String group;
  final MovesData data;
  final Catalog catalog;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final detail = catalog.formDetail(member.form);
    final item = switch (member.item) {
      final item? => catalog.heldItem(item),
      null => null,
    };
    final itemLine = [
      if (member.item case final name?) item?.label ?? name,
      if (member.ability case final ability?) abilityLabel(ability),
    ].join(' · ');
    final moves = memberMoves(member, data);
    return Card.filled(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: selected ? scheme.secondaryContainer : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: selected
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              Row(
                spacing: 12,
                children: [
                  PokemonSprite(url: member.formRef?.spriteUrl, size: 56),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        Text(
                          member.formRef?.displayName ?? detail.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final t in detail.types)
                              TypeChip(t.type, small: true),
                            if (member.specimen != null)
                              Tooltip(
                                message: l10n.teamLinkedHint,
                                child: Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(Icons.star, size: 14),
                                  label: Text(l10n.teamSpecimen),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (member.tera case final tera?
                      when teraGroups.contains(group))
                    Tooltip(
                      message: 'Tera ${typeLabel(tera)}',
                      child: Column(
                        spacing: 2,
                        children: [
                          TypeIcon(tera, size: 28),
                          Text(
                            l10n.memberTera,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (itemLine.isNotEmpty)
                Row(
                  spacing: 6,
                  children: [
                    if (item != null)
                      PokemonSprite(url: item.spriteUrl, size: 24),
                    Expanded(
                      child: Text(
                        itemLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ),
                  ],
                ),
              if (moves.isNotEmpty)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = (constraints.maxWidth - 6) / 2;
                    return Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final move in moves)
                          Container(
                            width: width,
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              spacing: 6,
                              children: [
                                TypeIcon(
                                  move
                                      .statsIn(group, catalog.versionGroupOrder)
                                      .type,
                                ),
                                Expanded(
                                  child: Text(
                                    move.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// O texto do Showdown, para copiar.
Future<void> showExportSheet(BuildContext context, String text) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final l10n = context.l10n;
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                Text(l10n.teamExport, style: theme.textTheme.titleLarge),
                Text(
                  l10n.teamExportHint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        text,
                        key: const ValueKey('export-text'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                ),
                FilledButton.icon(
                  key: const ValueKey('export-copy'),
                  icon: const Icon(Icons.copy),
                  label: Text(l10n.teamCopy),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(l10n.teamCopied)));
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
