import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/type_chip.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/moves/domain/moves_data.dart';
import 'package:ishinydex/features/moves/moves_providers.dart';
import 'package:ishinydex/features/moves/presentation/sticky_section.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/specimen_filters.dart'
    show generationNumber;

/// A aba Golpes da ficha (#36): o que a forma aprende no jogo escolhido.
///
/// O jogo vem de [gameHint] (o save ou o OT do espécime) quando a forma tem
/// golpes nele; senão, o mais recente em que tem. Uma lista só, com um
/// cabeçalho fixo por modo de aprender (como as boxes do Faltam), e o campo
/// "Buscar golpe" filtra todas as seções. Os golpes vêm de um arquivo à
/// parte, baixado na primeira vez que a aba abre ([movesProvider]).
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
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return switch (ref.watch(movesProvider)) {
      MovesUnavailable() => _Message(l10n.movesUnavailable),
      MovesDownloading(:final received, :final total) => _Progress(
        title: l10n.movesDownloading,
        value: total == null ? null : received / total,
        detail: _megabytes(context, received, total),
      ),
      MovesPreparing() => _Progress(title: l10n.movesPreparing),
      MovesFailed(:final offline) => Column(
        children: [
          _Message(offline ? l10n.movesOffline : l10n.movesFailed),
          TextButton(
            onPressed: () => ref.read(movesProvider.notifier).retry(),
            child: Text(l10n.tryAgain),
          ),
        ],
      ),
      MovesReady(:final data) => _ready(
        data,
        ref.watch(fakeBackendProvider).catalog!,
      ),
    };
  }

  String _megabytes(BuildContext context, int received, int? total) {
    final format = NumberFormat('0.0', context.l10n.localeName);
    String mb(int bytes) => format.format(bytes / 1024 / 1024);
    return total == null
        ? context.l10n.movesDownloaded(mb(received))
        : context.l10n.movesDownloadProgress(mb(received), mb(total));
  }

  Widget _ready(MovesData data, Catalog catalog) {
    final l10n = context.l10n;
    final (pokemon, groups) = () {
      for (final id in catalog.movesPokemonIds(widget.formId)) {
        final groups = data.groupsOf(id);
        if (groups.isNotEmpty) {
          return (
            id,
            groups..sort(
              (a, b) => catalog
                  .versionGroupOrder(b)
                  .compareTo(catalog.versionGroupOrder(a)),
            ),
          );
        }
      }
      return (null, const <String>[]);
    }();
    if (pokemon == null) return _Message(l10n.movesNoneForForm);
    final hinted = switch (widget.gameHint) {
      final version? => catalog.versionGroupOf(version),
      null => null,
    };
    final group = groups.contains(_group)
        ? _group!
        : groups.contains(hinted)
        ? hinted!
        : groups.first;
    final query = foldForSearch(_search.text.trim());
    final sections = _sections(
      data.learnset(pokemon, group),
      catalog.versionGroupGeneration(group),
    );
    final found = [
      for (final section in sections)
        (
          section,
          [
            for (final row in section.rows)
              if (query.isEmpty ||
                  foldForSearch(row.learn.move.label).contains(query))
                row,
          ],
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        _GamePicker(
          catalog: catalog,
          groups: groups,
          selected: group,
          onSelected: (g) => setState(() => _group = g),
        ),
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
        if (found.every((f) => f.$2.isEmpty))
          _Message(l10n.movesNoResults(_search.text.trim()))
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Row.header(),
              for (final (section, rows) in found)
                if (rows.isNotEmpty)
                  StickySection(
                    header: _SectionHeader(
                      label: section.label(l10n),
                      count: query.isEmpty
                          ? l10n.movesCount(section.rows.length)
                          : l10n.movesFoundOf(rows.length, section.rows.length),
                    ),
                    children: [
                      for (final row in rows)
                        _Row(
                          row: row,
                          stats: row.learn.move.statsIn(
                            group,
                            catalog.versionGroupOrder,
                          ),
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
  List<_Section> _sections(List<MoveLearn> learnset, String? generation) {
    // A partir da 9ª geração, as TMs têm três dígitos (TM001).
    final digits = (generationRank(generation) ?? 0) >= 9 ? 3 : 2;
    int byLabel(_MoveRow a, _MoveRow b) =>
        a.learn.move.label.compareTo(b.learn.move.label);
    final level = <_MoveRow>[];
    final machine = <_MoveRow>[];
    final egg = <_MoveRow>[];
    final tutor = <_MoveRow>[];
    final other = <_MoveRow>[];
    for (final learn in learnset) {
      switch (learn.method) {
        case 'level-up':
          level.add(_MoveRow(learn, how: _Level(learn.level)));
        case 'machine':
          final number = learn.machineNumber;
          machine.add(
            _MoveRow(
              learn,
              how: _Text(
                number == null
                    ? learn.machineKind
                    : '${learn.machineKind}'
                          '${number.toString().padLeft(digits, '0')}',
              ),
            ),
          );
        case 'egg':
          egg.add(_MoveRow(learn));
        case 'tutor':
          tutor.add(_MoveRow(learn));
        default:
          other.add(_MoveRow(learn, method: learn.method));
      }
    }
    level.sort(
      (a, b) => switch (a.learn.level.compareTo(b.learn.level)) {
        0 => byLabel(a, b),
        final c => c,
      },
    );
    machine.sort(
      (a, b) =>
          (a.learn.machineNumber ?? 0).compareTo(b.learn.machineNumber ?? 0),
    );
    egg.sort(byLabel);
    tutor.sort(byLabel);
    other.sort(byLabel);
    return [
      _Section((l) => l.movesSectionLevel, level),
      _Section((l) => l.movesSectionMachine, machine),
      _Section((l) => l.movesSectionEgg, egg),
      _Section((l) => l.movesSectionTutor, tutor),
      _Section((l) => l.movesSectionOther, other),
    ].where((s) => s.rows.isNotEmpty).toList();
  }
}

/// A geração como número (`generation-ix` → 9); `null` se não for uma.
int? generationRank(String? generation) {
  const numerals = ['i', 'ii', 'iii', 'iv', 'v', 'vi', 'vii', 'viii', 'ix'];
  final roman = generation?.replaceFirst('generation-', '');
  final index = numerals.indexOf(roman ?? '');
  return index < 0 ? null : index + 1;
}

class _Section {
  const _Section(this.label, this.rows);

  final String Function(AppLocalizations l10n) label;
  final List<_MoveRow> rows;
}

/// A coluna "Como": o nível, a TM ou nada.
sealed class _How {
  const _How();
}

class _Level extends _How {
  const _Level(this.level);

  final int level;
}

class _Text extends _How {
  const _Text(this.text);

  final String text;
}

class _MoveRow {
  const _MoveRow(this.learn, {this.how, this.method});

  final MoveLearn learn;
  final _How? how;

  /// O modo raro ("Outros"), mostrado ao lado do tipo.
  final String? method;
}

/// O nome de um modo raro de aprender.
String moveMethodLabel(AppLocalizations l10n, String method) =>
    switch (method) {
      'light-ball-egg' => l10n.movesMethodLightBallEgg,
      'form-change' => l10n.movesMethodFormChange,
      'zygarde-cube' => l10n.movesMethodZygardeCube,
      'stadium-surfing-pikachu' => l10n.movesMethodStadium,
      'train' => l10n.movesMethodTrain,
      'xd-purification' => l10n.movesMethodPurification,
      _ => prettifyName(method),
    };

/// O ícone da categoria (físico, especial ou status), os do Pokémon HOME.
class MoveCategoryIcon extends StatelessWidget {
  const MoveCategoryIcon(this.category, {this.height = 16, super.key});

  final String category;
  final double height;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = switch (category) {
      'physical' => l10n.moveCategoryPhysical,
      'special' => l10n.moveCategorySpecial,
      _ => l10n.moveCategoryStatus,
    };
    return Tooltip(
      message: label,
      child: Image.asset(
        'assets/icons/move_${switch (category) {
          'physical' || 'special' => category,
          _ => 'status',
        }}.png',
        height: height,
        semanticLabel: label,
        errorBuilder: (_, _, _) => Text(label),
      ),
    );
  }
}

/// As colunas da lista: como, golpe, poder, precisão e PP.
class _Row extends StatelessWidget {
  const _Row({required _MoveRow this.row, required MoveStats this.stats});

  const _Row.header() : row = null, stats = null;

  final _MoveRow? row;
  final MoveStats? stats;

  static String _value(int? value) => value?.toString() ?? '—';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final muted = theme.colorScheme.onSurfaceVariant;
    final row = this.row;
    final stats = this.stats;
    final small = theme.textTheme.bodySmall?.copyWith(color: muted);
    final number = theme.textTheme.bodyMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget cell(String text, TextStyle? style) => SizedBox(
      width: 40,
      child: Text(text, textAlign: TextAlign.end, style: style),
    );
    final children = row == null || stats == null
        ? [
            SizedBox(width: 52, child: Text(l10n.movesColumnHow, style: small)),
            Expanded(child: Text(l10n.movesColumnMove, style: small)),
            cell(l10n.movesColumnPower, small),
            cell(l10n.movesColumnAccuracy, small),
            SizedBox(
              width: 28,
              child: Text('PP', textAlign: TextAlign.end, style: small),
            ),
          ]
        : [
            SizedBox(
              width: 52,
              child: Text(switch (row.how) {
                _Level(:final level) => l10n.evolutionLevel(level),
                _Text(:final text) => text,
                null => '',
              }, style: small),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Text(
                      row.learn.move.label,
                      style: theme.textTheme.bodyLarge,
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TypeChip(stats.type, small: true),
                        MoveCategoryIcon(row.learn.move.category),
                        if (row.method case final method?)
                          Text(moveMethodLabel(l10n, method), style: small),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            cell(_value(stats.power), number),
            cell(_value(stats.accuracy), number),
            SizedBox(
              width: 28,
              child: Text(
                '${stats.pp}',
                textAlign: TextAlign.end,
                style: number,
              ),
            ),
          ];
    return Container(
      constraints: BoxConstraints(minHeight: row == null ? 0 : 56),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: row == null
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
      child: Row(spacing: 8, children: children),
    );
  }
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

/// O jogo escolhido; tocar abre a lista, agrupada por geração.
class _GamePicker extends StatelessWidget {
  const _GamePicker({
    required this.catalog,
    required this.groups,
    required this.selected,
    required this.onSelected,
  });

  final Catalog catalog;
  final List<String> groups;
  final String selected;
  final ValueChanged<String> onSelected;

  String _label(String group) => switch (catalog.versionsOfGroup(group)) {
    final versions when versions.isEmpty || group.startsWith('the-') =>
      prettifyName(group),
    final versions => versions.map(versionLabel).join(' / '),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return InkWell(
      key: const ValueKey('moves-game'),
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (context) => _GameSheet(
            groups: groups,
            selected: selected,
            label: _label,
            generationOf: catalog.versionGroupGeneration,
          ),
        );
        if (picked != null) onSelected(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.movesGame,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(_label(selected), style: theme.textTheme.bodyLarge),
      ),
    );
  }
}

class _GameSheet extends StatelessWidget {
  const _GameSheet({
    required this.groups,
    required this.selected,
    required this.label,
    required this.generationOf,
  });

  final List<String> groups;
  final String selected;
  final String Function(String group) label;
  final String? Function(String group) generationOf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // O cabeçalho da geração antes do primeiro jogo dela.
    final headers = <String, String>{};
    for (final group in groups) {
      if (generationOf(group) case final generation?
          when !headers.containsValue(generation)) {
        headers[group] = generation;
      }
    }
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final group in groups) ...[
            if (headers[group] case final generation?)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  context.l10n
                      .generationNumber(generationNumber(generation))
                      .toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ListTile(
              title: Text(label(group)),
              selected: group == selected,
              trailing: group == selected ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, group),
            ),
          ],
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium,
    ),
  );
}

/// O download ou a leitura dos golpes: a mensagem e a barra (indeterminada
/// sem [value]).
class _Progress extends StatelessWidget {
  const _Progress({required this.title, this.value, this.detail});

  final String title;
  final double? value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        spacing: 8,
        children: [
          Text(title, style: theme.textTheme.bodyMedium),
          LinearProgressIndicator(value: value),
          if (detail case final detail?)
            Text(
              detail,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
  }
}
