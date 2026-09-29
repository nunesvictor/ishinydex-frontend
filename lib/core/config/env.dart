import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Configuração de build, lida via `--dart-define`.
class Env {
  const Env({required this.apiBaseUrl, required this.useFakeApi});

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
  );

  final String apiBaseUrl;
  final bool useFakeApi;

  /// URL absoluta é usada como está; relativa é resolvida contra [base].
  /// Ex.: `/api` em `http://192.168.0.10:8090/#/dexes` →
  /// `http://192.168.0.10:8090/api`.
  static String resolveApiBaseUrl(String raw, Uri base) {
    final uri = Uri.parse(raw);
    return uri.hasScheme ? raw : base.resolveUri(uri).toString();
  }
}

final envProvider = Provider<Env>((ref) => Env.fromEnvironment());
