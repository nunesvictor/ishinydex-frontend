import 'package:shared_preferences/shared_preferences.dart';

/// Formato da data de captura no formulário do espécime.
enum CaptureDateFormat {
  /// Como no Pokémon HOME: mm/dd/aaaa (padrão).
  home,

  /// O formato de data do idioma do app (pt-BR: dd/mm/aaaa).
  locale,
}

/// Guarda a preferência de formato. Não é dado sensível: `shared_preferences`
/// serve na web e no iOS.
abstract interface class DateFormatStorage {
  Future<CaptureDateFormat?> read();
  Future<void> write(CaptureDateFormat format);
}

class PrefsDateFormatStorage implements DateFormatStorage {
  static const _key = 'capture_date_format';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<CaptureDateFormat?> read() async {
    final name = (await _prefs).getString(_key);
    return CaptureDateFormat.values.where((f) => f.name == name).firstOrNull;
  }

  @override
  Future<void> write(CaptureDateFormat format) async {
    await (await _prefs).setString(_key, format.name);
  }
}

class InMemoryDateFormatStorage implements DateFormatStorage {
  InMemoryDateFormatStorage([this._format]);

  CaptureDateFormat? _format;

  @override
  Future<CaptureDateFormat?> read() async => _format;

  @override
  Future<void> write(CaptureDateFormat format) async => _format = format;
}
