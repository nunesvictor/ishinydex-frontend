import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/features/local/presentation/local_data_tiles.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final env = ref.watch(envProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          const LocalDataTiles(),
          ListTile(
            leading: const Icon(Icons.videogame_asset_outlined),
            title: const Text('Meus saves'),
            subtitle: const Text('Jogos para onde você envia Pokémon do HOME'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(Routes.saves),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Shiny locks'),
            subtitle: const Text('Formas sem shiny, ou só por distribuição'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(Routes.shinyLocks),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Sobre o iShinyDex'),
            subtitle: Text('Versão ${env.appVersion}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(Routes.about),
          ),
        ],
      ),
    );
  }
}
