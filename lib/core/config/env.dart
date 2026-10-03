import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Configuração de build, lida via `--dart-define`.
class Env {
  const Env({
    required this.apiBaseUrl,
    required this.useFakeApi,
    this.appVersion = 'dev',
    this.catalogUrl,
    this.spritesBaseUrl = defaultSpritesBaseUrl,
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
  );

  /// Pasta `sprites/` do repositório PokeAPI/sprites (libera CORS).
  static const defaultSpritesBaseUrl =
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites';

  final String apiBaseUrl;
  final bool useFakeApi;

  /// Versão do build (a tag do repositório, ex. `v1.0.0`), passada pelo
  /// `Dockerfile`; `dev` em builds locais.
  final String appVersion;

  /// Pacote do catálogo (`catalog.json`); com ele, o modo demonstração usa
  /// os dados de referência reais. Relativo à página, como a API.
  final String? catalogUrl;

  /// Base dos caminhos de sprite do catálogo.
  final String spritesBaseUrl;

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
