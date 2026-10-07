import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/responsive/breakpoints.dart';

class ShellDestination {
  const ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const shellDestinations = [
  ShellDestination(
    label: 'PersonalDex',
    icon: Icons.catching_pokemon_outlined,
    selectedIcon: Icons.catching_pokemon,
  ),
  ShellDestination(
    label: 'Espécimes',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2,
  ),
  ShellDestination(
    label: 'Ajustes',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
  ),
];

/// Índice de Ajustes em [shellDestinations].
const settingsDestination = 2;

/// Casca de navegação: NavigationBar no compacto, NavigationRail nos demais.
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({
    required this.navigationShell,
    required this.activity,
    required this.decorateIcon,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  /// Uma faixa fina sobre o conteúdo, colada na navegação: em cima da barra
  /// inferior no compacto e no topo do conteúdo nos demais (ex.: o sync em
  /// andamento). Fica por cima, sem empurrar nada.
  final Widget activity;

  /// Troca o ícone de um destino (pelo índice em [shellDestinations]), por
  /// exemplo para pôr um selo.
  final Widget Function(int index, Widget icon) decorateIcon;

  Widget _icon(int index, IconData icon) => decorateIcon(index, Icon(icon));

  /// O conteúdo com a [activity] por cima, no topo ou embaixo.
  Widget _body({required bool atBottom}) => Stack(
    children: [
      Positioned.fill(child: navigationShell),
      Positioned(
        left: 0,
        right: 0,
        top: atBottom ? null : 0,
        bottom: atBottom ? 0 : null,
        child: activity,
      ),
    ],
  );

  void _goTo(int index) => navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final size = WindowSize.of(context);
    if (size.isCompact) {
      return Scaffold(
        body: _body(atBottom: true),
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _goTo,
          destinations: [
            for (final (i, d) in shellDestinations.indexed)
              NavigationDestination(
                icon: _icon(i, d.icon),
                selectedIcon: _icon(i, d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      );
    }
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            // Estendido só em telas largas: até 1440px, a largura vai para a
            // grade da box.
            extended: size.isLarge,
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _goTo,
            labelType: size.isLarge
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Icon(Icons.auto_awesome),
            ),
            destinations: [
              for (final (i, d) in shellDestinations.indexed)
                NavigationRailDestination(
                  icon: _icon(i, d.icon),
                  selectedIcon: _icon(i, d.selectedIcon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _body(atBottom: false)),
        ],
      ),
    );
  }
}
