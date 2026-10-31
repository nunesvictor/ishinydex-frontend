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
import 'package:ishinydex/features/specimens/presentation/widgets/specimen_filters.dart'
    show generationNumber;

/// Os golpes prontos ou o estado do download (#36): baixando, com a barra e
/// os MB; preparando; sem internet ou com erro, com o "Tentar novamente";
/// ou sem o arquivo. Pronto, o [builder] recebe os golpes e o catálogo.
class MovesGate extends ConsumerWidget {
  const MovesGate({required this.builder, super.key});

  final Widget Function(MovesData data, Catalog catalog) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return switch (ref.watch(movesProvider)) {
      MovesUnavailable() => MovesMessage(l10n.movesUnavailable),
      MovesDownloading(:final received, :final total) => _Progress(
        title: l10n.movesDownloading,
        value: total == null ? null : received / total,
        detail: _megabytes(context, received, total),
      ),
      MovesPreparing() => _Progress(title: l10n.movesPreparing),
      MovesFailed(:final offline) => Column(
        children: [
          MovesMessage(offline ? l10n.movesOffline : l10n.movesFailed),
          TextButton(
            onPressed: () => ref.read(movesProvider.notifier).retry(),
            child: Text(l10n.tryAgain),
          ),
        ],
      ),
      MovesReady(:final data) => builder(
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
}

class MovesMessage extends StatelessWidget {
  const MovesMessage(this.text, {super.key});

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

/// O que a forma [formId] aprende no jogo [group], pelo primeiro Pokémon
/// dela que tem golpes ali: golpe (o índice) → como.
Map<int, List<MoveLearn>> formLearnset(
  MovesData data,
  Catalog catalog,
  int formId,
  String group,
) {
  final learned = <int, List<MoveLearn>>{};
  for (final pokemon in catalog.movesPokemonIds(formId)) {
    final learnset = data.learnset(pokemon, group);
    if (learnset.isEmpty) continue;
    for (final learn in learnset) {
      (learned[learn.move.index] ??= []).add(learn);
    }
    break;
  }
  return learned;
}

/// Os grupos de versões, do mais novo ao mais antigo.
List<String> newestFirst(Iterable<String> groups, Catalog catalog) =>
    groups.toList()..sort(
      (a, b) =>
          catalog.versionGroupOrder(b).compareTo(catalog.versionGroupOrder(a)),
    );

/// O aviso dos jogos sem o poder, a precisão e o PP dos golpes no catálogo
/// (o Legends: Z-A); nos outros, nada.
class MovesNoValuesNote extends StatelessWidget {
  const MovesNoValuesNote(this.group, {super.key});

  final String group;

  @override
  Widget build(BuildContext context) {
    if (!groupsWithoutMoveValues.contains(group)) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Icon(Icons.info_outline, size: 18, color: muted),
        Expanded(
          child: Text(
            context.l10n.movesNoValues,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ),
      ],
    );
  }
}

/// O nome de um jogo: as versões do grupo ("Scarlet / Violet"); nas DLCs e
/// fora do catálogo, o nome do grupo ("The Teal Mask").
String gameLabel(Catalog catalog, String group) =>
    switch (catalog.versionsOfGroup(group)) {
      final versions when versions.isEmpty || group.startsWith('the-') =>
        prettifyName(group),
      final versions => versions.map(versionLabel).join(' / '),
    };

/// O jogo escolhido; tocar abre a lista, agrupada por geração.
class GamePicker extends StatelessWidget {
  const GamePicker({
    required this.catalog,
    required this.groups,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final Catalog catalog;
  final List<String> groups;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      key: const ValueKey('moves-game'),
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
        final picked = await showGameSheet(
          context,
          catalog: catalog,
          groups: groups,
          selected: selected,
        );
        if (picked != null) onSelected(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: context.l10n.movesGame,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          gameLabel(catalog, selected),
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// A lista dos jogos, agrupada por geração; devolve o escolhido.
Future<String?> showGameSheet(
  BuildContext context, {
  required Catalog catalog,
  required List<String> groups,
  required String selected,
}) => showModalBottomSheet<String>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) {
    final theme = Theme.of(context);
    // O cabeçalho da geração antes do primeiro jogo dela.
    final headers = <String, String>{};
    for (final group in groups) {
      if (catalog.versionGroupGeneration(group) case final generation?
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
              title: Text(gameLabel(catalog, group)),
              selected: group == selected,
              trailing: group == selected ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, group),
            ),
          ],
        ],
      ),
    );
  },
);

/// A geração como número (`generation-ix` → 9); `null` se não for uma.
int? generationRank(String? generation) {
  const numerals = ['i', 'ii', 'iii', 'iv', 'v', 'vi', 'vii', 'viii', 'ix'];
  final roman = generation?.replaceFirst('generation-', '');
  final index = numerals.indexOf(roman ?? '');
  return index < 0 ? null : index + 1;
}

