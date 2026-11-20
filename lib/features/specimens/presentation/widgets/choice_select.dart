import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/responsive/breakpoints.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/nature_colors.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_labels.dart';
import 'package:material_ui/material_ui.dart';

/// Select de [Choice]s sobre o `DropdownMenu` do Material 3.
///
/// - Desktop: o campo aceita digitação e filtra as opções, ignorando
///   maiúsculas e acentos ("poke" encontra "Poké Ball"); Enter escolhe a
///   opção destacada.
/// - Mobile: só toque, para o teclado virtual não cobrir a lista. Listas
///   longas (mais de [sheetThreshold] opções, ou com [action]) abrem uma
///   folha de baixo com a busca no topo (#409): o teclado só sobe quando a
///   pessoa toca na busca, e a lista encolhe acima dele.
/// - Quando alguma opção tem `spriteUrl` (pokébolas), o sprite aparece em
///   cada item e à esquerda do campo, como o select2 do admin.
///
/// - Naturezas (opções com `increased`/`decreased`, #410): o efeito vem
///   junto do nome, no campo e em cada item ("Careful ↑ Def. Esp. ↓ Atq.
///   Esp.", com ↑ vermelho e ↓ azul; as neutras dizem "(neutra)"). Por
///   estar no rótulo, a busca também acha pelo atributo, com as que sobem
///   antes das que descem.
///
/// O primeiro item ("—") limpa a seleção e devolve `null` em [onChanged].
class ChoiceSelect extends StatefulWidget {
  const ChoiceSelect({
    required this.label,
    required this.choices,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.trailingOf,
    this.leadingOf,
    this.action,
    super.key,
  });

  /// Acima disso, no celular, a lista abre na folha com busca (#409):
  /// natureza (25), pokébola (36), idioma (14), jogos.
  static const sheetThreshold = 10;

  final String label;
  final List<Choice> choices;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? errorText;

  /// Um ícone à direita de cada opção, como o Shiny Charm do save (#317).
  final Widget? Function(Choice choice)? trailingOf;

  /// Um ícone à esquerda de cada opção e do campo, como a marca de origem
  /// (#360); no lugar do sprite.
  final Widget? Function(Choice choice)? leadingOf;

  /// Uma ação no fim da folha do celular, sempre visível, mesmo filtrando:
  /// "Novo treinador…" (#409).
  final ChoiceAction? action;

  @override
  State<ChoiceSelect> createState() => _ChoiceSelectState();
}

/// Uma ação no fim da folha de opções: o texto, o ícone e o que fazer (a
/// folha fecha antes).
typedef ChoiceAction = ({String label, IconData icon, VoidCallback onPressed});

class _ChoiceSelectState extends State<ChoiceSelect> {
  /// Valor interno do item "—"; o `DropdownMenu` não aceita entrada `null`.
  static const _none = '';

  /// O texto do campo, que pinta o efeito da natureza escolhida.
  final _controller = _EffectController();

  /// No PC, focar o campo seleciona o texto todo: digitar substitui o "—"
  /// ou a opção escolhida, em vez de buscar por "—velo".
  late final _focus = FocusNode()..addListener(_selectAllOnFocus);

