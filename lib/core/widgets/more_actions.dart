import 'package:flutter/material.dart';
import 'package:ishinydex/core/l10n/l10n.dart';

/// Uma ação do menu "Mais ações" ([DetailActionBar]).
class MoreAction {
  const MoreAction({
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

  /// Chamada depois que o menu fecha (pode abrir diálogos e folhas).
  final VoidCallback onSelected;
}

/// Barra fixa no rodapé das telas de detalhe: só a ação principal e
/// "Mais ações". O conteúdo rola por cima dela, então ações novas não fazem
/// a tela crescer.
///
/// "Mais ações" abre um menu preso ao botão (#298), e não uma folha: no
/// celular, a barra fica dentro da folha do slot, e uma folha por cima da
/// outra escurecia a tela duas vezes.
class DetailActionBar extends StatelessWidget {
  const DetailActionBar({this.primary, this.actions, super.key});

  /// A ação principal (ex.: Editar espécime). Sem ela, "Mais ações" ocupa
  /// a barra.
  final Widget? primary;

  /// As ações do menu "Mais ações". Sem elas (ou vazias), não há o botão.
  final List<MoreAction>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final more = actions ?? const <MoreAction>[];
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
            else if (more.isNotEmpty)
              Expanded(
                child: MoreActionsMenu(
                  actions: more,
                  builder: (context, toggle) => OutlinedButton.icon(
                    onPressed: toggle,
                    icon: const Icon(Icons.more_horiz),
                    label: Text(context.l10n.moreActions),
                  ),
                ),
              ),
            if (primary != null && more.isNotEmpty)
              MoreActionsMenu(
                actions: more,
                builder: (context, toggle) => IconButton.outlined(
                  tooltip: context.l10n.moreActions,
                  onPressed: toggle,
                  icon: const Icon(Icons.more_horiz),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// O menu "Mais ações" preso ao botão que [builder] monta (#298): cada ação
/// com o ícone, o nome e a explicação numa segunda linha; as desabilitadas
/// aparecem com o motivo. As destrutivas vão por último, separadas e na cor
/// de erro.
class MoreActionsMenu extends StatelessWidget {
  const MoreActionsMenu({
    required this.actions,
    required this.builder,
    super.key,
  });

  final List<MoreAction> actions;

  /// O botão que abre e fecha o menu, com o `toggle` no `onPressed`.
  final Widget Function(BuildContext context, VoidCallback toggle) builder;

  /// Largura máxima do texto: explicações longas quebram em duas linhas em
  /// vez de alargar o menu além da tela do celular.
  static const textWidth = 240.0;

  @override
  Widget build(BuildContext context) {
    final regular = [
      for (final action in actions)
        if (!action.destructive) action,
    ];
    final destructive = [
      for (final action in actions)
        if (action.destructive) action,
    ];
    return MenuAnchor(
      menuChildren: [
        ...regular.map((action) => _item(context, action)),
        if (regular.isNotEmpty && destructive.isNotEmpty) const Divider(),
        ...destructive.map((action) => _item(context, action)),
      ],
      builder: (context, controller, _) => builder(
        context,
        () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }

  Widget _item(BuildContext context, MoreAction action) {
    final theme = Theme.of(context);
    final error = action.destructive ? theme.colorScheme.error : null;
    final hint = theme.colorScheme.onSurfaceVariant;
    return MenuItemButton(
      // O menu fecha antes: a ação pode abrir diálogos e folhas.
      onPressed: action.enabled ? action.onSelected : null,
      leadingIcon: action.leading ?? Icon(action.icon),
      style: error == null
          ? null
          : MenuItemButton.styleFrom(foregroundColor: error, iconColor: error),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: textWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(action.label),
              if (action.subtitle case final subtitle?)
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    // Desabilitada, a explicação apaga junto com o nome.
                    color: action.enabled ? hint : hint.withValues(alpha: 0.38),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
