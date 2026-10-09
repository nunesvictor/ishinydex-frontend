import 'package:flutter/material.dart';

/// Uma ação da [showActionSheet].
class SheetAction {
  const SheetAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.subtitle,
    this.destructive = false,
    this.enabled = true,
    this.leading,
  });

  final IconData icon;
  final String label;

  /// Uma linha explicando o efeito ("volta para o inventário").
  final String? subtitle;

  /// Ações que apagam algo: no fim, separadas e na cor de erro.
  final bool destructive;

  /// Desabilitada: aparece (com o motivo no [subtitle]), mas não responde.
  final bool enabled;

  /// No lugar do [icon] (ex.: o ícone colorido de um jogo).
  final Widget? leading;

  /// Chamada depois que a folha fecha (pode abrir diálogos e outras folhas).
  final VoidCallback onSelected;
}

/// Folha de ações, no padrão do iOS: as ações secundárias de uma tela de
/// detalhe ficam aqui, e não em mais botões empilhados. As destrutivas vão
/// por último, separadas.
Future<void> showActionSheet(
  BuildContext context, {
  required List<SheetAction> actions,
  String? title,
}) async {
  final regular = [
    for (final action in actions)
      if (!action.destructive) action,
  ];
  final destructive = [
    for (final action in actions)
      if (action.destructive) action,
  ];
  final picked = await showModalBottomSheet<SheetAction>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      Widget tile(SheetAction action) {
        final color = action.destructive ? theme.colorScheme.error : null;
        return ListTile(
          enabled: action.enabled,
          leading: action.leading ?? Icon(action.icon, color: color),
          title: Text(action.label, style: TextStyle(color: color)),
          subtitle: action.subtitle == null ? null : Text(action.subtitle!),
          onTap: () => Navigator.of(context).pop(action),
        );
      }

      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(title, style: theme.textTheme.titleMedium),
              ),
            ...regular.map(tile),
            if (regular.isNotEmpty && destructive.isNotEmpty) const Divider(),
            ...destructive.map(tile),
          ],
        ),
      );
    },
  );
  picked?.onSelected();
}

/// Barra fixa no rodapé das telas de detalhe: só a ação principal e
/// "Mais ações" (que abre a [showActionSheet]). O conteúdo rola por cima
/// dela, então ações novas não fazem a tela crescer.
class DetailActionBar extends StatelessWidget {
  const DetailActionBar({this.primary, this.onMore, super.key});

  /// A ação principal (ex.: Editar espécime). Sem ela, "Mais ações" ocupa
  /// a barra.
  final Widget? primary;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final more = onMore;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          spacing: 8,
          children: [
            if (primary case final primary?)
              Expanded(child: primary)
            else if (more != null)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: more,
                  icon: const Icon(Icons.more_horiz),
                  label: const Text('Mais ações'),
                ),
              ),
            if (primary != null && more != null)
              IconButton.outlined(
                tooltip: 'Mais ações',
                onPressed: more,
                icon: const Icon(Icons.more_horiz),
              ),
          ],
        ),
      ),
    );
  }
}
