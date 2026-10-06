import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:ishinydex/features/local/data/local_data_storage.dart';
import 'package:ishinydex/features/sync/data/dropbox_client.dart';
import 'package:ishinydex/features/sync/data/pkce.dart';

/// O que o sync guarda no aparelho, separado do arquivo de dados: a conexão
/// com o Dropbox ([refreshToken]), o nome da conta, a hora do último sync
/// e, durante o login, o verificador do PKCE e o `state`.
class SyncSession {
  const SyncSession({
    this.refreshToken,
    this.account,
    this.lastSync,
    this.verifier,
    this.state,
  });

  factory SyncSession.fromJson(Map<String, dynamic> json) => SyncSession(
    refreshToken: json['refreshToken'] as String?,
    account: json['account'] as String?,
    lastSync: switch (json['lastSync']) {
      final String date => DateTime.parse(date),
      _ => null,
    },
    verifier: json['verifier'] as String?,
    state: json['state'] as String?,
  );

  final String? refreshToken;
  final String? account;
  final DateTime? lastSync;
  final String? verifier;
  final String? state;

  bool get connected => refreshToken != null;

  Map<String, dynamic> toJson() => {
    'refreshToken': ?refreshToken,
    'account': ?account,
    'lastSync': ?lastSync?.toUtc().toIso8601String(),
    'verifier': ?verifier,
    'state': ?state,
  };
}

/// Lê e grava a [SyncSession] (no `shared_preferences`, numa chave própria).
class SyncSessionStore {
  SyncSessionStore(this.storage);

  final LocalDataStorage storage;

  Future<SyncSession> read() async {
    final raw = await storage.read();
    if (raw == null) return const SyncSession();
    return SyncSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> write(SyncSession session) =>
      storage.write(jsonEncode(session.toJson()));
}

/// O login do Dropbox, em duas metades: [begin] gera o PKCE, guarda o
/// verificador e devolve a URL do Dropbox; o app sai para ela. O Dropbox
/// volta para [redirectUri] com `?code=...&state=...`, e [finish] troca o
/// código pelo refresh token.
///
/// O verificador fica no armazenamento do aparelho porque o app inteiro
/// recarrega na volta. No iPhone e no iPad, o login volta para o app da
/// Tela de Início, que tem o mesmo armazenamento (ishinydex#53).
class DropboxLogin {
  DropboxLogin({
    required this.dio,
    required this.store,
    required this.appKey,
    required this.redirectUri,
    this.random,
  });

  final Dio dio;
  final SyncSessionStore store;
  final String appKey;
  final String redirectUri;
  final Random? random;

  Future<Uri> begin() async {
    final pkce = Pkce.generate(random);
    final state = randomToken(16, random);
    final session = await store.read();
    await store.write(
      SyncSession(
        refreshToken: session.refreshToken,
        account: session.account,
        lastSync: session.lastSync,
        verifier: pkce.verifier,
        state: state,
      ),
    );
    return DropboxClient.authorizeUrl(
      appKey: appKey,
      redirectUri: redirectUri,
      challenge: pkce.challenge,
      state: state,
    );
  }

  /// Conclui o login se [page] é a volta do Dropbox; `false` se não é.
  /// Login recusado, `state` que não confere ou volta sem o verificador
  /// (login iniciado em outro armazenamento) → [DropboxAuthException].
  Future<bool> finish(Uri page) async {
    final params = page.queryParameters;
    final code = params['code'];
    final error = params['error'];
    if (code == null && error == null) return false;
    final session = await store.read();
    // O verificador só serve uma vez, desse login dar certo ou não.
    await store.write(const SyncSession());
    if (error != null) {
      throw DropboxAuthException(
        params['error_description'] ?? 'O login no Dropbox foi recusado.',
      );
    }
    final verifier = session.verifier;
    if (verifier == null || params['state'] != session.state) {
      throw const DropboxAuthException(
        'O login no Dropbox não foi iniciado neste aparelho. Tente de novo.',
      );
    }
    final refreshToken = await DropboxClient.exchangeCode(
      dio,
      appKey: appKey,
      code: code!,
      verifier: verifier,
      redirectUri: redirectUri,
    );
    await store.write(SyncSession(refreshToken: refreshToken));
    return true;
  }
}
