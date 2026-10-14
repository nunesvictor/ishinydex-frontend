import 'package:flutter/material.dart';
import 'package:ishinydex/core/l10n/app_language.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/theme/app_theme.dart';

/// O app não abriu (modo local sem catálogo, dados de uma versão mais nova
/// do app...): explica e deixa tentar de novo, em vez de uma tela branca.
/// Sai no idioma de Ajustes ([language]), como o app.
class BootFailureApp extends StatelessWidget {
  const BootFailureApp({
    required this.error,
    required this.onRetry,
    this.language = AppLanguage.system,
    super.key,
  });

  final Object error;
  final VoidCallback onRetry;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    locale: language.locale,
    supportedLocales: supportedLocales,
    localeListResolutionCallback: (device, _) => resolveLocale(device),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                const Icon(Icons.cloud_off, size: 48),
                Text(
                  context.l10n.bootFailureTitle,
                  textAlign: TextAlign.center,
                ),
                Text(switch (error) {
                  final AppFailure failure => context.failureText(failure),
                  _ => context.l10n.bootFailureCheckConnection,
                }, textAlign: TextAlign.center),
                // O detalhe técnico, para quem for relatar o problema.
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                FilledButton(
                  onPressed: onRetry,
                  child: Text(context.l10n.tryAgain),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
