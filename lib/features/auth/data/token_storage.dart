import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Escolhe onde guardar o token.
///
/// - Nativo (iOS): Keychain, via `flutter_secure_storage`.
/// - Web: `localStorage`, via `shared_preferences`. O secure storage da web
///   depende de WebCrypto, que o navegador só libera em HTTPS ou `localhost`;
///   pelo IP da rede (`http://192.168...`) o login falharia.
TokenStorage createTokenStorage({required bool isWeb}) =>
    isWeb ? PrefsTokenStorage() : SecureTokenStorage();

abstract interface class TokenStorage {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'auth_token';

  final FlutterSecureStorage _storage;

  /// Falhas de leitura (ex.: WebCrypto indisponível) contam como deslogado.
  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } on Exception {
      return null;
    }
  }

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> delete() => _storage.delete(key: _key);
}

class PrefsTokenStorage implements TokenStorage {
  static const _key = 'auth_token';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<String?> read() async => (await _prefs).getString(_key);

  @override
  Future<void> write(String token) async {
    await (await _prefs).setString(_key, token);
  }

  @override
  Future<void> delete() async {
    await (await _prefs).remove(_key);
  }
}

class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage([this._token]);

  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> delete() async => _token = null;
}
