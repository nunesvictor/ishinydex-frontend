import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O tema escolhido em Ajustes → Aparência (#273): o do aparelho
/// ([ThemeMode.system], o padrão), claro ou escuro. Como o idioma, é deste
/// aparelho: não vai para o arquivo de dados nem para o sync.
ThemeMode parseThemeMode(String? value) => ThemeMode.values.firstWhere(
  (mode) => mode.name == value,
  orElse: () => ThemeMode.system,
);

/// Guarda a escolha do tema.
abstract interface class ThemeModeStorage {
  Future<ThemeMode> read();
  Future<void> write(ThemeMode mode);
}

/// No `shared_preferences`, que na web fica no `localStorage` como
/// `flutter.app_theme`: o `web/index.html` lê de lá antes do app carregar,
/// para o fundo, o splash e a barra de status já saírem no tema certo.
class PrefsThemeModeStorage implements ThemeModeStorage {
  const PrefsThemeModeStorage();

  static const key = 'app_theme';

  @override
  Future<ThemeMode> read() async =>
      parseThemeMode((await SharedPreferences.getInstance()).getString(key));

  @override
  Future<void> write(ThemeMode mode) async {
    await (await SharedPreferences.getInstance()).setString(key, mode.name);
  }
}

class InMemoryThemeModeStorage implements ThemeModeStorage {
  InMemoryThemeModeStorage([this._mode = ThemeMode.system]);

  ThemeMode _mode;

  @override
  Future<ThemeMode> read() async => _mode;

  @override
  Future<void> write(ThemeMode mode) async => _mode = mode;
}

final themeModeStorageProvider = Provider<ThemeModeStorage>(
  (ref) => const PrefsThemeModeStorage(),
);

/// A escolha lida na inicialização (`main.dart`), para o primeiro quadro já
/// sair no tema certo.
final initialThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.system);

/// O tema escolhido. Trocar vale na hora (o `MaterialApp` reconstrói com o
/// `themeMode` novo) e fica guardado no aparelho.
final appThemeModeProvider = NotifierProvider<AppThemeModeNotifier, ThemeMode>(
  AppThemeModeNotifier.new,
);

class AppThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(initialThemeModeProvider);

  Future<void> select(ThemeMode mode) async {
    state = mode;
    await ref.read(themeModeStorageProvider).write(mode);
  }
}
