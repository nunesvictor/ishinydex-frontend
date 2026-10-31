import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/utils/pokemon_types.dart';
import 'package:ishinydex/core/widgets/confirm_dialog.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/core/widgets/type_chip.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/moves/domain/moves_data.dart';
import 'package:ishinydex/features/moves/presentation/moves_widgets.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_labels.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/form_picker.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';
import 'package:ishinydex/features/teams/domain/models.dart';
import 'package:ishinydex/features/teams/domain/team_rules.dart';
import 'package:ishinydex/features/teams/presentation/team_pickers.dart';
import 'package:ishinydex/features/teams/presentation/team_widgets.dart';
import 'package:ishinydex/features/teams/teams_providers.dart';

/// Um membro do time (#231), numa tela própria: a forma, o espécime ligado,
/// o nível, a habilidade, a natureza, o item, o Tera, os golpes e os EVs,
/// com os stats calculados no nível.
class MemberEditor extends ConsumerWidget {
  const MemberEditor({
    required this.team,
    required this.index,
    required this.data,
    required this.catalog,
    required this.onRemoved,
    super.key,
  });

  final Team team;
  final int index;
  final MovesData data;
  final Catalog catalog;

  /// Depois de tirar o membro do time.
  final VoidCallback onRemoved;

  String get _group => team.versionGroup;

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    TeamMember member,
  ) async {
    try {
      await ref.read(teamActionsProvider).saveMember(team, index, member);
    } on AppFailure catch (failure) {
      if (context.mounted) showTeamFailure(context, failure);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final member = team.members[index];
    final detail = catalog.formDetail(member.form);
    final learned = formLearnset(data, catalog, member.form, _group);
    final name = member.formRef?.displayName ?? detail.name;
    final hasAbilities = !groupsWithoutAbilities.contains(_group);
    final muted = theme.colorScheme.onSurfaceVariant;
    Future<void> save(TeamMember updated) => _save(context, ref, updated);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        Row(
          spacing: 16,
          children: [
            PokemonSprite(url: member.formRef?.spriteUrl, size: 96),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Text(name, style: theme.textTheme.titleLarge),
                  Wrap(
                    spacing: 4,
                    children: [for (final t in detail.types) TypeChip(t.type)],
                  ),
                  OutlinedButton(
                    key: const ValueKey('member-form'),
                    onPressed: () => _changeForm(context, member, save),
                    child: Text(l10n.memberChangeForm),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SpecimenLink(member: member, pullsAbility: hasAbilities, onSave: save),
        const SizedBox(height: 8),
        _Field(
          key: const ValueKey('member-level'),
          label: l10n.memberLevel,
          value: '${member.level}',
          onTap: () async {
            final level = await showNumberDialog(
              context,
              title: l10n.memberLevel,
              hint: l10n.memberLevelHint,
              initial: member.level,
              min: 1,
              max: 100,
            );
            if (level != null) await save(member.copyWith(level: level));
          },
        ),
        if (hasAbilities)
          _abilityField(context, member, detail.abilities, save),
        _natureField(context, member, save),
        _Field(
          key: const ValueKey('member-item'),
          label: l10n.memberItem,
          value: switch (member.item) {
            final item? => catalog.heldItem(item)?.label ?? item,
            null => l10n.memberNoItem,
          },
          leading: switch (member.item) {
            final item? => PokemonSprite(
              url: catalog.heldItem(item)?.spriteUrl,
              size: 24,
            ),
            null => null,
          },
          onTap: () async {
            final items = catalog.heldItemsIn(_group);
            final picked = await showItemPicker(
              context,
              items: items,
              countText: l10n.memberItemsCount(
                items.length,
                gameLabel(catalog, _group),
              ),
              current: member.item,
            );
            if (picked != null) {
              await save(member.copyWith(item: picked.value));
            }
          },
        ),
        if (teraGroups.contains(_group)) _teraField(context, member, save),
        if (!hasAbilities)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Icon(Icons.info_outline, size: 18, color: muted),
                Expanded(
                  child: Text(
                    l10n.memberNoAbilities,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Text(l10n.memberMoves, style: theme.textTheme.titleSmall),
        ),
        MovesNoValuesNote(_group),
        for (var slot = 0; slot < TeamMember.maxMoves; slot++)
          _moveSlot(context, member, learned, slot, name, save),
        _Stats(
          member: member,
          detail: detail,
          nature: natureOf(catalog, member.nature),
          onSave: save,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const ValueKey('member-remove'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: l10n.memberRemoveQuestion(name),
                message: l10n.teamDeleteDetail,
                confirmLabel: l10n.memberRemove,
                destructive: true,
              );
              if (!confirmed || !context.mounted) return;
              try {
                await ref.read(teamActionsProvider).removeMember(team, index);
                onRemoved();
              } on AppFailure catch (failure) {
                if (context.mounted) showTeamFailure(context, failure);
              }
            },
            child: Text(l10n.memberRemove),
          ),
        ),
      ],
    );
  }

  /// Trocar a forma: fica o que a nova aceita (a habilidade dela e os
  /// golpes que ela aprende no jogo); o espécime ligado sai.
  Future<void> _changeForm(
    BuildContext context,
    TeamMember member,
    Future<void> Function(TeamMember) save,
  ) async {
    final form = await showFormPicker(
      context,
      allow: (f) => formInGame(data, catalog, f.id, _group),
    );
    if (form == null) return;
    final abilities = catalog.formDetail(form.id).abilities;
    final learned = {
      for (final learns in formLearnset(data, catalog, form.id, _group).values)
        learns.first.move.name,
    };
    await save(
      member.copyWith(
        form: form.id,
        formRef: form,
        specimen: null,
        ability: groupsWithoutAbilities.contains(_group)
            ? null
            : abilities.any((a) => a.ability == member.ability)
            ? member.ability
            : abilities.length == 1
            ? abilities.single.ability
            : null,
        moves: [
          for (final move in member.moves)
            if (learned.contains(move)) move,
        ],
      ),
    );
  }

  Widget _abilityField(
    BuildContext context,
    TeamMember member,
    List<FormAbility> abilities,
    Future<void> Function(TeamMember) save,
  ) {
    final l10n = context.l10n;
    final sorted = [...abilities]..sort((a, b) => a.slot.compareTo(b.slot));
    if (sorted.length == 1) {
      return _Field(
        key: const ValueKey('member-ability'),
        label: l10n.memberAbility,
        value: abilityLabel(sorted.single.ability),
        hint: l10n.memberOnlyAbility,
      );
    }
    final current = sorted.where((a) => a.ability == member.ability);
    return _Field(
      key: const ValueKey('member-ability'),
      label: l10n.memberAbility,
      value: switch (member.ability) {
        final ability? => abilityLabel(ability),
        null => l10n.memberNotChosen,
      },
      hint: current.firstOrNull?.isHidden ?? false
          ? l10n.memberHiddenAbility
          : null,
      onTap: sorted.isEmpty
          ? null
          : () async {
              final picked = await _showOptions(
                context,
                title: l10n.memberAbility,
                current: member.ability,
                options: [
                  for (final a in sorted)
                    (
                      value: a.ability,
                      label: abilityLabel(a.ability),
                      subtitle: a.isHidden ? l10n.memberHiddenAbility : null,
                      leading: null,
                    ),
                ],
              );
              if (picked != null) {
                await save(member.copyWith(ability: picked.value));
              }
            },
    );
  }

  Widget _natureField(
    BuildContext context,
    TeamMember member,
    Future<void> Function(TeamMember) save,
  ) {
    final l10n = context.l10n;
    String effect(Choice nature) =>
        switch ((nature.increased, nature.decreased)) {
          (final up?, final down?) when up != down => l10n.memberNatureEffect(
            l10n.stat(up),
            l10n.stat(down),
          ),
          _ => l10n.memberNatureNeutral,
        };
    String label(Choice nature) => nature.labels['en'] ?? nature.label;
    final nature = natureOf(catalog, member.nature);
    return _Field(
      key: const ValueKey('member-nature'),
      label: l10n.memberNature,
      value: nature == null ? l10n.memberNotChosen : label(nature),
      hint: nature == null ? null : effect(nature),
      onTap: () async {
        final picked = await _showOptions(
          context,
          title: l10n.memberNature,
          current: member.nature,
          options: [
            (
              value: null,
              label: l10n.memberNotChosen,
              subtitle: null,
              leading: null,
            ),
            for (final n in catalog.options.nature)
              (
                value: n.value,
                label: label(n),
                subtitle: effect(n),
                leading: null,
              ),
          ],
        );
        if (picked != null) await save(member.copyWith(nature: picked.value));
      },
    );
  }

  Widget _teraField(
    BuildContext context,
    TeamMember member,
    Future<void> Function(TeamMember) save,
  ) {
    final l10n = context.l10n;
    return _Field(
      key: const ValueKey('member-tera'),
      label: l10n.memberTera,
      value: switch (member.tera) {
        final tera? => typeLabel(tera),
        null => l10n.memberNotChosen,
      },
      leading: switch (member.tera) {
        final tera? => TypeIcon(tera, size: 24),
        null => null,
      },
      onTap: () async {
        final picked = await _showOptions(
          context,
          title: l10n.memberTera,
          current: member.tera,
          options: [
            (
              value: null,
              label: l10n.memberNotChosen,
              subtitle: null,
              leading: null,
            ),
            for (final type in teraTypes)
              (
                value: type,
                label: typeLabel(type),
                subtitle: null,
                leading: TypeIcon(type, size: 24),
              ),
          ],
        );
        if (picked != null) await save(member.copyWith(tera: picked.value));
      },
    );
  }

  /// O slot [slot] dos golpes: o golpe, ou "Escolher golpe" no primeiro
  /// vazio; tocar abre a lista do que a forma aprende no jogo.
  Widget _moveSlot(
    BuildContext context,
    TeamMember member,
    Map<int, List<MoveLearn>> learned,
    int slot,
    String name,
    Future<void> Function(TeamMember) save,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final moves = memberMoves(member, data);
    if (slot > moves.length) return const SizedBox.shrink();
    final move = slot < moves.length ? moves[slot] : null;
    Future<void> pick() async {
      final picked = await showMovePicker(
        context,
        title: l10n.memberMoveSlot(slot + 1),
        countText: l10n.memberMovesCount(
          learned.length,
          name,
          gameLabel(catalog, _group),
        ),
        learned: learned,
        taken: {
          for (final m in moves)
            if (m != move) m.name,
        },
        group: _group,
        catalog: catalog,
        current: move,
      );
      if (picked == null) return;
      final names = [for (final m in moves) m.name];
      await save(
        member.copyWith(
          moves: [
            for (final (i, m) in names.indexed)
              if (i != slot) m else ?picked.value,
            if (slot == names.length) ?picked.value,
          ],
        ),
      );
    }

    final number = SizedBox(
      width: 20,
      child: Text(
        '${slot + 1}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
    if (move == null) {
      return ListTile(
        key: ValueKey('member-move-$slot'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: number,
        minLeadingWidth: 20,
        title: Text(l10n.memberPickMove),
        trailing: const Icon(Icons.add),
        onTap: pick,
      );
    }
    return Row(
      children: [
        number,
        Expanded(
          child: MoveRow(
            key: ValueKey('member-move-$slot'),
            move: move,
            stats: move.statsIn(_group, catalog.versionGroupOrder),
            detail: switch (learned[move.index]) {
              final learns? => learnHow(
                l10n,
                learns,
                catalog.versionGroupGeneration(_group),
              ),
              null => null,
            },
            onTap: pick,
          ),
        ),
      ],
    );
  }
}

/// Uma linha de campo: o rótulo, o valor (com a dica embaixo) e a seta
/// quando dá para trocar.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    this.hint,
    this.leading,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final String? hint;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          spacing: 12,
          children: [
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
            ?leading,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(value, style: theme.textTheme.bodyLarge),
                  if (hint case final hint?)
                    Text(
                      hint,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                ],
              ),
            ),
            if (onTap != null) Icon(Icons.arrow_drop_down, color: muted),
          ],
        ),
      ),
    );
  }
}

