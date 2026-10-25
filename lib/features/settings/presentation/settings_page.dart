import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/l10n/app_language.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/responsive/breakpoints.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/theme/app_theme_mode.dart';
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
          const ThemeModeTile(),
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

/// Ajustes → Preferências → Aparência (#273): o tema em uso e a escolha
/// ([showThemeModePicker]), no mesmo desenho do Idioma.
class ThemeModeTile extends ConsumerWidget {
  const ThemeModeTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mode = ref.watch(appThemeModeProvider);
    return ListTile(
      leading: const Icon(Icons.palette_outlined),
      title: Text(l10n.appearance),
      subtitle: Text(switch (mode) {
        ThemeMode.system => l10n.themeAutomaticValue(
          _themeName(l10n, MediaQuery.platformBrightnessOf(context)),
        ),
        ThemeMode.light => l10n.themeLight,
        ThemeMode.dark => l10n.themeDark,
      }),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showThemeModePicker(context, ref),
    );
  }
}

String _themeName(AppLocalizations l10n, Brightness brightness) =>
    brightness == Brightness.dark ? l10n.themeDark : l10n.themeLight;

/// A escolha do tema: folha no compacto, diálogo nos demais. Escolher fecha
/// e troca na hora.
Future<void> showThemeModePicker(BuildContext context, WidgetRef ref) async {
  final options = _ThemeModeOptions(
    selected: ref.read(appThemeModeProvider),
    // O tema que o "Automático" usa agora neste aparelho.
    device: _themeName(context.l10n, MediaQuery.platformBrightnessOf(context)),
  );
  final ThemeMode? picked;
  if (WindowSize.of(context).isCompact) {
    picked = await showModalBottomSheet<ThemeMode>(
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
                context.l10n.appearance,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            options,
          ],
        ),
      ),
    );
  } else {
    picked = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.appearance),
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
    await ref.read(appThemeModeProvider.notifier).select(picked);
  }
}

/// Automático, Claro e Escuro, e o aviso da barra de status do iPhone, que
/// só troca de cor na próxima abertura (limitação do WebKit, #290).
class _ThemeModeOptions extends StatelessWidget {
  const _ThemeModeOptions({required this.selected, required this.device});

  final ThemeMode selected;
  final String device;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return RadioGroup<ThemeMode>(
      groupValue: selected,
      onChanged: (value) => Navigator.of(context).pop(value),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RadioListTile(
            value: ThemeMode.system,
            title: Text(l10n.languageAutomatic),
            subtitle: Text(l10n.themeAutomaticSubtitle(device)),
          ),
          RadioListTile(value: ThemeMode.light, title: Text(l10n.themeLight)),
          RadioListTile(value: ThemeMode.dark, title: Text(l10n.themeDark)),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Text(
              l10n.themeStatusBarNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
