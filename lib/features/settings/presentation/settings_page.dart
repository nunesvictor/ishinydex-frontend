import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/widgets/confirm_dialog.dart';
import 'package:ishinydex/features/auth/auth_providers.dart';
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
          if (env.localData)
            const ListTile(
              leading: Icon(Icons.smartphone_outlined),
              title: Text('Dados'),
              subtitle: Text('Neste aparelho'),
            )
          else
            ListTile(
              leading: const Icon(Icons.dns_outlined),
              title: const Text('Servidor'),
              subtitle: Text(
                env.useFakeApi
                    ? 'Modo demonstração (dados fake)'
                    : env.apiBaseUrl,
              ),
            ),
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
          // No modo local não há conta: nada de "Sair".
          if (!env.localData)
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sair'),
              onTap: () async {
                final confirmed = await showConfirmDialog(
                  context,
                  title: 'Sair?',
                  message: 'Você precisará entrar novamente.',
                  confirmLabel: 'Sair',
                  destructive: true,
                );
                if (confirmed) {
                  await ref.read(authControllerProvider.notifier).logout();
                }
              },
            ),
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
