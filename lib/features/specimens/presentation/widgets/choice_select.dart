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
/// - Mobile: só toque, para o teclado virtual não cobrir a lista.
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
    super.key,
  });

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

  @override
  State<ChoiceSelect> createState() => _ChoiceSelectState();
}

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
      leadingIcon: withSprites
          ? _sprite(selected?.spriteUrl)
          : selected == null
          ? null
          : leadingOf?.call(selected),
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
  ]) {
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

    final ranked = [
      for (final e in entries)
        if (rank(e.label) case final r?) (r, e),
    ];
    // `sort` não é estável: a ordem original desempata.
    final order = {for (final (i, e) in entries.indexed) e: i};
    ranked.sort(
      (a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : order[a.$2]! - order[b.$2]!,
    );
    return [for (final (_, e) in ranked) e];
  }

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
