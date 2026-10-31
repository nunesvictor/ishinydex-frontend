import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/responsive/breakpoints.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/core/widgets/search_field.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/moves/domain/moves_data.dart';
import 'package:ishinydex/features/moves/presentation/moves_widgets.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';

/// Tela cheia no compacto, diálogo nos demais (como o seletor de formas).
Future<T?> _showPicker<T>(BuildContext context, Widget picker) => showDialog<T>(
  context: context,
  builder: (context) => WindowSize.of(context).isCompact
      ? Dialog.fullscreen(child: picker)
      : Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
            child: picker,
          ),
        ),
);

/// A escolha num seletor que também pode tirar o valor: `null` = fechou;
/// `value` `null` = tirou.
typedef PickResult = ({String? value});

/// Escolhe o golpe de um slot entre os que a forma aprende no jogo
/// ([learned]: golpe → como), menos os dos outros slots ([taken]).
Future<PickResult?> showMovePicker(
  BuildContext context, {
  required String title,
  required String countText,
  required Map<int, List<MoveLearn>> learned,
  required Set<String> taken,
  required String group,
  required Catalog catalog,
  MoveInfo? current,
}) => _showPicker(
  context,
  _MovePicker(
    title: title,
    countText: countText,
    learned: learned,
    taken: taken,
    group: group,
    catalog: catalog,
    current: current,
  ),
);

class _MovePicker extends StatefulWidget {
  const _MovePicker({
    required this.title,
    required this.countText,
    required this.learned,
    required this.taken,
    required this.group,
    required this.catalog,
    this.current,
  });

  final String title;
  final String countText;
  final Map<int, List<MoveLearn>> learned;
  final Set<String> taken;
  final String group;
  final Catalog catalog;
  final MoveInfo? current;

  @override
  State<_MovePicker> createState() => _MovePickerState();
}

class _MovePickerState extends State<_MovePicker> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final query = foldForSearch(_search.trim());
    final generation = widget.catalog.versionGroupGeneration(widget.group);
    final rows = [
      for (final learns in widget.learned.values)
        if (!widget.taken.contains(learns.first.move.name) &&
            (query.isEmpty ||
                foldForSearch(learns.first.move.label).contains(query)))
          learns,
    ]..sort((a, b) => a.first.move.label.compareTo(b.first.move.label));
    final current = widget.current;
    return _PickerFrame(
      title: widget.title,
      hint: l10n.memberMoveSearch,
      onSearch: (text) => setState(() => _search = text),
      count: widget.countText,
      children: [
        if (current != null)
          Card.filled(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: ListTile(
              title: Text(
                l10n.memberCurrentMove,
                style: theme.textTheme.bodySmall,
              ),
              subtitle: Text(current.label, style: theme.textTheme.bodyLarge),
              trailing: TextButton(
                key: const ValueKey('move-clear'),
                onPressed: () => Navigator.of(context).pop((value: null)),
                child: Text(l10n.memberClearMove),
              ),
            ),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: MoveRow.header(),
        ),
        for (final learns in rows)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: MoveRow(
              key: ValueKey('pick-${learns.first.move.name}'),
              move: learns.first.move,
              stats: learns.first.move.statsIn(
                widget.group,
                widget.catalog.versionGroupOrder,
              ),
              detail: learnHow(l10n, learns, generation),
              onTap: () =>
                  Navigator.of(context).pop((value: learns.first.move.name)),
            ),
          ),
      ],
    );
  }
}

/// Escolhe o item segurado entre os do jogo, ou "Sem item".
Future<PickResult?> showItemPicker(
  BuildContext context, {
  required List<HeldItem> items,
  required String countText,
  String? current,
}) => _showPicker(
  context,
  _ItemPicker(items: items, countText: countText, current: current),
);

class _ItemPicker extends StatefulWidget {
  const _ItemPicker({
    required this.items,
    required this.countText,
    this.current,
  });

  final List<HeldItem> items;
  final String countText;
  final String? current;

  @override
  State<_ItemPicker> createState() => _ItemPickerState();
}

