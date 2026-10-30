import 'package:flutter/material.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/utils/pokemon_types.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/core/widgets/type_chip.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/moves/domain/moves_data.dart';
import 'package:ishinydex/features/moves/presentation/move_page.dart';
import 'package:ishinydex/features/moves/presentation/moves_widgets.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/form_picker.dart';

/// Abre a busca de golpes (#369), por cima de tudo. Pela aba Golpes, já com
/// o jogo ([group]), a forma ([formId]) e o texto ([query]); pelo menu do
/// PersonalDex, vazia.
Future<void> openMoveSearch(
  BuildContext context, {
  String? group,
  int? formId,
  String query = '',
}) => Navigator.of(context, rootNavigator: true).push(
  MaterialPageRoute<void>(
    builder: (_) => MoveSearchPage(group: group, formId: formId, query: query),
  ),
);

/// A busca de golpes (#369): o texto e os filtros em chips, o jogo (sempre
/// um, porque o golpe existe ou não em cada jogo), o tipo, a categoria, o
/// alvo e quem aprende. Com "quem aprende", cada linha diz como. Tocar num
/// golpe abre o golpe. As mesmas consultas servem ao team builder (#231).
class MoveSearchPage extends StatefulWidget {
  const MoveSearchPage({this.group, this.formId, this.query = '', super.key});

  final String? group;
  final int? formId;
  final String query;

  @override
  State<MoveSearchPage> createState() => _MoveSearchPageState();
}

