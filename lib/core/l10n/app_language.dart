import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Idioma escolhido em Ajustes → Idioma (ishinydex-frontend#178).
/// [system] segue o aparelho ([resolveLocale]).
enum AppLanguage {
  system,
  en,
  pt;

  /// O valor guardado ([LanguageStorage]); desconhecido vira [system].
  static AppLanguage parse(String? value) =>
      values.firstWhere((l) => l.name == value, orElse: () => system);

  /// O `locale` do `MaterialApp`: `null` em [system], para o Flutter
  /// escolher pelo aparelho.
  Locale? get locale => switch (this) {
    system => null,
    en => english,
    pt => portuguese,
  };
}

/// Os idiomas da interface. O inglês vem primeiro: é o padrão de quem não
/// fala português.
const english = Locale('en');
const portuguese = Locale('pt', 'BR');
const supportedLocales = <Locale>[english, portuguese];

/// Nome de cada idioma na própria língua (não se traduz: quem errou o
/// idioma precisa reconhecer o seu para voltar). [short] tira a variante,
/// para caber entre parênteses: "Automático (Português)".
String languageName(Locale locale, {bool short = false}) =>
    locale.languageCode != 'pt'
    ? 'English'
    : short
    ? 'Português'
    : 'Português (Brasil)';

/// O idioma do app pelo aparelho: o primeiro português da lista vira pt-BR;
/// sem português, inglês.
Locale resolveLocale(List<Locale>? device) {
  for (final locale in device ?? const <Locale>[]) {
    if (locale.languageCode == 'pt') return portuguese;
  }
  return english;
}

/// Guarda a escolha de idioma. É deste aparelho, como o último dex aberto:
/// não vai para o arquivo de dados nem para o sync.
abstract interface class LanguageStorage {
  Future<AppLanguage> read();
  Future<void> write(AppLanguage language);
}

class PrefsLanguageStorage implements LanguageStorage {
  const PrefsLanguageStorage();

  static const _key = 'app_language';

  @override
  Future<AppLanguage> read() async => AppLanguage.parse(
    (await SharedPreferences.getInstance()).getString(_key),
  );

  @override
  Future<void> write(AppLanguage language) async {
    await (await SharedPreferences.getInstance()).setString(
      _key,
      language.name,
    );
  }
}

class InMemoryLanguageStorage implements LanguageStorage {
  InMemoryLanguageStorage([this._language = AppLanguage.system]);

  AppLanguage _language;

  @override
  Future<AppLanguage> read() async => _language;

  @override
  Future<void> write(AppLanguage language) async => _language = language;
}

final languageStorageProvider = Provider<LanguageStorage>(
  (ref) => const PrefsLanguageStorage(),
);

/// A escolha lida na inicialização (`main.dart`), para o primeiro quadro já
/// sair no idioma certo.
final initialLanguageProvider = Provider<AppLanguage>(
  (ref) => AppLanguage.system,
);

/// O idioma escolhido. Trocar vale na hora (o `MaterialApp` reconstrói com
/// o `locale` novo) e fica guardado no aparelho.
final appLanguageProvider = NotifierProvider<AppLanguageNotifier, AppLanguage>(
  AppLanguageNotifier.new,
);

class AppLanguageNotifier extends Notifier<AppLanguage> {
  @override
  AppLanguage build() => ref.read(initialLanguageProvider);

  Future<void> select(AppLanguage language) async {
    state = language;
    await ref.read(languageStorageProvider).write(language);
  }
}
