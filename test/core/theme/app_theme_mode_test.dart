import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/theme/app_theme_mode.dart';
import 'package:ishinydex/features/catalog/presentation/boot_failure_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/helpers.dart';

void main() {
  test('o valor guardado vira a escolha; desconhecido, Automático', () {
    expect(parseThemeMode('light'), ThemeMode.light);
    expect(parseThemeMode('dark'), ThemeMode.dark);
    expect(parseThemeMode(null), ThemeMode.system);
    expect(parseThemeMode('sepia'), ThemeMode.system);
  });

  test('a escolha fica no aparelho (shared_preferences)', () async {
    SharedPreferences.setMockInitialValues({});
    const storage = PrefsThemeModeStorage();
    expect(await storage.read(), ThemeMode.system);
    await storage.write(ThemeMode.dark);
    expect(await storage.read(), ThemeMode.dark);
    // A chave que o web/index.html lê (com o prefixo "flutter.").
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefsThemeModeStorage.key), 'dark');
  });

  test('escolher troca o tema e guarda', () async {
    final storage = InMemoryThemeModeStorage();
    final container = createContainer(
      overrides: [
        initialThemeModeProvider.overrideWithValue(ThemeMode.light),
        themeModeStorageProvider.overrideWithValue(storage),
      ],
    );
    expect(container.read(appThemeModeProvider), ThemeMode.light);
    await container.read(appThemeModeProvider.notifier).select(ThemeMode.dark);
    expect(container.read(appThemeModeProvider), ThemeMode.dark);
    expect(await storage.read(), ThemeMode.dark);
    // Sem override: o do aparelho e o shared_preferences.
    final defaults = createContainer();
    expect(defaults.read(appThemeModeProvider), ThemeMode.system);
    expect(
      defaults.read(themeModeStorageProvider),
      isA<PrefsThemeModeStorage>(),
    );
  });

  testWidgets('a tela de erro do boot também sai no tema escolhido', (
    tester,
  ) async {
    await tester.pumpWidget(
      BootFailureApp(
        error: Exception('x'),
        onRetry: () {},
        themeMode: ThemeMode.dark,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.dark,
    );
  });
}