typedef _Option = ({
  String? value,
  String label,
  String? subtitle,
  Widget? leading,
});

/// Uma lista de opções numa folha; devolve a escolhida (`null` = fechou).
Future<PickResult?> _showOptions(
  BuildContext context, {
  required String title,
  required String? current,
  required List<_Option> options,
}) => showModalBottomSheet<PickResult>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: ListView(
      shrinkWrap: true,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        for (final option in options)
          ListTile(
            key: ValueKey('option-${option.value}'),
            leading: option.leading,
            title: Text(option.label),
            subtitle: option.subtitle == null ? null : Text(option.subtitle!),
            selected: option.value == current,
            trailing: option.value == current ? const Icon(Icons.check) : null,
            onTap: () => Navigator.of(context).pop((value: option.value)),
          ),
      ],
    ),
  ),
);

/// O espécime ligado ("Ligado a…", com o "Desligar"), ou o botão para
/// ligar um, que puxa a natureza e a habilidade dele.
class _SpecimenLink extends ConsumerWidget {
  const _SpecimenLink({
    required this.member,
    required this.pullsAbility,
    required this.onSave,
  });

  final TeamMember member;

  /// Puxa também a habilidade (fora do Z-A, que não tem).
  final bool pullsAbility;
  final Future<void> Function(TeamMember) onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    if (member.specimen case final id?) {
      final name = ref.watch(specimenProvider(id)).value?.displayName ?? '';
      return Card.filled(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(Icons.link, color: muted),
          title: Text(l10n.memberLinked(name)),
          trailing: TextButton(
            key: const ValueKey('member-unlink'),
            onPressed: () => onSave(member.copyWith(specimen: null)),
            child: Text(l10n.memberUnlink),
          ),
        ),
      );
    }
    return Card.filled(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: const ValueKey('member-link'),
        leading: Icon(Icons.link, color: muted),
        title: Text(l10n.memberLinkSpecimen),
        subtitle: Text(
          pullsAbility ? l10n.memberLinkHint : l10n.memberLinkHintNoAbility,
        ),
        onTap: () async {
          final specimens = await ref.read(
            formSpecimensProvider(member.form).future,
          );
          if (!context.mounted) return;
          final picked = await showSpecimenPicker(
            context,
            specimens: specimens,
          );
          if (picked == null) return;
          await onSave(
            member.copyWith(
              specimen: picked.id,
              nature: picked.nature ?? member.nature,
              ability: pullsAbility ? picked.ability ?? member.ability : null,
            ),
          );
        },
      ),
    );
  }
}

