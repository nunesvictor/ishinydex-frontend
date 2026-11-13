import 'package:flutter/widgets.dart';
import 'package:ishinydex/core/l10n/problem_text.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart' show GlobalMaterialLocalizations;

export 'package:ishinydex/core/l10n/core_labels.dart';
export 'package:ishinydex/core/l10n/problem_text.dart';
export 'package:ishinydex/l10n/app_localizations.dart';

/// Os delegates de tradução do app: os textos do app e os do Material,
/// Cupertino e widgets do `material_ui` (#402). O
/// `appLocalizationsDelegates` gerado pelo gen-l10n ainda traz
/// os do `flutter_localizations`, que o `material_ui` não lê: os textos
/// prontos do Material (botões dos diálogos, datas) ficariam sem pt-BR.
const appLocalizationsDelegates = <LocalizationsDelegate<Object?>>[
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];

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

  /// O texto de uma falha: `context.failureText(failure)`.
  String failureText(AppFailure failure) => l10n.problems(failure.problems);

  /// O erro do campo [field] numa [ValidationFailure], ou `null`.
  String? fieldError(ValidationFailure? failure, String field) =>
      switch (failure?.errorsFor(field)) {
        final problems? => l10n.problems(problems),
        null => null,
      };
}
