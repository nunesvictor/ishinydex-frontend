import 'package:flutter/material.dart';
import 'package:ishinydex/core/responsive/breakpoints.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';

/// Select de [Choice]s sobre o `DropdownMenu` do Material 3.
///
/// - Desktop: o campo aceita digitação e filtra as opções, ignorando
///   maiúsculas e acentos ("poke" encontra "Poké Ball"); Enter escolhe a
///   opção destacada.
/// - Mobile: só toque, para o teclado virtual não cobrir a lista.
/// - Quando alguma opção tem `spriteUrl` (pokébolas), o sprite aparece em
///   cada item e à esquerda do campo, como o select2 do admin.
///
/// O primeiro item ("—") limpa a seleção e devolve `null` em [onChanged].
class ChoiceSelect extends StatelessWidget {
  const ChoiceSelect({
    required this.label,
    required this.choices,
    required this.value,
    required this.onChanged,
    this.errorText,
    super.key,
  });

  /// Valor interno do item "—"; o `DropdownMenu` não aceita entrada `null`.
  static const _none = '';

  final String label;
  final List<Choice> choices;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktopPlatform(Theme.of(context).platform);
    final withSprites = choices.any((c) => c.spriteUrl != null);
    final selected = choices.where((c) => c.value == value).firstOrNull;
    return DropdownMenu<String>(
      initialSelection: selected?.value ?? _none,
      label: Text(label),
      errorText: errorText,
      expandedInsets: EdgeInsets.zero,
      menuHeight: 320,
      requestFocusOnTap: desktop,
      enableFilter: desktop,
      filterCallback: desktop ? _filter : null,
      searchCallback: _search,
      leadingIcon: withSprites ? _sprite(selected?.spriteUrl) : null,
      dropdownMenuEntries: [
        const DropdownMenuEntry(value: _none, label: '—'),
        for (final c in choices)
          DropdownMenuEntry(
            value: c.value,
            label: c.label,
            leadingIcon: withSprites ? _sprite(c.spriteUrl) : null,
          ),
      ],
      onSelected: (v) => onChanged(v == null || v == _none ? null : v),
    );
  }

  Widget _sprite(String? url) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: PokemonSprite(url: url, size: 24),
  );

  static List<DropdownMenuEntry<String>> _filter(
    List<DropdownMenuEntry<String>> entries,
    String text,
  ) {
    final query = foldForSearch(text);
    return [
      for (final e in entries)
        if (foldForSearch(e.label).contains(query)) e,
    ];
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
