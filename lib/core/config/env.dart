import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Configuração de build, lida via `--dart-define`.
///
/// O app não tem servidor: os dados ficam no aparelho (modo local,
/// `LOCAL_DATA`) ou são de exemplo (demonstração, sem `LOCAL_DATA`).
class Env {
  const Env({
    this.appVersion = 'dev',
    this.catalogUrl,
    this.spritesBaseUrl = defaultSpritesBaseUrl,
    this.localData = false,
    this.dropboxAppKey,
  });

  /// [base] é o endereço da página (`Uri.base`); serve para resolver um
  /// `CATALOG_URL` relativo, como `catalog/catalog.json` no GitHub Pages.
  factory Env.fromEnvironment({Uri? base}) => Env(
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

  /// Modo local (`LOCAL_DATA`): os dados ficam no aparelho, e o catálogo
  /// (`CATALOG_URL`) é obrigatório. Sem ele, a demonstração, com dados de
  /// exemplo que somem ao recarregar.
  final bool localData;

  /// Versão do build (a tag do repositório, ex. `v2.0.0`); `dev` em builds
  /// locais.
  final String appVersion;

  /// Pacote do catálogo (`catalog.json`); com ele, a demonstração usa os
  /// dados de referência reais. Relativo à página.
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

  /// `CATALOG_URL` vazio → sem catálogo; senão, como a [resolveUrl].
  static String? resolveCatalogUrl(String raw, Uri base) =>
      raw.isEmpty ? null : resolveUrl(raw, base);

  /// URL absoluta é usada como está; relativa é resolvida contra [base].
  /// Ex.: `catalog/catalog.json` em `https://x.github.io/app/#/dexes` →
  /// `https://x.github.io/app/catalog/catalog.json`.
  static String resolveUrl(String raw, Uri base) {
    final uri = Uri.parse(raw);
    return uri.hasScheme ? raw : base.resolveUri(uri).toString();
  }
}

final envProvider = Provider<Env>((ref) => Env.fromEnvironment());
