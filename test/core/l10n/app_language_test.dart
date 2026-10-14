import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/l10n/app_language.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/helpers.dart';

void main() {
  test('o valor guardado vira a escolha; desconhecido, Automático', () {
    expect(AppLanguage.parse('en'), AppLanguage.en);
    expect(AppLanguage.parse('pt'), AppLanguage.pt);
    expect(AppLanguage.parse(null), AppLanguage.system);
    expect(AppLanguage.parse('klingon'), AppLanguage.system);
    expect(AppLanguage.system.locale, isNull);
    expect(AppLanguage.en.locale, english);
    expect(AppLanguage.pt.locale, portuguese);
  });

  test('pelo aparelho: português vira pt-BR; o resto, inglês', () {
    expect(resolveLocale([const Locale('pt', 'PT')]), portuguese);
    expect(
      resolveLocale([const Locale('fr'), const Locale('pt', 'BR')]),
      portuguese,
    );
    expect(resolveLocale([const Locale('ja')]), english);
    expect(resolveLocale(null), english);
  });

  test('nome do idioma na própria língua', () {
    expect(languageName(english), 'English');
    expect(languageName(portuguese), 'Português (Brasil)');
    expect(languageName(portuguese, short: true), 'Português');
  });

  test('a escolha fica no aparelho (shared_preferences)', () async {
    SharedPreferences.setMockInitialValues({});
    const storage = PrefsLanguageStorage();
    expect(await storage.read(), AppLanguage.system);
    await storage.write(AppLanguage.en);
    expect(await storage.read(), AppLanguage.en);
  });

  test('escolher troca o idioma e guarda', () async {
    final storage = InMemoryLanguageStorage();
    final container = createContainer(
      overrides: [
        initialLanguageProvider.overrideWithValue(AppLanguage.pt),
        languageStorageProvider.overrideWithValue(storage),
      ],
    );
    expect(container.read(appLanguageProvider), AppLanguage.pt);
    await container.read(appLanguageProvider.notifier).select(AppLanguage.en);
    expect(container.read(appLanguageProvider), AppLanguage.en);
    expect(await storage.read(), AppLanguage.en);
    // Sem override: Automático e o shared_preferences.
    final defaults = createContainer();
    expect(defaults.read(appLanguageProvider), AppLanguage.system);
    expect(defaults.read(languageStorageProvider), isA<PrefsLanguageStorage>());
  });

  for (final (locale, language, text) in [
    (english, 'en', 'Settings · Grass'),
    (portuguese, 'pt-BR', 'Ajustes · Planta'),
  ]) {
    testWidgets('textos e rótulos do catálogo em $language', (tester) async {
      late BuildContext captured;
      await pumpWidgetApp(
        tester,
        Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
        locale: locale,
      );
      final type = captured.catalogText('Planta', const {
        'en': 'Grass',
        'pt-BR': 'Planta',
      });
      expect(captured.catalogLanguage, language);
      expect('${captured.l10n.settingsTitle} · $type', text);
      // Catálogo antigo: o rótulo em pt-BR.
      expect(captured.catalogText('Planta', const {}), 'Planta');
    });
  }
}
