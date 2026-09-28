import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Configuração de build, lida via `--dart-define`.
class Env {
  const Env({required this.apiBaseUrl, required this.useFakeApi});

  factory Env.fromEnvironment() => const Env(
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8008/api',
    ),
    useFakeApi: bool.fromEnvironment('USE_FAKE_API'),
  );

  final String apiBaseUrl;
  final bool useFakeApi;
}

final envProvider = Provider<Env>((ref) => Env.fromEnvironment());
