import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/l10n/app_language.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/responsive/breakpoints.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/features/local/presentation/local_data_tiles.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final env = ref.watch(envProvider);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          const LocalDataTiles(),
          ListTile(
            leading: const Icon(Icons.videogame_asset_outlined),
            title: Text(l10n.settingsMySaves),
            subtitle: Text(l10n.settingsMySavesSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(Routes.saves),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(l10n.settingsShinyLocks),
            subtitle: Text(l10n.settingsShinyLocksSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(Routes.shinyLocks),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              l10n.settingsPreferences,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const LanguageTile(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.settingsAbout),
            subtitle: Text(l10n.settingsVersion(env.appVersion)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(Routes.about),
          ),
        ],
      ),
    );
  }
}

/// Ajustes → Preferências → Idioma: mostra o idioma em uso e abre a
/// escolha ([showLanguagePicker]).
class LanguageTile extends ConsumerWidget {
  const LanguageTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    return ListTile(
      leading: const Icon(Icons.language),
      title: Text(l10n.language),
      subtitle: Text(
        ref.watch(appLanguageProvider) == AppLanguage.system
            ? l10n.languageAutomaticValue(languageName(locale, short: true))
            : languageName(locale),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showLanguagePicker(context, ref),
    );
  }
}

/// A escolha do idioma: folha no compacto, diálogo nos demais. Escolher
/// fecha e troca na hora, sem recarregar.
Future<void> showLanguagePicker(BuildContext context, WidgetRef ref) async {
  final options = _LanguageOptions(
    selected: ref.read(appLanguageProvider),
    // O idioma que o "Automático" usa neste aparelho.
    device: languageName(
      resolveLocale(WidgetsBinding.instance.platformDispatcher.locales),
      short: true,
    ),
  );
  final AppLanguage? picked;
  if (WindowSize.of(context).isCompact) {
    picked = await showModalBottomSheet<AppLanguage>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                context.l10n.language,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            options,
          ],
        ),
      ),
    );
  } else {
    picked = await showDialog<AppLanguage>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.language),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        content: options,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
        ],
      ),
    );
  }
  if (picked != null) {
    await ref.read(appLanguageProvider.notifier).select(picked);
  }
}

/// As três opções. Os idiomas aparecem na própria língua ([languageName]):
/// quem escolheu o errado reconhece o seu para voltar.
class _LanguageOptions extends StatelessWidget {
  const _LanguageOptions({required this.selected, required this.device});

  final AppLanguage selected;
  final String device;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RadioGroup<AppLanguage>(
      groupValue: selected,
      onChanged: (value) => Navigator.of(context).pop(value),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile(
            value: AppLanguage.system,
            title: Text(l10n.languageAutomatic),
            subtitle: Text(l10n.languageAutomaticSubtitle(device)),
          ),
          RadioListTile(
            value: AppLanguage.en,
            title: Text(languageName(english)),
          ),
          RadioListTile(
            value: AppLanguage.pt,
            title: Text(languageName(portuguese)),
          ),
        ],
      ),
    );
  }
}
