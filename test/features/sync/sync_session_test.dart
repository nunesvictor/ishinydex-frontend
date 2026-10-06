import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/features/local/data/local_data_storage.dart';
import 'package:ishinydex/features/sync/data/dropbox_client.dart';
import 'package:ishinydex/features/sync/data/sync_session.dart';

import 'fake_dropbox.dart';

void main() {
  late FakeDropbox dropbox;
  late SyncSessionStore store;

  DropboxLogin login() => DropboxLogin(
    dio: dropbox.dio(),
    store: store,
    appKey: 'chave',
    redirectUri: 'https://x.github.io/app/',
    random: Random(7),
  );

  setUp(() {
    dropbox = FakeDropbox();
    store = SyncSessionStore(InMemoryLocalDataStorage());
  });

  test('sessão: vazia no começo; grava e lê tudo', () async {
    expect((await store.read()).connected, isFalse);
    final lastSync = DateTime.utc(2026, 10, 6, 12);
    await store.write(
      SyncSession(
        refreshToken: 'rt',
        account: 'Victor N.',
        lastSync: lastSync,
        verifier: 'v',
        state: 's',
      ),
    );
    final session = await store.read();
    expect(session.connected, isTrue);
    expect(
      (
        session.refreshToken,
        session.account,
        session.lastSync,
        session.verifier,
        session.state,
      ),
      ('rt', 'Victor N.', lastSync, 'v', 's'),
    );
  });

  test('login: begin guarda o PKCE e finish troca o código', () async {
    final url = await login().begin();
    final pending = await store.read();
    expect(url.queryParameters['state'], pending.state);
    expect(url.queryParameters['redirect_uri'], 'https://x.github.io/app/');
    expect(pending.verifier, isNotNull);

    // Uma página qualquer não é a volta do login.
    expect(await login().finish(Uri.parse('https://x.github.io/app/')), false);
    expect((await store.read()).verifier, pending.verifier);

    final back = Uri.parse(
      'https://x.github.io/app/?code=bom&state=${pending.state}',
    );
    expect(await login().finish(back), isTrue);
    final session = await store.read();
    expect(session.refreshToken, 'rt-${pending.verifier}');
    expect(session.verifier, isNull);
  });

  test('begin mantém uma conexão anterior até o novo login', () async {
    final lastSync = DateTime.utc(2026);
    await store.write(
      SyncSession(refreshToken: 'antigo', account: 'A', lastSync: lastSync),
    );
    await login().begin();
    final session = await store.read();
    expect(
      (session.refreshToken, session.account, session.lastSync),
      ('antigo', 'A', lastSync),
    );
  });

  test('login recusado, state errado ou sem verificador: erro', () async {
    Future<void> expectAuthError(String query, String message) async {
      await expectLater(
        login().finish(Uri.parse('https://x.github.io/app/?$query')),
        throwsA(
          isA<DropboxAuthException>().having(
            (e) => e.message,
            'mensagem',
            contains(message),
          ),
        ),
      );
    }

    await login().begin();
    await expectAuthError(
      'error=access_denied&error_description=Negado',
      'Negado',
    );
    await login().begin();
    await expectAuthError('error=access_denied', 'recusado');
    await login().begin();
    await expectAuthError('code=bom&state=outro', 'não foi iniciado');
    // O verificador já foi usado: a mesma volta de novo também falha.
    await expectAuthError('code=bom&state=x', 'não foi iniciado');
  });
}
