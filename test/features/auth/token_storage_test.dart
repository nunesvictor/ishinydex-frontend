import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/features/auth/data/token_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage;

void main() {
  test('InMemoryTokenStorage', () async {
    final storage = InMemoryTokenStorage();
    expect(await storage.read(), isNull);
    await storage.write('t');
    expect(await storage.read(), 't');
    await storage.delete();
    expect(await storage.read(), isNull);
  });

  group('SecureTokenStorage', () {
    late _MockSecureStorage secure;
    late SecureTokenStorage storage;

    setUp(() {
      secure = _MockSecureStorage();
      storage = SecureTokenStorage(secure);
    });

    test('lê, grava e apaga pela chave auth_token', () async {
      when(() => secure.read(key: 'auth_token')).thenAnswer((_) async => 't');
      when(() => secure.write(key: 'auth_token', value: 'n'))
          .thenAnswer((_) async {});
      when(() => secure.delete(key: 'auth_token')).thenAnswer((_) async {});
      expect(await storage.read(), 't');
      await storage.write('n');
      await storage.delete();
      verify(() => secure.write(key: 'auth_token', value: 'n')).called(1);
      verify(() => secure.delete(key: 'auth_token')).called(1);
    });

    test('falha na leitura conta como deslogado', () async {
      when(() => secure.read(key: 'auth_token')).thenThrow(Exception('x'));
      expect(await storage.read(), isNull);
    });

    test('construtor padrão', () {
      expect(SecureTokenStorage(), isA<TokenStorage>());
    });
  });

  test('PrefsTokenStorage usa o localStorage (shared_preferences)', () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'salvo'});
    final storage = PrefsTokenStorage();
    expect(await storage.read(), 'salvo');
    await storage.write('novo');
    expect(await storage.read(), 'novo');
    await storage.delete();
    expect(await storage.read(), isNull);
  });

  test('createTokenStorage escolhe pela plataforma', () {
    expect(createTokenStorage(isWeb: true), isA<PrefsTokenStorage>());
    expect(createTokenStorage(isWeb: false), isA<SecureTokenStorage>());
  });
}
