import 'package:flutter/material.dart';

/// Campo de busca do app: uma pílula preenchida, com a lupa à esquerda e o
/// "x" de limpar quando há texto. Os demais campos (formulários) seguem o
/// contorno arredondado do tema (`AppTheme`); a pílula diferencia a busca
/// de um campo de cadastro.
class SearchField extends StatefulWidget {
  const SearchField({
    required this.hintText,
    this.onChanged,
    this.onCleared,
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.dense = false,
    super.key,
  });

  final String hintText;
  final ValueChanged<String>? onChanged;

  /// Depois de limpar o campo; sem ele, avisa [onChanged] com `''`.
  final VoidCallback? onCleared;

  /// Sem ele, o campo cria e descarta o seu.
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Mais baixo, para diálogos.
  final bool dense;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  TextEditingController? _own;

  TextEditingController get _controller =>
      widget.controller ?? (_own ??= TextEditingController());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    final onCleared = widget.onCleared;
    if (onCleared != null) {
      onCleared();
    } else {
      widget.onChanged?.call('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    OutlineInputBorder pill([BorderSide side = BorderSide.none]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: side,
        );
    // Reconstrói só o campo quando o texto muda, para o "x" aparecer apenas
    // com algo digitado.
    return ValueListenableBuilder(
      valueListenable: _controller,
      builder: (context, value, _) => TextField(
        controller: _controller,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: widget.hintText,
          isDense: widget.dense,
          filled: true,
          fillColor: scheme.surfaceContainerHigh,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpar busca',
                  onPressed: _clear,
                  icon: const Icon(Icons.clear),
                ),
          border: pill(),
          enabledBorder: pill(),
          focusedBorder: pill(BorderSide(color: scheme.primary, width: 2)),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}