  void _selectAllOnFocus() {
    if (!_focus.hasFocus) return;
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final desktop = isDesktopPlatform(Theme.of(context).platform);
    // As opções do catálogo no idioma da tela.
    final natures = widget.choices.any((c) => c.increased != null);
    final choices = [
      for (final c in l10n.choicesIn(widget.choices))
        if (natures) c.copyWith(label: _withEffect(l10n, c)) else c,
    ];
    _controller.natures = natures ? l10n.natureNeutralTag : null;
    final withSprites = choices.any((c) => c.spriteUrl != null);
    final selected = choices.where((c) => c.value == widget.value).firstOrNull;
    final leadingOf = widget.leadingOf;
    final trailingOf = widget.trailingOf;
    final leading = withSprites
        ? _sprite(selected?.spriteUrl)
        : selected == null
        ? null
        : leadingOf?.call(selected);
    if (!desktop &&
        (choices.length > ChoiceSelect.sheetThreshold ||
            widget.action != null)) {
      final text = selected?.label ?? '—';
      if (_controller.text != text) _controller.text = text;
      return TextField(
        controller: _controller,
        readOnly: true,
        // Só toque: o campo nunca recebe o foco (nem abre o teclado).
        canRequestFocus: false,
        onTap: () =>
            _openSheet(choices, natures: natures, sprites: withSprites),
        decoration: InputDecoration(
          labelText: widget.label,
          errorText: widget.errorText,
          errorMaxLines: 3,
          prefixIcon: leading,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
      );
    }
    return DropdownMenu<String>(
      controller: _controller,
      // Só no PC: com um focusNode, o DropdownMenu ignora o
      // requestFocusOnTap e o celular abriria o teclado.
      focusNode: desktop ? _focus : null,
      initialSelection: selected?.value ?? _none,
      label: Text(widget.label),
      errorText: widget.errorText,
      // O erro pode explicar o porquê em duas linhas (#408), sem cortar.
      inputDecorationTheme: Theme.of(context).inputDecorationTheme
          .copyWith(errorMaxLines: 3),
      expandedInsets: EdgeInsets.zero,
      menuHeight: 320,
      requestFocusOnTap: desktop,
      enableFilter: desktop,
      filterCallback: !desktop
          ? null
          : natures
          ? (entries, text) => _filter(entries, text, l10n.natureNeutralTag)
          : _filter,
      searchCallback: _search,
      leadingIcon: leading,
      dropdownMenuEntries: [
        const DropdownMenuEntry(value: _none, label: '—'),
        for (final c in choices)
          DropdownMenuEntry(
            value: c.value,
            label: c.label,
            labelWidget: natures
                ? _NatureEntry(_EffectParts.of(c.label, l10n.natureNeutralTag))
                : null,
            leadingIcon: withSprites
                ? _sprite(c.spriteUrl)
                : leadingOf?.call(c),
            trailingIcon: trailingOf?.call(c),
          ),
      ],
      onSelected: (v) => widget.onChanged(v == null || v == _none ? null : v),
    );
  }

  /// A folha com busca (#409); o que for escolhido nela vai para o
  /// [ChoiceSelect.onChanged], e a ação, para o `onPressed` da [ChoiceSelect.action].
  Future<void> _openSheet(
    List<Choice> choices, {
    required bool natures,
    required bool sprites,
  }) async {
    final l10n = context.l10n;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _ChoiceSheet(
        title: widget.label,
        choices: choices,
        value: widget.value,
        neutralTag: natures ? l10n.natureNeutralTag : null,
        leadingOf: sprites
            ? (c) => PokemonSprite(url: c.spriteUrl, size: 30)
            : widget.leadingOf,
        trailingOf: widget.trailingOf,
        action: widget.action,
      ),
    );
    switch (picked) {
      case null:
        return;
      case _ChoiceSheet.actionValue:
        widget.action?.onPressed();
      case final value:
        widget.onChanged(value == _none ? null : value);
    }
  }

  /// "Careful ↑ Def. Esp. ↓ Atq. Esp." ou "Bashful (neutra)".
  static String _withEffect(AppLocalizations l10n, Choice nature) =>
      switch ((nature.increased, nature.decreased)) {
        (final up?, final down?) when up != down =>
          '${nature.label} ↑ ${l10n.stat(up)} ↓ ${l10n.stat(down)}',
        _ => '${nature.label} ${l10n.natureNeutralTag}',
      };

  Widget _sprite(String? url) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: PokemonSprite(url: url, size: 24),
  );

  /// As que casam com o texto; nas naturezas, as que casam pelo nome
  /// primeiro, depois as que sobem e por fim as que descem o atributo
  /// buscado ("velo": Jolly, Timid... e então Brave, Quiet...).
  static List<DropdownMenuEntry<String>> _filter(
    List<DropdownMenuEntry<String>> entries,
    String text, [
    String? neutralTag,
  ]) => [
    for (final (_, e) in _ranked(entries, (e) => e.label, text, neutralTag)) e,
  ];

  /// Destaca a primeira opção que casa com o texto (Enter a escolhe).
  static int? _search(List<DropdownMenuEntry<String>> entries, String text) {
    if (text.isEmpty) return null;
    final query = foldForSearch(text);
    final index = entries.indexWhere(
      (e) => foldForSearch(e.label).contains(query),
    );
    return index < 0 ? null : index;
  }
}

/// Os [items] que casam com o [text] (sem maiúsculas nem acentos), com o
/// grau: 0 pelo nome; nas naturezas (`neutralTag` informado), 1 pelo
/// atributo que sobe e 2 pelo que desce, nessa ordem ("velo": Jolly,
/// Timid... e então Brave, Quiet...).
List<(int, T)> _ranked<T>(
  List<T> items,
  String Function(T item) labelOf,
  String text,
  String? neutralTag,
) {
  final query = foldForSearch(text);
  int? rank(String label) {
    if (neutralTag == null) {
      return foldForSearch(label).contains(query) ? 0 : null;
    }
    final parts = _EffectParts.of(label, neutralTag);
    final name = [parts.name, ?parts.neutral].join(' ');
    for (final (i, part) in [name, parts.up, parts.down].indexed) {
      if (part != null && foldForSearch(part).contains(query)) return i;
    }
    return null;
  }

  // `sort` não é estável: a ordem original desempata.
  final ranked = [
    for (final (i, item) in items.indexed)
      if (rank(labelOf(item)) case final r?) (r, i, item),
  ]..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
  return [for (final (r, _, item) in ranked) (r, item)];
}