class _ItemPickerState extends State<_ItemPicker> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final query = foldForSearch(_search.trim());
    Widget tile({
      required Key key,
      required Widget leading,
      required String label,
      required String? value,
    }) {
      final selected = value == widget.current;
      return ListTile(
        key: key,
        leading: SizedBox.square(dimension: 32, child: Center(child: leading)),
        title: Text(label),
        selected: selected,
        trailing: selected
            ? Icon(Icons.check, semanticLabel: l10n.memberSelected)
            : null,
        onTap: () => Navigator.of(context).pop((value: value)),
      );
    }

    return _PickerFrame(
      title: l10n.memberItem,
      hint: l10n.memberItemSearch,
      onSearch: (text) => setState(() => _search = text),
      count: widget.countText,
      children: [
        if (query.isEmpty)
          tile(
            key: const ValueKey('item-none'),
            leading: const Icon(Icons.block),
            label: l10n.memberNoItem,
            value: null,
          ),
        for (final item in widget.items)
          if (query.isEmpty || foldForSearch(item.label).contains(query))
            tile(
              key: ValueKey('item-${item.name}'),
              leading: PokemonSprite(url: item.spriteUrl, size: 32),
              label: item.label,
              value: item.name,
            ),
      ],
    );
  }
}

/// O cabeçalho dos seletores: fechar, título, busca e a contagem.
class _PickerFrame extends StatelessWidget {
  const _PickerFrame({
    required this.title,
    required this.hint,
    required this.onSearch,
    required this.count,
    required this.children,
  });

  final String title;
  final String hint;
  final ValueChanged<String> onSearch;
  final String count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
          child: Row(
            children: [
              const CloseButton(),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SearchField(hintText: hint, onChanged: onSearch),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            count,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: ListView(children: children)),
      ],
    );
  }
}

/// Um número de [min] a [max] (o nível, um IV); `null` se cancelar.
Future<int?> showNumberDialog(
  BuildContext context, {
  required String title,
  required String hint,
  required int initial,
  required int min,
  required int max,
}) => showDialog<int>(
  context: context,
  builder: (context) => _NumberDialog(
    title: title,
    hint: hint,
    initial: initial,
    min: min,
    max: max,
  ),
);

class _NumberDialog extends StatefulWidget {
  const _NumberDialog({
    required this.title,
    required this.hint,
    required this.initial,
    required this.min,
    required this.max,
  });

  final String title;
  final String hint;
  final int initial;
  final int min;
  final int max;

  @override
  State<_NumberDialog> createState() => _NumberDialogState();
}

class _NumberDialogState extends State<_NumberDialog> {
  late final _text = TextEditingController(text: '${widget.initial}');

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  int? get _value => switch (int.tryParse(_text.text)) {
    final value? when value >= widget.min && value <= widget.max => value,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final value = _value;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('number-field'),
        controller: _text,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          helperText: widget.hint,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) {
          // O texto de agora, não o do último quadro.
          if (_value case final value?) Navigator.of(context).pop(value);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('number-ok'),
          onPressed: value == null
              ? null
              : () => Navigator.of(context).pop(value),
          child: Text(l10n.ok),
        ),
      ],
    );
  }
}

/// Escolhe um espécime do inventário (os da forma do membro).
Future<Specimen?> showSpecimenPicker(
  BuildContext context, {
  required List<Specimen> specimens,
}) => showModalBottomSheet<Specimen>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) {
    final l10n = context.l10n;
    return SafeArea(
      child: specimens.isEmpty
          ? Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Text(l10n.memberNoSpecimens, textAlign: TextAlign.center),
            )
          : ListView(
              shrinkWrap: true,
              children: [
                for (final s in specimens)
                  ListTile(
                    key: ValueKey('link-${s.id}'),
                    leading: PokemonSprite(url: s.spriteUrl, size: 40),
                    title: Text(s.displayName),
                    subtitle: Text(
                      [
                        ?s.nature.map(prettifyName),
                        ?s.ability.map(prettifyName),
                      ].join(' · '),
                    ),
                    onTap: () => Navigator.of(context).pop(s),
                  ),
              ],
            ),
    );
  },
);

extension on String? {
  String? map(String Function(String) f) => switch (this) {
    final value? => f(value),
    null => null,
  };
}
