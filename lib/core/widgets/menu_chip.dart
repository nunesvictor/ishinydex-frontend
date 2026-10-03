import 'package:flutter/material.dart';

/// Chip de filtro que abre um menu (▾) com as opções de um grupo, como
/// "Situação" ou "Motivos". Um grupo inteiro ocupa um chip só, então a
/// linha de filtros cabe na largura do celular sem rolagem lateral.
///
/// [selected] destaca o chip quando o grupo não está no padrão.
class MenuChip extends StatelessWidget {
  const MenuChip({
    required this.label,
    required this.menuChildren,
    this.selected = false,
    this.tooltip,
    super.key,
  });

  final String label;
  final bool selected;
  final String? tooltip;

  /// Itens do menu: [MenuHeader], `RadioMenuButton`, `CheckboxMenuButton`...
  final List<Widget> menuChildren;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    menuChildren: menuChildren,
    builder: (context, controller, _) => FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Text(label), const Icon(Icons.arrow_drop_down, size: 18)],
      ),
      tooltip: tooltip,
      selected: selected,
      showCheckmark: false,
      onSelected: (_) =>
          controller.isOpen ? controller.close() : controller.open(),
    ),
  );
}

/// Título de um menu de [MenuChip] (não é clicável).
class MenuHeader extends StatelessWidget {
  const MenuHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Texto de uma opção de menu com uma linha de explicação embaixo.
class MenuOptionText extends StatelessWidget {
  const MenuOptionText(this.label, this.hint, {this.leading, super.key});

  final String label;
  final String hint;

  /// Ícone antes do rótulo (ex.: a marca do GO).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [?leading, Text(label)],
          ),
          Text(
            hint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
