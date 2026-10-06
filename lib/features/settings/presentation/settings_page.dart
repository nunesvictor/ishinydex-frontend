import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/features/local/presentation/local_data_tiles.dart';
import 'package:ishinydex/features/settings/data/date_format_storage.dart';
import 'package:ishinydex/features/settings/settings_providers.dart';

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
          const _CaptureDateFormatSetting(),
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

/// Formato da data de captura digitada no formulário (PC).
class _CaptureDateFormatSetting extends ConsumerWidget {
  const _CaptureDateFormatSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        ref.watch(captureDateFormatProvider).value ?? CaptureDateFormat.home;
    final locale = Localizations.localeOf(context).toString();
    // Exemplo: 23 de setembro de 2024 em cada formato.
    final sample = DateTime(2024, 9, 23);
    String example(CaptureDateFormat f) =>
        CaptureDatePattern(f, locale).format(sample);
    return RadioGroup<CaptureDateFormat>(
      groupValue: current,
      onChanged: (f) {
        if (f != null) {
          unawaited(ref.read(captureDateFormatProvider.notifier).choose(f));
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ListTile(
            leading: Icon(Icons.event),
            title: Text('Formato da data de captura'),
            subtitle: Text(
              'Usado ao digitar a data no formulário do espécime.',
            ),
          ),
          RadioListTile<CaptureDateFormat>(
            value: CaptureDateFormat.home,
            title: const Text('Pokémon HOME (mm/dd/aaaa)'),
            subtitle: Text('Ex.: ${example(CaptureDateFormat.home)}'),
          ),
          RadioListTile<CaptureDateFormat>(
            value: CaptureDateFormat.locale,
            title: Text(
              'Do idioma do app '
              '(${CaptureDatePattern(CaptureDateFormat.locale, locale).hint})',
            ),
            subtitle: Text('Ex.: ${example(CaptureDateFormat.locale)}'),
          ),
        ],
      ),
    );
  }
}
