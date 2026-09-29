import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/network/api_client.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/auth/data/auth_repository.dart';
import 'package:ishinydex/features/auth/data/token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => createTokenStorage(isWeb: kIsWeb),
);

final dioProvider = Provider<Dio>((ref) {
  final env = ref.watch(envProvider);
  return createDio(
    baseUrl: env.apiBaseUrl,
    readToken: () => ref.read(authControllerProvider).value,
    onUnauthorized: () => ref.read(authControllerProvider.notifier).expire(),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (ref.watch(envProvider).useFakeApi) {
    return ref.watch(fakeBackendProvider);
  }
  return HttpAuthRepository(ref.watch(dioProvider));
});

/// Token atual: `null` quando deslogado.
final authControllerProvider = AsyncNotifierProvider<AuthController, String?>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<String?> {
  TokenStorage get _storage => ref.read(tokenStorageProvider);

  @override
  Future<String?> build() => _storage.read();

  Future<void> login({
    required String username,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final token = await ref
          .read(authRepositoryProvider)
          .login(username: username, password: password);
      await _storage.write(token);
      return token;
    });
  }

  Future<void> logout() async {
    await _storage.delete();
    state = const AsyncData(null);
  }

  /// Chamado quando a API responde 401.
  Future<void> expire() async {
    if (state.value == null) return;
    await logout();
  }
}