class _MoveSearchPageState extends State<MoveSearchPage> {
  late final _search = TextEditingController(text: widget.query);
  late String? _group = widget.group;
  late int? _formId = widget.formId;
  String? _type;
  String? _category;
  String? _target;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.moveSearchTitle)),
    body: MovesGate(
      builder: (data, catalog) => _results(context, data, catalog),
    ),
  );

  Widget _results(BuildContext context, MovesData data, Catalog catalog) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final groups = newestFirst(
      data.versionGroups.where((g) => data.movesIn(g).isNotEmpty),
      catalog,
    );
    final group = groups.contains(_group) ? _group! : groups.first;
    final generation = catalog.versionGroupGeneration(group);
    final available = data.movesIn(group);
    final form = switch (_formId) {
      final id? when catalog.hasForm(id) => catalog.formRef(id),
      _ => null,
    };
    // O que a forma aprende no jogo: golpe → como.
    final learned = <int, List<MoveLearn>>{};
    if (form != null) {
      for (final pokemon in catalog.movesPokemonIds(form.id)) {
        final learnset = data.learnset(pokemon, group);
        if (learnset.isEmpty) continue;
        for (final learn in learnset) {
          (learned[learn.move.index] ??= []).add(learn);
        }
        break;
      }
    }
    final query = foldForSearch(_search.text.trim());
    MoveStats stats(MoveInfo move) =>
        move.statsIn(group, catalog.versionGroupOrder);
    final results = [
      for (final move in available)
        if ((query.isEmpty || foldForSearch(move.label).contains(query)) &&
            (_type == null || stats(move).type == _type) &&
            (_category == null || move.category == _category) &&
            (_target == null || move.target == _target) &&
            (form == null || learned.containsKey(move.index)))
          move,
    ]..sort((a, b) => a.label.compareTo(b.label));
    final count = [
      l10n.movesCount(results.length),
      if (form != null) l10n.moveLearnedBy(form.displayName),
    ].join(' · ');
    final targets = {for (final move in available) move.target}..remove('');

    final header = <Widget>[
      TextField(
        controller: _search,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: l10n.movesSearch,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: l10n.movesClearSearch,
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(_search.clear),
                ),
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          // O jogo: sempre um, sem tirar.
          _FilterChip(
            key: const ValueKey('filter-game'),
            label: gameLabel(catalog, group),
            selected: true,
            onPressed: () async {
              final picked = await showGameSheet(
                context,
                catalog: catalog,
                groups: groups,
                selected: group,
              );
              if (picked != null) setState(() => _group = picked);
            },
          ),
          _FilterChip(
            key: const ValueKey('filter-type'),
            label: _type == null ? l10n.moveFilterType : typeLabel(_type!),
            selected: _type != null,
            onPressed: () => _pick(
              context,
              options: [for (final c in catalog.options.type) c.value],
              label: typeLabel,
              leading: TypeIcon.new,
              onPicked: (type) => _type = type,
            ),
            onClear: () => setState(() => _type = null),
          ),
          _FilterChip(
            key: const ValueKey('filter-category'),
            label: _category == null
                ? l10n.moveFilterCategory
                : moveCategoryLabel(l10n, _category!),
            selected: _category != null,
            onPressed: () => _pick(
              context,
              options: const ['physical', 'special', 'status'],
              label: (c) => moveCategoryLabel(l10n, c),
              leading: MoveCategoryIcon.new,
              onPicked: (category) => _category = category,
            ),
            onClear: () => setState(() => _category = null),
          ),
          _FilterChip(
            key: const ValueKey('filter-target'),
            label: _target == null
                ? l10n.moveFilterTarget
                : moveTargetLabel(l10n, _target!),
            selected: _target != null,
            onPressed: () => _pick(
              context,
              options: [...targets]
                ..sort(
                  (a, b) => moveTargetLabel(
                    l10n,
                    a,
                  ).compareTo(moveTargetLabel(l10n, b)),
                ),
              label: (t) => moveTargetLabel(l10n, t),
              onPicked: (target) => _target = target,
            ),
            onClear: () => setState(() => _target = null),
          ),
          _FilterChip(
            key: const ValueKey('filter-learner'),
            label: form?.displayName ?? l10n.moveFilterLearner,
            avatar: form == null
                ? null
                : PokemonSprite(url: form.spriteUrl, size: 24),
            selected: form != null,
            onPressed: () async {
              final picked = await showFormPicker(context);
              if (picked != null) setState(() => _formId = picked.id);
            },
            onClear: () => setState(() => _formId = null),
          ),
        ],
      ),
      Text(
        count,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      if (results.isEmpty)
        MovesMessage(l10n.movesNoResults(_search.text.trim()))
      else
        const MoveRow.header(),
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: header.length + results.length,
      itemBuilder: (context, index) {
        if (index < header.length) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: index < header.length - 1 ? 12 : 0,
            ),
            child: header[index],
          );
        }
        final move = results[index - header.length];
        return MoveRow(
          key: ValueKey('move-${move.name}'),
          move: move,
          stats: stats(move),
          detail: switch (learned[move.index]) {
            final learns? => learnHow(l10n, learns, generation),
            null => null,
          },
          onTap: () => openMove(context, move, group),
        );
      },
    );
  }

  /// Escolhe uma opção de um filtro numa folha.
  Future<void> _pick(
    BuildContext context, {
    required List<String> options,
    required String Function(String option) label,
    required void Function(String option) onPicked,
    Widget Function(String option)? leading,
  }) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final option in options)
              ListTile(
                leading: leading?.call(option),
                title: Text(label(option)),
                onTap: () => Navigator.pop(context, option),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => onPicked(picked));
  }
}

/// Um filtro em chip: sem valor, o nome do filtro com a seta; com valor,
/// o valor marcado e o "x" para tirar (o jogo não tem o "x").
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.onClear,
    this.avatar,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final VoidCallback? onClear;
  final Widget? avatar;

  @override
  Widget build(BuildContext context) => InputChip(
    label: Text(label),
    avatar: avatar,
    selected: selected,
    showCheckmark: false,
    onPressed: onPressed,
    onDeleted: selected ? onClear ?? onPressed : onPressed,
    deleteIcon: Icon(
      selected && onClear != null ? Icons.close : Icons.arrow_drop_down,
      size: 18,
    ),
    deleteButtonTooltipMessage: selected && onClear != null
        ? context.l10n.moveFilterClear
        : '',
  );
}
