import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/auth/auth_providers.dart';
import 'package:ishinydex/features/auth/data/auth_repository.dart';
import 'package:ishinydex/features/auth/data/token_storage.dart';

import '../../helpers/helpers.dart';

void main() {
  test('tokenStorageProvider padrão é o SecureTokenStorage', () {
    expect(
      createContainer().read(tokenStorageProvider),
      isA<SecureTokenStorage>(),
    );
  });

  test('authRepositoryProvider escolhe fake ou HTTP pelo Env', () {
    expect(
      createContainer(overrides: [envProvider.overrideWithValue(fakeEnv)])
          .read(authRepositoryProvider),
      isA<FakeBackend>(),
    );
    expect(
      createContainer(
        overrides: [
          envProvider.overrideWithValue(
            const Env(apiBaseUrl: 'http://x/api', useFakeApi: false),
          ),
        ],
      ).read(authRepositoryProvider),
      isA<HttpAuthRepository>(),
    );
  });

  group('AuthController', () {
    late InMemoryTokenStorage storage;

    ProviderContainer make({String? token}) {
      storage = InMemoryTokenStorage(token);
      return createContainer(
        overrides: [
          envProvider.overrideWithValue(fakeEnv),
          fakeBackendProvider.overrideWithValue(FakeBackend()),
          tokenStorageProvider.overrideWithValue(storage),
        ],
      );
    }

    test('modo local: já entra, sem login', () async {
      final container = createContainer(
        overrides: [
          envProvider.overrideWithValue(
            const Env(apiBaseUrl: 'x', useFakeApi: false, localData: true),
          ),
          tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
        ],
      );
      expect(
        await container.read(authControllerProvider.future),
        AuthController.localToken,
      );
      expect(container.read(authRepositoryProvider), isA<FakeBackend>());
    });

    test('build lê o token salvo', () async {
      final container = make(token: 'saved');
      expect(await container.read(authControllerProvider.future), 'saved');
    });

    test('login com sucesso salva o token', () async {
      final container = make();
      await container.read(authControllerProvider.future);
      await container
          .read(authControllerProvider.notifier)
          .login(username: 'ash', password: 'x');
      expect(container.read(authControllerProvider).value, 'fake-token-ash');
      expect(await storage.read(), 'fake-token-ash');
    });

    test('login inválido fica em erro', () async {
      final container = make();
      await container.read(authControllerProvider.future);
      await container
          .read(authControllerProvider.notifier)
          .login(username: '', password: '');
      final state = container.read(authControllerProvider);
      expect(state.error, isA<ValidationFailure>());
      expect(state.value, isNull);
    });

    test('logout e expire', () async {
      final container = make(token: 'saved');
      await container.read(authControllerProvider.future);
      final notifier = container.read(authControllerProvider.notifier);
      await notifier.expire();
      expect(container.read(authControllerProvider).value, isNull);
      expect(await storage.read(), isNull);
      // Já deslogado: expire não faz nada.
      await notifier.expire();
      expect(container.read(authControllerProvider).value, isNull);
    });

    test('dioProvider envia o token e desloga em 401', () async {
      final container = make(token: 'saved');
      await container.read(authControllerProvider.future);
      final dio = container.read(dioProvider);
      DioAdapter(dio: dio).onGet(
        'private/',
        (server) => server.reply(401, {'detail': 'x'}),
        headers: {'Authorization': 'Token saved'},
      );
      await expectLater(
        dio.get<void>('private/'),
        throwsA(isA<DioException>()),
      );
      await pumpEventQueue();
      expect(container.read(authControllerProvider).value, isNull);
    });
  });
}
