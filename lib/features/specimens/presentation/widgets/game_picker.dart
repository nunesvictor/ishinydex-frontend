import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/responsive/breakpoints.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/game_icon.dart';
import 'package:ishinydex/core/widgets/search_field.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/specimen_filters.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Uma seção da folha Jogo: os jogos de onde escolher e os já marcados.
class GamePickerSection {
  const GamePickerSection({
    required this.title,
    required this.versions,
    required this.selected,
    this.hint,
    this.saves = const {},
    this.count,
  });

  final String title;

  /// O que a seção filtra, abaixo do título.
  final String? hint;

  /// Os jogos, já na ordem da série.
  final List<String> versions;
  final List<String> selected;

  /// Quantos saves há de cada jogo: com mais de um, a linha diz "N saves".
  final Map<String, int> saves;

  /// O número à direita de cada jogo (quantos resultados ele daria).
  final Widget Function(String version)? count;
}

/// A folha "Jogo" (#205, #201): no celular, uma folha de baixo; no PC, um
/// diálogo. Em cima a busca, no meio os jogos (por geração, na ordem da
/// série), embaixo o botão fixo. Só o meio rola: com 2 ou 40 jogos, a busca
/// e o botão ficam à vista. Com mais de uma seção, cada uma é recolhível:
/// abre fechada, a não ser que tenha jogo marcado, e a busca abre todas.
///
/// Devolve os jogos marcados de cada seção (vazio = todos) ou `null` se
/// fechou sem aplicar. [applyLabel] escreve o botão com o rascunho.
Future<List<List<String>>?> showGamePicker(
  BuildContext context, {
  required List<GamePickerSection> sections,
  required String Function(WidgetRef ref, List<List<String>> draft) applyLabel,
  String? subtitle,
}) {
  final panel = GamePicker(
    sections: sections,
    applyLabel: applyLabel,
    subtitle: subtitle,
  );
  if (WindowSize.of(context).isCompact) {
    return showModalBottomSheet<List<List<String>>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: panel,
      ),
    );
  }
  return showDialog<List<List<String>>>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
        child: panel,
      ),
    ),
  );
}

class GamePicker extends ConsumerStatefulWidget {
  const GamePicker({
    required this.sections,
    required this.applyLabel,
    this.subtitle,
    super.key,
  });

  final List<GamePickerSection> sections;
  final String Function(WidgetRef ref, List<List<String>> draft) applyLabel;
  final String? subtitle;

  @override
  ConsumerState<GamePicker> createState() => _GamePickerState();
}

class _GamePickerState extends ConsumerState<GamePicker> {
  /// Com poucos jogos a busca só ocuparia espaço (como nos filtros).
  static const _searchFrom = 8;

  late final List<Set<String>> _draft = [
    for (final s in widget.sections) <String>{...s.selected},
  ];

  /// Seções abertas: as que já têm jogo marcado.
  late final List<bool> _open = [
    for (final s in widget.sections) s.selected.isNotEmpty,
  ];
  String _search = '';

  bool get _collapsible => widget.sections.length > 1;

  List<List<String>> get _result => [
    for (final (i, s) in widget.sections.indexed)
      [
        for (final v in s.versions)
          if (_draft[i].contains(v)) v,
      ],
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final search = foldForSearch(_search.trim());
    final total = widget.sections.fold(0, (n, s) => n + s.versions.length);
    final rows = <Widget>[
      if (search.isEmpty)
        CheckboxListTile(
          value: _draft.every((d) => d.isEmpty),
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Todos os jogos'),
          onChanged: (_) => setState(() {
            for (final d in _draft) {
              d.clear();
            }
          }),
        ),
      for (final (i, section) in widget.sections.indexed)
        ..._section(theme, i, section, search),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Jogo', style: theme.textTheme.titleLarge),
              if (widget.subtitle case final subtitle?)
                Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        if (total >= _searchFrom)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: SearchField(
              hintText: 'Buscar jogo',
              dense: true,
              onChanged: (text) => setState(() => _search = text),
            ),
          ),
        const Divider(height: 1),
        Expanded(child: ListView(children: rows)),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(_result),
            child: Text(widget.applyLabel(ref, _result)),
          ),
        ),
      ],
    );
  }

  List<Widget> _section(
    ThemeData theme,
    int i,
    GamePickerSection section,
    String search,
  ) {
    final generationOf = ref.watch(versionGenerationProvider);
    final versions = [
      for (final v in section.versions)
        if (foldForSearch(versionLabel(v)).contains(search)) v,
    ];
    final open = !_collapsible || search.isNotEmpty || _open[i];
    final marked = _draft[i].length;
    return [
      if (_collapsible)
        ListTile(
          key: ValueKey('game-section-$i'),
          title: Text(section.title),
          subtitle: Text(
            [?section.hint, '${section.versions.length} jogos'].join(' · '),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              if (marked > 0)
                Badge(
                  label: Text(marked == 1 ? '1 marcado' : '$marked marcados'),
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  textColor: theme.colorScheme.onSecondaryContainer,
                ),
              Icon(open ? Icons.expand_less : Icons.expand_more),
            ],
          ),
          // Durante a busca, as seções ficam abertas.
          onTap: search.isNotEmpty
              ? null
              : () => setState(() => _open[i] = !_open[i]),
        ),
      if (open) ...[
        for (final (j, version) in versions.indexed) ...[
          if (j == 0 || generationOf[version] != generationOf[versions[j - 1]])
            if (generationOf[version] case final generation?)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
                child: Text(
                  'Geração ${generationNumber(generation)}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          CheckboxListTile(
            dense: true,
            value: _draft[i].contains(version),
            controlAffinity: ListTileControlAffinity.leading,
            title: Row(
              spacing: 12,
              children: [
                GameIcon(version),
                Flexible(child: Text(versionLabel(version))),
                if ((section.saves[version] ?? 0) > 1)
                  Text(
                    '${section.saves[version]} saves',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
            secondary: section.count?.call(version),
            onChanged: (on) => setState(
              () => on! ? _draft[i].add(version) : _draft[i].remove(version),
            ),
          ),
        ],
        if (versions.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _collapsible
                  ? 'Nenhum jogo com esse nome nesta seção.'
                  : 'Nenhum jogo com esse nome.',
            ),
          ),
      ],
    ];
  }
}
