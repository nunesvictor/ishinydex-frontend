import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Configuração de build, lida via `--dart-define`.
class Env {
  const Env({
    required this.apiBaseUrl,
    required this.useFakeApi,
    this.appVersion = 'dev',
    this.catalogUrl,
    this.spritesBaseUrl = defaultSpritesBaseUrl,
    this.localData = false,
    this.dropboxAppKey,
  });

  /// [base] é o endereço da página (`Uri.base`); serve para resolver uma
  /// `API_BASE_URL` relativa, como `/api` no deploy com nginx.
  factory Env.fromEnvironment({Uri? base}) => Env(
    apiBaseUrl: resolveApiBaseUrl(
      const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:8008/api',
      ),
      base ?? Uri.base,
    ),
    useFakeApi: const bool.fromEnvironment('USE_FAKE_API'),
    // Como no APP_VERSION: sem --dart-define, o lint acha redundante.
    // ignore: avoid_redundant_argument_values
    localData: const bool.fromEnvironment('LOCAL_DATA'),
    // Sem --dart-define, a constante vale 'dev' e o lint a acha redundante;
    // num build com APP_VERSION, não é.
    // ignore: avoid_redundant_argument_values
    appVersion: const String.fromEnvironment(
      'APP_VERSION',
      defaultValue: 'dev',
    ),
    catalogUrl: resolveCatalogUrl(
      const String.fromEnvironment('CATALOG_URL'),
      base ?? Uri.base,
    ),
    // Mesmo caso do APP_VERSION: sem --dart-define, o lint acha redundante.
    // ignore: avoid_redundant_argument_values
    spritesBaseUrl: const String.fromEnvironment(
      'SPRITES_BASE_URL',
      defaultValue: defaultSpritesBaseUrl,
    ),
    dropboxAppKey: _orNull(const String.fromEnvironment('DROPBOX_APP_KEY')),
  );

  static String? _orNull(String raw) => raw.isEmpty ? null : raw;

  /// Pasta `sprites/` do repositório PokeAPI/sprites (libera CORS).
  static const defaultSpritesBaseUrl =
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites';

  final String apiBaseUrl;
  final bool useFakeApi;

  /// Modo local (`LOCAL_DATA`): sem servidor nem login; os dados ficam no
  /// aparelho, e o catálogo (`CATALOG_URL`) é obrigatório.
  final bool localData;

  /// Os repositórios usam o backend em memória: na demonstração e no modo
  /// local.
  bool get usesLocalBackend => useFakeApi || localData;

  /// Versão do build (a tag do repositório, ex. `v1.0.0`), passada pelo
  /// `Dockerfile`; `dev` em builds locais.
  final String appVersion;

  /// Pacote do catálogo (`catalog.json`); com ele, o modo demonstração usa
  /// os dados de referência reais. Relativo à página, como a API.
  final String? catalogUrl;

  /// Base dos caminhos de sprite do catálogo.
  final String spritesBaseUrl;

  /// App key do app do Dropbox de quem publica (pública; o PKCE dispensa o
  /// app secret). Sem ela, o build não tem sincronização: cada cópia do
  /// projeto usa o próprio app do Dropbox, ou nenhum.
  final String? dropboxAppKey;

  /// A sincronização com o Dropbox existe neste build: modo local com
  /// [dropboxAppKey].
  bool get syncAvailable => localData && dropboxAppKey != null;

  /// `CATALOG_URL` vazio → sem catálogo; senão, como a [resolveApiBaseUrl].
  static String? resolveCatalogUrl(String raw, Uri base) =>
      raw.isEmpty ? null : resolveApiBaseUrl(raw, base);

  /// URL absoluta é usada como está; relativa é resolvida contra [base].
  /// Ex.: `/api` em `http://192.168.0.10:8090/#/dexes` →
  /// `http://192.168.0.10:8090/api`.
  static String resolveApiBaseUrl(String raw, Uri base) {
    final uri = Uri.parse(raw);
    return uri.hasScheme ? raw : base.resolveUri(uri).toString();
  }
}

final envProvider = Provider<Env>((ref) => Env.fromEnvironment());
