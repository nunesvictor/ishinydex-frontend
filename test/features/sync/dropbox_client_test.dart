import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/features/sync/data/dropbox_client.dart';
import 'package:ishinydex/features/sync/data/pkce.dart';

import 'fake_dropbox.dart';

void main() {
  late FakeDropbox dropbox;
  late DateTime now;

  DropboxClient client() => DropboxClient(
    dropbox.dio(),
    appKey: 'chave',
    refreshToken: 'rt',
    now: () => now,
  );

  setUp(() {
    dropbox = FakeDropbox();
    now = DateTime(2026, 10, 6, 12);
  });

  test('PKCE: o desafio é o SHA-256 do verificador (exemplo da RFC 7636)', () {
    final pkce = Pkce('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk');
    expect(pkce.challenge, 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM');
    final generated = Pkce.generate(Random(1));
    expect(generated.verifier, hasLength(43));
    expect(generated.verifier, isNot(contains('=')));
    expect(randomToken(16), hasLength(22));
  });

  test('URL de login com PKCE, offline e o retorno para o app', () {
    final url = DropboxClient.authorizeUrl(
      appKey: 'chave',
      redirectUri: 'https://x.github.io/app/',
      challenge: 'desafio',
      state: 'estado',
    );
    expect(url.host, 'www.dropbox.com');
    expect(url.queryParameters, {
      'client_id': 'chave',
      'response_type': 'code',
      'code_challenge': 'desafio',
      'code_challenge_method': 'S256',
      'token_access_type': 'offline',
      'redirect_uri': 'https://x.github.io/app/',
      'state': 'estado',
    });
  });

  test(
    'troca o código pelo refresh token; código ruim é erro de login',
    () async {
      final token = await DropboxClient.exchangeCode(
        dropbox.dio(),
        appKey: 'chave',
        code: 'bom',
        verifier: 'v',
        redirectUri: 'r',
      );
      expect(token, 'rt-v');
      await expectLater(
        DropboxClient.exchangeCode(
          dropbox.dio(),
          appKey: 'chave',
          code: 'velho',
          verifier: 'v',
          redirectUri: 'r',
        ),
        throwsA(
          isA<DropboxAuthException>().having(
            (e) => e.toString(),
            'mensagem',
            'refresh token is invalid or revoked',
          ),
        ),
      );
    },
  );

  test('sem arquivo: download é null; envia, baixa e devolve a rev', () async {
    final c = client();
    expect(await c.download(), isNull);
    final rev = await c.upload(utf8.encode('{"a":1}'));
    expect(rev, dropbox.rev);
    final file = await c.download();
    expect(file?.rev, rev);
    expect(utf8.decode(file!.bytes), '{"a":1}');
    // O arquivo vai como bytes, com o tipo que o Dropbox exige.
    final upload = dropbox.requests.firstWhere(
      (r) => r.uri.path.endsWith('upload'),
    );
    expect(upload.contentType, 'application/octet-stream');
    expect(
      jsonDecode(upload.headers['Dropbox-API-Arg'] as String),
      containsPair('path', DropboxClient.path),
    );
  });

  test(
    'envio condicional: rev antiga ou arquivo existente é conflito',
    () async {
      final c = client();
      final first = await c.upload(utf8.encode('1'));
      await c.upload(utf8.encode('2'), rev: first);
      await expectLater(
        c.upload(utf8.encode('3'), rev: first),
        throwsA(isA<DropboxConflictException>()),
      );
      await expectLater(
        c.upload(utf8.encode('3')),
        throwsA(isA<DropboxConflictException>()),
      );
      await c.upload(utf8.encode('4'), overwrite: true);
      expect(utf8.decode(dropbox.file!), '4');
    },
  );

  test('o token de acesso é reaproveitado até perto de expirar', () async {
    final c = client();
    await c.download();
    await c.download();
    expect(dropbox.tokenRefreshes, 1);
    now = now.add(const Duration(hours: 3, minutes: 59, seconds: 30));
    await c.download();
    expect(dropbox.tokenRefreshes, 2);
  });

  test('nome da conta', () async {
    expect(await client().accountName(), 'Victor N.');
  });

  test('refresh token revogado ou acesso recusado: erro de login', () async {
    dropbox.revoked = true;
    await expectLater(
      client().download(),
      throwsA(isA<DropboxAuthException>()),
    );
    dropbox
      ..revoked = false
      ..forced = (
        status: 401,
        body: {'error_summary': 'expired_access_token/'},
      );
    await expectLater(
      client().download(),
      throwsA(
        isA<DropboxAuthException>().having(
          (e) => e.message,
          'mensagem',
          'expired_access_token/',
        ),
      ),
    );
  });

  test('sem conexão e erros inesperados', () async {
    dropbox.offline = true;
    await expectLater(
      client().download(),
      throwsA(isA<DropboxOfflineException>()),
    );
    dropbox
      ..offline = false
      ..forced = (status: 500, body: 'fora do ar');
    final c = client();
    await expectLater(
      c.download(),
      throwsA(
        isA<DropboxException>().having(
          (e) => e.toString(),
          'mensagem',
          '500 fora do ar',
        ),
      ),
    );
    dropbox.forced = (status: 400, body: {'error_description': 'ruim'});
    await expectLater(
      c.upload(utf8.encode('x')),
      throwsA(
        isA<DropboxException>().having(
          (e) => e.message,
          'mensagem',
          '400 ruim',
        ),
      ),
    );
    await c.upload(utf8.encode('x'));
    dropbox
      ..forced = (status: 409, body: 'download recusado')
      ..forcedOn = 'download';
    await expectLater(
      c.download(),
      throwsA(
        isA<DropboxException>().having(
          (e) => e.message,
          'mensagem',
          '409 download recusado',
        ),
      ),
    );
    dropbox.forced = (status: 400, body: {'outro': 1});
    await expectLater(
      c.accountName(),
      throwsA(isA<DropboxException>().having((e) => e.message, 'm', '400')),
    );
  });

  test('token: falha sem resposta é sem conexão', () async {
    dropbox.offline = true;
    await expectLater(
      DropboxClient.exchangeCode(
        dropbox.dio(),
        appKey: 'chave',
        code: 'bom',
        verifier: 'v',
        redirectUri: 'r',
      ),
      throwsA(isA<DropboxOfflineException>()),
    );
  });
}