/// A TM de um golpe ("TM071"): a partir da 9ª geração, com três dígitos.
String machineLabel(MoveLearn learn, String? generation) {
  final digits = (generationRank(generation) ?? 0) >= 9 ? 3 : 2;
  return switch (learn.machineNumber) {
    final number? =>
      '${learn.machineKind}${number.toString().padLeft(digits, '0')}',
    null => learn.machineKind,
  };
}

/// Como um Pokémon aprende um golpe, em poucas palavras ("Nv. 30 ·
/// TM125"): os modos na ordem nível, TM, ovo, tutor e os raros.
String learnHow(
  AppLocalizations l10n,
  List<MoveLearn> learns,
  String? generation,
) {
  int rank(String method) => switch (method) {
    'level-up' => 0,
    'machine' => 1,
    'egg' => 2,
    'tutor' => 3,
    _ => 4,
  };
  final sorted = [...learns]
    ..sort((a, b) => rank(a.method).compareTo(rank(b.method)));
  return {
    for (final learn in sorted)
      switch (learn.method) {
        'level-up' => l10n.evolutionLevel(learn.level),
        'machine' => machineLabel(learn, generation),
        'egg' => l10n.movesSectionEgg,
        'tutor' => l10n.movesSectionTutor,
        final method => moveMethodLabel(l10n, method),
      },
  }.join(' · ');
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

/// O nome da categoria: físico, especial ou status.
String moveCategoryLabel(AppLocalizations l10n, String category) =>
    switch (category) {
      'physical' => l10n.moveCategoryPhysical,
      'special' => l10n.moveCategorySpecial,
      _ => l10n.moveCategoryStatus,
    };

/// O ícone da categoria (físico, especial ou status), os do Pokémon HOME.
class MoveCategoryIcon extends StatelessWidget {
  const MoveCategoryIcon(this.category, {this.height = 16, super.key});

  final String category;
  final double height;

  @override
  Widget build(BuildContext context) {
    final label = moveCategoryLabel(context.l10n, category);
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

/// Uma linha de golpe, como no mock: a coluna "Como" ([how], na aba
/// Golpes), o nome com o tipo, o ícone da categoria e o [detail], e poder /
/// precisão / PP do jogo. Sem [move], o cabeçalho das colunas.
class MoveRow extends StatelessWidget {
  const MoveRow({
    required MoveInfo this.move,
    required MoveStats this.stats,
    this.how,
    this.showHow = false,
    this.detail,
    this.footer,
    this.onTap,
    super.key,
  });

  const MoveRow.header({this.showHow = false, super.key})
    : move = null,
      stats = null,
      how = null,
      detail = null,
      footer = null,
      onTap = null;

  final MoveInfo? move;
  final MoveStats? stats;

  /// A coluna "Como" (o nível ou a TM); só com [showHow].
  final String? how;
  final bool showHow;

  /// Ao lado do tipo: o modo raro, ou como a forma aprende (na busca).
  final String? detail;

  /// Embaixo do tipo: como cada forma aprende, na busca com várias (#373).
  final Widget? footer;
  final VoidCallback? onTap;

  static String _value(int? value) => value?.toString() ?? '—';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final muted = theme.colorScheme.onSurfaceVariant;
    final move = this.move;
    final stats = this.stats;
    final small = theme.textTheme.bodySmall?.copyWith(color: muted);
    final number = theme.textTheme.bodyMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget cell(String text, TextStyle? style, {double width = 40}) => SizedBox(
      width: width,
      child: Text(text, textAlign: TextAlign.end, style: style),
    );
    final children = move == null || stats == null
        ? [
            if (showHow)
              SizedBox(
                width: 52,
                child: Text(l10n.movesColumnHow, style: small),
              ),
            Expanded(child: Text(l10n.movesColumnMove, style: small)),
            cell(l10n.movesColumnPower, small),
            cell(l10n.movesColumnAccuracy, small),
            cell('PP', small, width: 28),
          ]
        : [
            if (showHow)
              SizedBox(width: 52, child: Text(how ?? '', style: small)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Text(move.label, style: theme.textTheme.bodyLarge),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TypeChip(stats.type, small: true),
                        MoveCategoryIcon(move.category),
                        if (detail case final detail?)
                          Text(detail, style: small),
                      ],
                    ),
                    ?footer,
                  ],
                ),
              ),
            ),
            cell(_value(stats.power), number),
            cell(_value(stats.accuracy), number),
            cell(_value(stats.pp), number, width: 28),
          ];
    final row = Container(
      constraints: BoxConstraints(minHeight: move == null ? 0 : 56),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: move == null
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
      child: Row(spacing: 8, children: children),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}
