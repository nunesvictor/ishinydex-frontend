import 'package:flutter/widgets.dart';
import 'package:ishinydex/l10n/app_localizations.dart';

export 'package:ishinydex/l10n/app_localizations.dart';

/// Atalhos de tradução (ishinydex-frontend#178).
extension L10nContext on BuildContext {
  /// Os textos da interface no idioma da tela: `context.l10n.settingsTitle`.
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// A chave do idioma da tela nos `labels` do catálogo (`en` ou `pt-BR`).
  String get catalogLanguage =>
      Localizations.localeOf(this).languageCode == 'pt' ? 'pt-BR' : 'en';

  /// Um texto do catálogo no idioma da tela: o de [labels], ou o [fallback]
  /// em pt-BR quando o catálogo é antigo (sem `labels`).
  String catalogText(String fallback, Map<String, String> labels) =>
      labels[catalogLanguage] ?? fallback;
}
