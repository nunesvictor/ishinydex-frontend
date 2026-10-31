import 'package:flutter/material.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/utils/pokemon_types.dart';
import 'package:ishinydex/core/widgets/chip_icons.dart';
import 'package:ishinydex/core/widgets/game_icon.dart';
import 'package:ishinydex/core/widgets/menu_chip.dart';
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
/// alvo e quem aprende. Tipo, categoria e alvo aceitam vários valores, com
/// OU; "quem aprende" aceita várias formas, com E: só os golpes que todas
/// aprendem, e cada linha diz como cada uma aprende (#373). Tocar num golpe
/// abre o golpe. As mesmas consultas servem ao team builder (#231).
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
  late final List<int> _formIds = [?widget.formId];
  final _types = <String>{};
  final _categories = <String>{};
  final _targets = <String>{};

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
    final forms = [
      for (final id in _formIds)
        if (catalog.hasForm(id)) catalog.formRef(id),
    ];
    // O que cada forma aprende no jogo: golpe → como.
    final learned = [
      for (final form in forms) formLearnset(data, catalog, form.id, group),
    ];
    final query = foldForSearch(_search.text.trim());
    MoveStats stats(MoveInfo move) =>
        move.statsIn(group, catalog.versionGroupOrder);
    final results = [
      for (final move in available)
        if ((query.isEmpty || foldForSearch(move.label).contains(query)) &&
            (_types.isEmpty || _types.contains(stats(move).type)) &&
            (_categories.isEmpty || _categories.contains(move.category)) &&
            (_targets.isEmpty || _targets.contains(move.target)) &&
            learned.every((moves) => moves.containsKey(move.index)))
          move,
    ]..sort((a, b) => a.label.compareTo(b.label));
    final names = [for (final form in forms) form.displayName];
    final count = [
      l10n.movesCount(results.length),
      if (forms.length == 1) l10n.moveLearnedBy(names.single),
      if (forms.length > 1) l10n.moveLearnedByAll(joinLabels(l10n, names)),
    ].join(' · ');
    final targets = {for (final move in available) move.target}..remove('');
    String targetLabel(String target) => moveTargetLabel(l10n, target);
    // Os tipos dos golpes do jogo, na ordem do catálogo.
    final catalogTypes = [for (final c in catalog.options.type) c.value];
    final present = {for (final move in available) stats(move).type};
    final typeOrder = [
      ...catalogTypes.where(present.contains),
      ...present.difference(catalogTypes.toSet()).toList()..sort(),
    ];
    final types = typeOrder.where(_types.contains).toList();
    const categoryOrder = ['physical', 'special', 'status'];
    final categories = categoryOrder.where(_categories.contains).toList();
    final targetOrder = [...targets]
      ..sort((a, b) => targetLabel(a).compareTo(targetLabel(b)));
    final pickedTargets = [
      for (final t in targetOrder)
        if (_targets.contains(t)) targetLabel(t),
    ];
    final versions = catalog.versionsOfGroup(group);
    final gameName = gameLabel(catalog, group);

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
          // O jogo: sempre um, sem tirar; a face mostra as versões do grupo
          // (nas DLCs, que não têm ícone, o nome).
          FilterChip(
            key: const ValueKey('filter-game'),
            tooltip: l10n.filterGameValue(gameName),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (versions.isEmpty || group.startsWith('the-'))
                  Text(gameName)
                else
                  ChipIcons([
                    for (final v in versions) GameIcon(v, size: 18),
                  ], semanticLabel: l10n.filterGameValue(gameName)),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
            selected: true,
            showCheckmark: false,
            onSelected: (_) async {
              final picked = await showGameSheet(
                context,
                catalog: catalog,
                groups: groups,
                selected: group,
              );
              if (picked != null) setState(() => _group = picked);
            },
          ),
          _checkChip(
            key: const ValueKey('filter-type'),
            title: l10n.moveFilterType,
            options: typeOrder,
            picked: _types,
            optionLabel: typeLabel,
            icon: TypeIcon.new,
            tooltip: joinAlternatives(l10n, [
              for (final t in types) typeLabel(t),
            ]),
            icons: [for (final t in types) TypeIcon(t)],
          ),
          _checkChip(
            key: const ValueKey('filter-category'),
            title: l10n.moveFilterCategory,
            options: categoryOrder,
            picked: _categories,
            optionLabel: (c) => moveCategoryLabel(l10n, c),
            icon: MoveCategoryIcon.new,
            tooltip: joinAlternatives(l10n, [
              for (final c in categories) moveCategoryLabel(l10n, c),
            ]),
            icons: [for (final c in categories) MoveCategoryIcon(c)],
          ),
          // Os alvos não têm ícone: a face mostra o nome do primeiro e "+N".
          _checkChip(
            key: const ValueKey('filter-target'),
            title: l10n.moveFilterTarget,
            face: switch (pickedTargets) {
              [] => null,
              [final one] => one,
              [final first, ...final rest] => '$first +${rest.length}',
            },
            options: targetOrder,
            picked: _targets,
            optionLabel: targetLabel,
            tooltip: joinAlternatives(l10n, pickedTargets),
          ),
          MenuChip(
            key: const ValueKey('filter-learner'),
            label: l10n.moveFilterLearner,
            selected: forms.isNotEmpty,
            tooltip: forms.isEmpty
                ? null
                : l10n.moveFilterValue(
                    l10n.moveFilterLearner,
                    joinLabels(l10n, names),
                  ),
            icons: [
              for (final form in forms)
                PokemonSprite(url: form.spriteUrl, size: 18),
            ],
            menuChildren: [
              MenuHeader(l10n.moveFilterLearner),
              // Com várias formas, valem os golpes que todas aprendem.
              if (forms.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Text(
                    l10n.moveLearnersAll,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              for (final form in forms)
                CheckboxMenuButton(
                  key: ValueKey('learner-form-${form.id}'),
                  value: true,
                  onChanged: (_) => setState(() => _formIds.remove(form.id)),
                  child: Row(
                    spacing: 12,
                    children: [
                      PokemonSprite(url: form.spriteUrl, size: 36),
                      Text(form.displayName),
                    ],
                  ),
                ),
              if (forms.isNotEmpty) const Divider(height: 8),
              MenuItemButton(
                key: const ValueKey('learner-add'),
                leadingIcon: const Icon(Icons.add),
                onPressed: () async {
                  final picked = await showFormPicker(context);
                  if (picked != null && !_formIds.contains(picked.id)) {
                    setState(() => _formIds.add(picked.id));
                  }
                },
                child: Text(l10n.moveLearnerAdd),
              ),
            ],
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
        String how(int i) =>
            learnHow(l10n, learned[i][move.index]!, generation);
        return MoveRow(
          key: ValueKey('move-${move.name}'),
          move: move,
          stats: stats(move),
          // Uma forma: como ela aprende, ao lado do tipo (o nome está na
          // contagem). Várias: uma linha embaixo, com a miniatura de cada
          // uma no lugar do nome, para caber no celular.
          detail: forms.length == 1 ? how(0) : null,
          footer: forms.length < 2
              ? null
              : Wrap(
                  spacing: 12,
                  runSpacing: 2,
                  children: [
                    for (final (i, form) in forms.indexed)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 2,
                        children: [
                          PokemonSprite(
                            url: form.spriteUrl,
                            size: 20,
                            semanticLabel: form.displayName,
                          ),
                          Text(
                            how(i),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
          onTap: () => openMove(context, move, group),
        );
      },
    );
  }

  /// Um filtro de vários valores (OU): um [MenuChip] com uma caixa por
  /// opção. O menu fica aberto enquanto se marca. A face mostra os [icons]
  /// marcados; sem eles, o [face] ou o [title].
  Widget _checkChip({
    required Key key,
    required String title,
    required List<String> options,
    required Set<String> picked,
    required String Function(String option) optionLabel,
    required String tooltip,
    String? face,
    Widget Function(String option)? icon,
    List<Widget> icons = const [],
  }) => MenuChip(
    key: key,
    label: face ?? title,
    icons: icons,
    selected: picked.isNotEmpty,
    tooltip: picked.isEmpty
        ? null
        : context.l10n.moveFilterValue(title, tooltip),
    menuChildren: [
      MenuHeader(title),
      for (final option in options)
        CheckboxMenuButton(
          value: picked.contains(option),
          closeOnActivate: false,
          onChanged: (on) =>
              setState(() => on! ? picked.add(option) : picked.remove(option)),
          child: Row(
            spacing: 12,
            children: [?icon?.call(option), Text(optionLabel(option))],
          ),
        ),
    ],
  );
}
