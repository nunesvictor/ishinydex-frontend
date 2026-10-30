import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/moves/domain/moves_data.dart';
import 'package:ishinydex/features/moves/presentation/move_page.dart';
import 'package:ishinydex/features/moves/presentation/move_search_page.dart';
import 'package:ishinydex/features/moves/presentation/moves_widgets.dart';
import 'package:ishinydex/features/moves/presentation/sticky_section.dart';

/// A aba Golpes da ficha (#36): o que a forma aprende no jogo escolhido.
///
/// O jogo vem de [gameHint] (o save ou o OT do espécime) quando a forma tem
/// golpes nele; senão, o mais recente em que tem. Uma lista só, com um
/// cabeçalho fixo por modo de aprender (como as boxes do Faltam), e o campo
/// "Buscar golpe" filtra todas as seções. Ao lado dele, "Filtros" abre a
/// busca completa com o jogo e a forma (#369); tocar num golpe abre o golpe.
/// Os golpes vêm de um arquivo à parte, baixado na primeira vez que a aba
/// abre ([MovesGate]).
class MovesTab extends ConsumerStatefulWidget {
  const MovesTab({required this.formId, this.gameHint, super.key});

  final int formId;

  /// A versão do jogo do espécime (`scarlet`); `null` sem espécime.
  final String? gameHint;

  @override
  ConsumerState<MovesTab> createState() => _MovesTabState();
}

class _MovesTabState extends ConsumerState<MovesTab> {
  String? _group;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MovesGate(builder: _ready);

  Widget _ready(MovesData data, Catalog catalog) {
    final l10n = context.l10n;
    final (pokemon, groups) = () {
      for (final id in catalog.movesPokemonIds(widget.formId)) {
        final groups = data.groupsOf(id);
        if (groups.isNotEmpty) return (id, newestFirst(groups, catalog));
      }
      return (null, const <String>[]);
    }();
    if (pokemon == null) return MovesMessage(l10n.movesNoneForForm);
    final hinted = switch (widget.gameHint) {
      final version? => catalog.versionGroupOf(version),
      null => null,
    };
    final group = groups.contains(_group)
        ? _group!
        : groups.contains(hinted)
        ? hinted!
        : groups.first;
    final generation = catalog.versionGroupGeneration(group);
    final query = foldForSearch(_search.text.trim());
    final found = [
      for (final section in _sections(data.learnset(pokemon, group)))
        (
          section,
          [
            for (final learn in section.learns)
              if (query.isEmpty ||
                  foldForSearch(learn.move.label).contains(query))
                learn,
          ],
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        GamePicker(
          catalog: catalog,
          groups: groups,
          selected: group,
          onSelected: (g) => setState(() => _group = g),
        ),
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: TextField(
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
            ),
            // A busca completa (#369), com o jogo, a forma e o texto.
            OutlinedButton.icon(
              onPressed: () => openMoveSearch(
                context,
                group: group,
                formId: widget.formId,
                query: _search.text.trim(),
              ),
              icon: const Icon(Icons.tune),
              label: Text(l10n.movesFilters),
            ),
          ],
        ),
        if (found.every((f) => f.$2.isEmpty))
          MovesMessage(l10n.movesNoResults(_search.text.trim()))
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MoveRow.header(showHow: true),
              for (final (section, learns) in found)
                if (learns.isNotEmpty)
                  StickySection(
                    header: _SectionHeader(
                      label: section.label(l10n),
                      count: query.isEmpty
                          ? l10n.movesCount(section.learns.length)
                          : l10n.movesFoundOf(
                              learns.length,
                              section.learns.length,
                            ),
                    ),
                    children: [
                      for (final learn in learns)
                        MoveRow(
                          move: learn.move,
                          stats: learn.move.statsIn(
                            group,
                            catalog.versionGroupOrder,
                          ),
                          showHow: true,
                          how: switch (learn.method) {
                            'level-up' => l10n.evolutionLevel(learn.level),
                            'machine' => machineLabel(learn, generation),
                            _ => null,
                          },
                          detail: section.other
                              ? moveMethodLabel(l10n, learn.method)
                              : null,
                          onTap: () => openMove(context, learn.move, group),
                        ),
                    ],
                  ),
            ],
          ),
      ],
    );
  }

  /// As seções por modo de aprender: nível (pelo nível), TM (pelo número),
  /// ovo, tutor e os raros em "Outros" (pelo nome). Só as que existem no
  /// jogo.
  List<_Section> _sections(List<MoveLearn> learnset) {
    int byLabel(MoveLearn a, MoveLearn b) =>
        a.move.label.compareTo(b.move.label);
    List<MoveLearn> of(bool Function(String method) test) => [
      for (final learn in learnset)
        if (test(learn.method)) learn,
    ];
    const main = {'level-up', 'machine', 'egg', 'tutor'};
    return [
      _Section(
        (l) => l.movesSectionLevel,
        of((m) => m == 'level-up')..sort(
          (a, b) => switch (a.level.compareTo(b.level)) {
            0 => byLabel(a, b),
            final c => c,
          },
        ),
      ),
      _Section(
        (l) => l.movesSectionMachine,
        of((m) => m == 'machine')..sort(
          (a, b) => (a.machineNumber ?? 0).compareTo(b.machineNumber ?? 0),
        ),
      ),
      _Section((l) => l.movesSectionEgg, of((m) => m == 'egg')..sort(byLabel)),
      _Section(
        (l) => l.movesSectionTutor,
        of((m) => m == 'tutor')..sort(byLabel),
      ),
      _Section(
        (l) => l.movesSectionOther,
        of((m) => !main.contains(m))..sort(byLabel),
        other: true,
      ),
    ].where((s) => s.learns.isNotEmpty).toList();
  }
}

class _Section {
  const _Section(this.label, this.learns, {this.other = false});

  final String Function(AppLocalizations l10n) label;
  final List<MoveLearn> learns;

  /// "Outros": o modo de cada golpe aparece ao lado do tipo.
  final bool other;
}

/// O cabeçalho de uma seção: o modo e quantos golpes ("Por nível · 15
/// golpes").
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});

  final String label;
  final String count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          spacing: 8,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Flexible(
              child: Text(
                count,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
