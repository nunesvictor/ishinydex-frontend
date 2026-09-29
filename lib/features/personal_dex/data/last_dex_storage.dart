import 'package:ishinydex/features/personal_dex/domain/personal_dex_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda o último PersonalDex aberto, para o app voltar direto nele.
///
/// Não é dado sensível: `shared_preferences` (localStorage na web,
/// NSUserDefaults no iOS) serve nas duas plataformas.
abstract interface class LastDexStorage {
  Future<int?> read();
  Future<void> write(int dexId);
}

class PrefsLastDexStorage implements LastDexStorage {
  static const _key = 'last_dex_id';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<int?> read() async => (await _prefs).getInt(_key);

  @override
  Future<void> write(int dexId) async {
    await (await _prefs).setInt(_key, dexId);
  }
}

class InMemoryLastDexStorage implements LastDexStorage {
  InMemoryLastDexStorage([this._dexId]);

  int? _dexId;

  @override
  Future<int?> read() async => _dexId;

  @override
  Future<void> write(int dexId) async => _dexId = dexId;
}

/// Dex que o app abre ao entrar: o último usado, se ainda existir; senão o
/// único dex do usuário; senão `null` (fica na lista para escolher).
Future<int?> resolveHomeDexId({
  required LastDexStorage storage,
  required PersonalDexRepository repository,
}) async {
  final saved = await storage.read();
  final dexes = await repository.fetchDexes();
  if (dexes.any((d) => d.id == saved)) return saved;
  if (dexes.length == 1) return dexes.single.id;
  return null;
}