/// Os EVs e os stats no nível do membro: a barra do total e, por stat, o
/// base, o controle do EV, o IV (tocar para trocar) e o total calculado,
/// com a seta da natureza.
class _Stats extends StatelessWidget {
  const _Stats({
    required this.member,
    required this.detail,
    required this.nature,
    required this.onSave,
  });

  final TeamMember member;
  final FormDetail detail;
  final Choice? nature;
  final Future<void> Function(TeamMember) onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final small = theme.textTheme.bodySmall?.copyWith(color: muted);
    final total = member.evTotal;
    final bases = {for (final s in detail.stats) s.stat: s.baseStat};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  l10n.memberEvsStats(member.level),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(l10n.memberEvTotal(total), style: small),
            ],
          ),
        ),
        LinearProgressIndicator(
          value: total / TeamMember.maxEvTotal,
          semanticsLabel: l10n.memberEvTotal(total),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: _StatColumns(
            label: Text(l10n.memberStat, style: small),
            base: Text(l10n.memberBase, style: small, textAlign: TextAlign.end),
            ev: Text('EV', style: small),
            evValue: Text('EV', style: small, textAlign: TextAlign.end),
            iv: Text('IV', style: small, textAlign: TextAlign.end),
            total: Text(
              l10n.memberTotal,
              style: small,
              textAlign: TextAlign.end,
            ),
          ),
        ),
        for (final stat in teamStats)
          _StatRow(
            key: ValueKey('stat-$stat'),
            member: member,
            stat: stat,
            base: bases[stat] ?? 0,
            nature: nature,
            alwaysOneHp: detail.name == 'shedinja',
            onSave: onSave,
          ),
      ],
    );
  }
}