/// Um rótulo de natureza em partes: o nome, "↑ X" e "↓ Y" (ou o
/// `neutralTag`, "(neutra)"). Sem efeito (o "—", texto digitado), só o nome.
class _EffectParts {
  _EffectParts._(this.name, this.up, this.down, this.neutral);

  factory _EffectParts.of(String label, String neutralTag) {
    final up = label.indexOf(' ↑ ');
    final down = label.indexOf(' ↓ ');
    if (up > 0 && down > up) {
      return _EffectParts._(
        label.substring(0, up),
        label.substring(up + 1, down),
        label.substring(down + 1),
        null,
      );
    }
    if (label.endsWith(' $neutralTag')) {
      return _EffectParts._(
        label.substring(0, label.length - neutralTag.length - 1),
        null,
        null,
        neutralTag,
      );
    }
    return _EffectParts._(label, null, null, null);
  }

  final String name;
  final String? up;
  final String? down;
  final String? neutral;

  bool get hasEffect => up != null || neutral != null;
}

TextStyle? _upStyle(BuildContext context, TextStyle? base) => base?.copyWith(
  fontSize: (base.fontSize ?? 16) * 0.875,
  fontWeight: FontWeight.w500,
  color: NatureColors.increased(Theme.of(context).brightness),
);

TextStyle? _downStyle(BuildContext context, TextStyle? base) => base?.copyWith(
  fontSize: (base.fontSize ?? 16) * 0.875,
  fontWeight: FontWeight.w500,
  color: NatureColors.decreased(Theme.of(context).brightness),
);

TextStyle? _neutralStyle(BuildContext context, TextStyle? base) =>
    base?.copyWith(
      fontSize: (base.fontSize ?? 16) * 0.875,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

/// O texto do campo com o efeito da natureza pintado; qualquer outro texto
/// (o digitado, outras listas) sai como sempre.
class _EffectController extends TextEditingController {
  /// O "(neutra)" do idioma da tela numa lista de naturezas; `null` nas
  /// outras listas, que nunca são pintadas.
  String? natures;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing,
    TextStyle? style,
  }) {
    final tag = natures;
    final parts = tag == null ? null : _EffectParts.of(text, tag);
    if (parts == null || !parts.hasEffect) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: parts.name),
        if (parts.up case final up?) ...[
          const TextSpan(text: ' '),
          TextSpan(text: up, style: _upStyle(context, style)),
          const TextSpan(text: ' '),
          TextSpan(text: parts.down, style: _downStyle(context, style)),
        ],
        if (parts.neutral case final neutral?) ...[
          const TextSpan(text: ' '),
          TextSpan(text: neutral, style: _neutralStyle(context, style)),
        ],
      ],
    );
  }
}

/// Um item da lista de naturezas: o nome e o efeito em duas colunas
/// alinhadas, para correr o olho pelo ↑.
class _NatureEntry extends StatelessWidget {
  const _NatureEntry(this.parts);

  final _EffectParts parts;

  /// Cabe "↑ Velocidade", o mais largo.
  static const _column = 104.0;

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style;
    return Row(
      spacing: 8,
      children: [
        Expanded(child: Text(parts.name, overflow: TextOverflow.ellipsis)),
        if (parts.neutral case final neutral?)
          SizedBox(
            width: _column * 2 + 8,
            child: Text(neutral, style: _neutralStyle(context, base)),
          )
        else ...[
          SizedBox(
            width: _column,
            child: Text(parts.up ?? '', style: _upStyle(context, base)),
          ),
          SizedBox(
            width: _column,
            child: Text(parts.down ?? '', style: _downStyle(context, base)),
          ),
        ],
      ],
    );
  }
}

/// A folha de opções do celular (#409): o título, a busca (sem foco
/// automático: no iPhone, o teclado só abre com o toque no próprio campo,
/// e assim dá para rolar vendo os sprites), o "—", as opções e a ação.
/// Devolve o valor tocado (`''` no "—", [actionValue] na ação).
class _ChoiceSheet extends StatefulWidget {
  const _ChoiceSheet({
    required this.title,
    required this.choices,
    required this.value,
    required this.neutralTag,
    required this.leadingOf,
    required this.trailingOf,
    required this.action,
  });

  /// O valor devolvido quando a ação é tocada.
  static const actionValue = '\u0000action';

  final String title;
  final List<Choice> choices;
  final String? value;

  /// O "(neutra)" numa lista de naturezas; `null` nas outras.
  final String? neutralTag;
  final Widget? Function(Choice choice)? leadingOf;
  final Widget? Function(Choice choice)? trailingOf;
  final ChoiceAction? action;

  @override
  State<_ChoiceSheet> createState() => _ChoiceSheetState();
}

