import 'package:shared_preferences/shared_preferences.dart';

/// Onde o modo local guarda o arquivo de dados (um JSON).
abstract interface class LocalDataStorage {
  Future<String?> read();
  Future<void> write(String data);
}

/// `shared_preferences`: no navegador, o `localStorage` (os dados, ~0,7 MB,
/// cabem no limite); no app instalado da Tela de Início do iOS, o
/// armazenamento é persistente (ishinydex#53).
class PrefsLocalDataStorage implements LocalDataStorage {
  static const _key = 'ishinydex.data';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<String?> read() async => (await _prefs).getString(_key);

  @override
  Future<void> write(String data) async {
    await (await _prefs).setString(_key, data);
  }
}

class InMemoryLocalDataStorage implements LocalDataStorage {
  InMemoryLocalDataStorage([this.data]);

  String? data;

  @override
  Future<String?> read() async => data;

  @override
  Future<void> write(String data) async => this.data = data;
}