/// As colunas da tabela de stats, no cabeçalho e em cada linha.
class _StatColumns extends StatelessWidget {
  const _StatColumns({
    required this.label,
    required this.base,
    required this.ev,
    required this.evValue,
    required this.iv,
    required this.total,
  });

  final Widget label;
  final Widget base;
  final Widget ev;
  final Widget evValue;
  final Widget iv;
  final Widget total;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 8,
    children: [
      SizedBox(width: 72, child: label),
      SizedBox(width: 32, child: base),
      Expanded(child: ev),
      SizedBox(width: 32, child: evValue),
      SizedBox(width: 28, child: iv),
      SizedBox(width: 56, child: total),
    ],
  );
}

class _StatRow extends StatefulWidget {
  const _StatRow({
    required this.member,
    required this.stat,
    required this.base,
    required this.nature,
    required this.alwaysOneHp,
    required this.onSave,
    super.key,
  });

  final TeamMember member;
  final String stat;
  final int base;
  final Choice? nature;
  final bool alwaysOneHp;
  final Future<void> Function(TeamMember) onSave;

  @override
  State<_StatRow> createState() => _StatRowState();
}

class _StatRowState extends State<_StatRow> {
  /// O EV enquanto o controle é arrastado; `null` = o do membro.
  int? _dragging;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final member = widget.member;
    final stat = widget.stat;
    final ev = _dragging ?? member.ev(stat);
    final iv = member.iv(stat);
    final nature = widget.nature;
    final factor = natureFactor(
      stat,
      increased: nature?.increased,
      decreased: nature?.decreased,
    );
    final value = statValue(
      stat,
      base: widget.base,
      level: member.level,
      ev: ev,
      iv: iv,
      factor: factor,
      alwaysOneHp: widget.alwaysOneHp,
    );
    final number = theme.textTheme.bodyMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final limit = maxEvFor(member, stat);
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: _StatColumns(
        label: Text(l10n.stat(stat), style: theme.textTheme.bodyMedium),
        base: Text(
          '${widget.base}',
          textAlign: TextAlign.end,
          style: number?.copyWith(color: muted),
        ),
        ev: Slider(
          value: ev.toDouble(),
          max: TeamMember.maxEv.toDouble(),
          divisions: TeamMember.maxEv ~/ 4,
          label: '$ev',
          semanticFormatterCallback: (v) =>
              'EV ${l10n.stat(stat)}: ${v.round()}',
          onChanged: (v) =>
              setState(() => _dragging = v.round().clamp(0, limit)),
          onChangeEnd: (v) async {
            final updated = v.round().clamp(0, limit);
            setState(() => _dragging = null);
            await widget.onSave(
              member.copyWith(evs: {...member.evs, stat: updated}),
            );
          },
        ),
        evValue: Text('$ev', textAlign: TextAlign.end, style: number),
        iv: InkWell(
          key: ValueKey('iv-$stat'),
          onTap: () async {
            final picked = await showNumberDialog(
              context,
              title: l10n.memberIvTitle(l10n.stat(stat)),
              hint: l10n.memberIvHint,
              initial: iv,
              min: 0,
              max: TeamMember.maxIv,
            );
            if (picked != null) {
              await widget.onSave(
                member.copyWith(ivs: {...member.ivs, stat: picked}),
              );
            }
          },
          child: Text('$iv', textAlign: TextAlign.end, style: number),
        ),
        // Com fonte grande, o número encolhe em vez de vazar a coluna.
        total: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerEnd,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 2,
            children: [
              Text(
                '$value',
                style: number?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: factor < 1 ? muted : null,
                ),
              ),
              if (factor > 1)
                Icon(
                  Icons.arrow_drop_up,
                  size: 16,
                  semanticLabel: l10n.memberRaised,
                )
              else if (factor < 1)
                Icon(
                  Icons.arrow_drop_down,
                  size: 16,
                  color: muted,
                  semanticLabel: l10n.memberLowered,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A falha ao gravar o time, num aviso.
void showTeamFailure(BuildContext context, AppFailure failure) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.failureText(failure))));
