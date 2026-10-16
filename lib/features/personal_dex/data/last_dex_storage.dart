import 'package:ishinydex/features/personal_dex/domain/personal_dex_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda o último PersonalDex aberto, para o app voltar direto nele.
///
/// Não é dado sensível: `shared_preferences` (localStorage na web,
/// NSUserDefaults no iOS) serve nas duas plataformas.
abstract interface class LastDexStorage {
  Future<int?> read();
  Future<void> write(int dexId);

  /// O shiny dex escolhido na aba Caçadas (#246), à parte do último aberto.
  Future<int?> readHunts();
  Future<void> writeHunts(int dexId);

  /// Se a lista de boxes ao lado da grade fica aberta (#302); `null` até a
  /// primeira escolha (fechada).
  Future<bool?> readBoxList();
  Future<void> writeBoxList({required bool open});
}

class PrefsLastDexStorage implements LastDexStorage {
  static const _key = 'last_dex_id';
  static const _huntsKey = 'last_hunts_dex_id';
  static const _boxListKey = 'box_list_open';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<int?> read() async => (await _prefs).getInt(_key);

  @override
  Future<void> write(int dexId) async {
    await (await _prefs).setInt(_key, dexId);
  }

  @override
  Future<int?> readHunts() async => (await _prefs).getInt(_huntsKey);

  @override
  Future<void> writeHunts(int dexId) async {
    await (await _prefs).setInt(_huntsKey, dexId);
  }

  @override
  Future<bool?> readBoxList() async => (await _prefs).getBool(_boxListKey);

  @override
  Future<void> writeBoxList({required bool open}) async {
    await (await _prefs).setBool(_boxListKey, open);
  }
}

class InMemoryLastDexStorage implements LastDexStorage {
  InMemoryLastDexStorage([this._dexId]);

  int? _dexId;
  int? _huntsDexId;
  bool? _boxListOpen;

  @override
  Future<int?> read() async => _dexId;

  @override
  Future<void> write(int dexId) async => _dexId = dexId;

  @override
  Future<int?> readHunts() async => _huntsDexId;

  @override
  Future<void> writeHunts(int dexId) async => _huntsDexId = dexId;

  @override
  Future<bool?> readBoxList() async => _boxListOpen;

  @override
  Future<void> writeBoxList({required bool open}) async => _boxListOpen = open;
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