class _ChoiceSheetState extends State<_ChoiceSheet> {
  final _search = TextEditingController();

  /// A altura da folha deixa à mostra o topo da tela (o título do
  /// formulário), como no mock.
  static const _topGap = 72.0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final query = _search.text.trim();
    final tag = widget.neutralTag;
    final ranked = query.isEmpty
        ? [for (final c in widget.choices) (0, c)]
        : _ranked(widget.choices, (c) => c.label, query, tag);
    final action = widget.action;
    final rows = <Widget>[
      if (query.isEmpty) _row(context, null, query),
      for (final (i, (rank, choice)) in ranked.indexed) ...[
        if (tag != null && rank > 0 && (i == 0 || ranked[i - 1].$1 != rank))
          _groupHeader(context, choice, rank),
        _row(context, choice, query),
      ],
      if (ranked.isEmpty && query.isNotEmpty)
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            l10n.choiceNoMatch,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      if (action != null)
        ListTile(
          key: const ValueKey('choice-action'),
          leading: Icon(action.icon, color: theme.colorScheme.primary),
          title: Text(
            action.label,
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          onTap: () => Navigator.of(context).pop(_ChoiceSheet.actionValue),
        ),
    ];
    // O teclado empurra a folha para cima e a lista encolhe acima dele.
    final keyboard = media.viewInsets.bottom;
    // A alça de arrastar (showDragHandle) ocupa kMinInteractiveDimension
    // acima do conteúdo.
    final height =
        media.size.height -
        media.padding.top -
        _topGap -
        kMinInteractiveDimension -
        keyboard;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SizedBox(
        height: height.clamp(200, double.infinity),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const CloseButton(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                key: const ValueKey('choice-search'),
                controller: _search,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                // Enter com uma opção só: escolhe.
                onSubmitted: (_) {
                  if (ranked.length == 1) {
                    Navigator.of(context).pop(ranked.single.$2.value);
                  }
                },
                decoration: InputDecoration(
                  hintText: tag != null ? l10n.natureSearch : l10n.choiceSearch,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l10n.clearSearch,
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(_search.clear),
                        ),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(bottom: media.padding.bottom + 8),
                children: rows,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Sobe Velocidade" / "Desce Velocidade", antes das naturezas que casam
  /// pelo atributo.
  Widget _groupHeader(BuildContext context, Choice first, int rank) {
    final parts = _EffectParts.of(first.label, widget.neutralTag!);
    final stat = (rank == 1 ? parts.up : parts.down)!.substring(2);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(
        (rank == 1
                ? context.l10n.natureGroupUp(stat)
                : context.l10n.natureGroupDown(stat))
            .toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  /// Uma opção ([choice] `null`: o "—"), com o trecho buscado em destaque
  /// e o ✓ na escolhida.
  Widget _row(BuildContext context, Choice? choice, String query) {
    final theme = Theme.of(context);
    final value = choice?.value ?? '';
    final selected = (widget.value ?? '') == value;
    final tag = widget.neutralTag;
    final leading = choice == null ? null : widget.leadingOf?.call(choice);
    final trailing = choice == null ? null : widget.trailingOf?.call(choice);
    final Widget title;
    if (choice == null) {
      title = Text(
        '—',
        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
      );
    } else if (tag != null) {
      title = _NatureEntry(_EffectParts.of(choice.label, tag));
    } else {
      title = Text.rich(
        _highlight(choice.label, query, theme.colorScheme.primary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return ListTile(
      key: ValueKey('choice-$value'),
      selected: selected,
      selectedTileColor: theme.colorScheme.surfaceContainerHighest,
      selectedColor: theme.colorScheme.onSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      minTileHeight: 52,
      // Alinha o "—" com as opções que têm sprite ou ícone.
      leading: widget.leadingOf == null
          ? null
          : SizedBox.square(dimension: 30, child: Center(child: leading)),
      title: title,
      trailing: (trailing == null && !selected)
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                ?trailing,
                if (selected)
                  Icon(Icons.check, color: theme.colorScheme.primary),
              ],
            ),
      onTap: () => Navigator.of(context).pop(value),
    );
  }

  /// O [label] com o primeiro trecho que casa com a [query] em negrito e
  /// na cor de destaque. A comparação ignora acentos ("poke" em "Poké").
  static TextSpan _highlight(String label, String query, Color color) {
    final folded = foldForSearch(label);
    final start = query.isEmpty ? -1 : folded.indexOf(foldForSearch(query));
    // A dobra troca um caractere por um (`foldForSearch`): os índices
    // valem no original.
    if (start < 0) {
      return TextSpan(text: label);
    }
    final end = start + query.length;
    return TextSpan(
      children: [
        TextSpan(text: label.substring(0, start)),
        TextSpan(
          text: label.substring(start, end),
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
        TextSpan(text: label.substring(end)),
      ],
    );
  }
}
