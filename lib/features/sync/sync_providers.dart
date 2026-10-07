import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/web/browser.dart' as browser;
import 'package:ishinydex/features/local/data/local_data_storage.dart';
import 'package:ishinydex/features/local/local_data_providers.dart';
import 'package:ishinydex/features/sync/data/dropbox_client.dart';
import 'package:ishinydex/features/sync/data/sync_session.dart';
import 'package:ishinydex/features/sync/domain/sync_engine.dart';

/// A página do app no navegador: o endereço atual, sair para outro (login
/// do Dropbox) e trocar o da barra sem recarregar. Nos testes, um falso.
class Browser {
  const Browser();

  Uri get page => Uri.base;
  void open(Uri url) => browser.openUrl(url.toString());
  void replace(Uri url) => browser.replaceUrl(url.toString());
}

final browserProvider = Provider<Browser>((ref) => const Browser());

final syncSessionStoreProvider = Provider<SyncSessionStore>(
  (ref) => SyncSessionStore(const PrefsLocalDataStorage(key: 'ishinydex.sync')),
);

/// O Dio do Dropbox: sem a base e os interceptadores da API do servidor.
final syncDioProvider = Provider<Dio>((ref) => Dio());

enum SyncPhase {
  /// Sem Dropbox: os dados ficam só no aparelho.
  off,

  /// Conectado e em dia.
  idle,
  syncing,

  /// Sem conexão: as mudanças ficam no aparelho até a próxima vez.
  offline,

  /// Falhou ([SyncState.error] diz o motivo).
  error,
}

/// Resumos dos dois lados, para a primeira conexão com dados nos dois.
typedef FirstSyncChoice = ({DataFileSummary remote, DataFileSummary local});

class SyncState {
  const SyncState({
    this.phase = SyncPhase.off,
    this.account,
    this.lastSync,
    this.error,
    this.connected = false,
    this.firstSync,
    this.pulls = 0,
  });

  final SyncPhase phase;
  final String? account;
  final DateTime? lastSync;
  final String? error;
  final bool connected;

  /// Primeira conexão com dados nos dois lados: espera a escolha
  /// ([SyncController.resolveFirstSync]).
  final FirstSyncChoice? firstSync;

  /// Quantos syncs trouxeram mudanças de outro aparelho (para avisar: cada
  /// aumento é um aviso).
  final int pulls;

  SyncState copyWith({
    SyncPhase? phase,
    String? account,
    DateTime? lastSync,
    String? error,
    FirstSyncChoice? firstSync,
    int? pulls,
  }) => SyncState(
    phase: phase ?? this.phase,
    account: account ?? this.account,
    lastSync: lastSync ?? this.lastSync,
    error: error,
    connected: connected,
    firstSync: firstSync,
    pulls: pulls ?? this.pulls,
  );
}

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);

/// O sync com o Dropbox visto pela interface: conectar (login), sincronizar
/// (ao abrir o app, depois de mudanças e quando pedido) e desconectar.
class SyncController extends Notifier<SyncState> {
  /// Espera depois de uma mudança antes de sincronizar (uma rajada de
  /// mudanças vira um sync só).
  static const changeDelay = Duration(seconds: 3);

  bool _running = false;
  bool _again = false;
  Timer? _debounce;
  DropboxClient? _client;

  @override
  SyncState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const SyncState();
  }

  Env get _env => ref.read(envProvider);
  SyncSessionStore get _store => ref.read(syncSessionStoreProvider);
  Browser get _browser => ref.read(browserProvider);

  /// A página do app, sem consulta nem rota: para onde o login volta.
  Uri get redirectUri {
    final page = _browser.page;
    return Uri(
      scheme: page.scheme,
      host: page.host,
      port: page.hasPort ? page.port : null,
      path: page.path,
    );
  }

  DropboxLogin _login() => DropboxLogin(
    dio: ref.read(syncDioProvider),
    store: _store,
    appKey: _env.dropboxAppKey!,
    redirectUri: redirectUri.toString(),
  );

  /// Na abertura do app: conclui um login que voltou do Dropbox e
  /// sincroniza. Sem Dropbox neste build, não faz nada.
  Future<void> start() async {
    if (!_env.syncAvailable) return;
    var connecting = false;
    try {
      connecting = await _login().finish(_browser.page);
    } on Exception catch (error) {
      _browser.replace(redirectUri);
      state = SyncState(
        phase: SyncPhase.error,
        // Do login, a mensagem já diz o que houve (recusado, outro aparelho).
        error: error is DropboxAuthException ? error.message : _message(error),
      );
      ref.read(routerProvider).go(Routes.sync);
      return;
    }
    if (connecting) _browser.replace(redirectUri);
    final session = await _store.read();
    if (!session.connected) return;
    ref.read(localDataProvider)!.onChanged = _onLocalChange;
    state = SyncState(
      phase: SyncPhase.idle,
      account: session.account,
      lastSync: session.lastSync,
      connected: true,
    );
    if (connecting) {
      ref.read(routerProvider).go(Routes.sync);
      await _firstSync();
    } else {
      await sync();
    }
  }

  /// Sai para o login do Dropbox (o app recarrega na volta: ver [start]).
  Future<void> connect() async => _browser.open(await _login().begin());

  /// Esquece a conexão; os dados continuam no aparelho e no Dropbox.
  Future<void> disconnect() async {
    _debounce?.cancel();
    _client = null;
    ref.read(localDataProvider)!.onChanged = null;
    await _store.write(const SyncSession());
    state = const SyncState();
  }

  /// Logo depois de conectar: busca o nome da conta e, se houver dados nos
  /// dois lados, pergunta o que fazer ([SyncState.firstSync]).
  Future<void> _firstSync() async {
    state = state.copyWith(phase: SyncPhase.syncing);
    try {
      final client = await _clientFor();
      final account = await client.accountName();
      final session = await _store.read();
      await _store.write(
        SyncSession(refreshToken: session.refreshToken, account: account),
      );
      final remote = await client.download();
      final local = ref.read(localDataProvider)!.currentFile();
      if (remote != null && _hasRecords(local)) {
        final remoteFile = LocalData.read(remote.bytes);
        if (!SyncEngine.sameData(local, remoteFile)) {
          state = state.copyWith(
            phase: SyncPhase.idle,
            account: account,
            firstSync: (
              remote: LocalData.summarize(remoteFile),
              local: LocalData.summarize(local),
            ),
          );
          return;
        }
      }
      state = state.copyWith(account: account);
    } on Exception catch (error) {
      _fail(error);
      return;
    }
    await sync(notify: false);
  }

  static bool _hasRecords(Map<String, dynamic> file) =>
      (file['records'] as Map<String, dynamic>).values.any(
        (list) => (list as List).isNotEmpty,
      );

  /// A escolha da primeira conexão; `null` cancela (desconecta).
  Future<void> resolveFirstSync(FirstSync? mode) async {
    if (mode == null) return await disconnect();
    state = state.copyWith();
    await sync(mode: mode, notify: false);
  }

  void _onLocalChange() {
    _debounce?.cancel();
    _debounce = Timer(changeDelay, () => unawaited(sync()));
  }

  /// Um sync agora. Se já houver um em andamento, outro roda logo depois
  /// (para levar o que mudou no meio). Se trouxer mudanças de outro
  /// aparelho, conta em [SyncState.pulls], exceto com [notify] falso (a
  /// primeira conexão, em que a escolha foi do usuário).
  Future<void> sync({
    FirstSync mode = FirstSync.merge,
    bool notify = true,
  }) async {
    if (!state.connected) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    _debounce?.cancel();
    state = state.copyWith(phase: SyncPhase.syncing);
    try {
      final engine = SyncEngine(
        client: await _clientFor(),
        target: _LocalTarget(ref),
      );
      var current = mode;
      var pulled = false;
      do {
        _again = false;
        // Sem `pulled |= (await ...).pulled`: essa forma quebra o build
        // wasm (o dart2wasm gera um módulo que o wasm-opt não lê).
        final result = await engine.sync(mode: current);
        if (result.pulled) pulled = true;
        current = FirstSync.merge;
      } while (_again);
      final now = DateTime.now();
      final session = await _store.read();
      await _store.write(
        SyncSession(
          refreshToken: session.refreshToken,
          account: session.account,
          lastSync: now,
        ),
      );
      state = state.copyWith(
        phase: SyncPhase.idle,
        lastSync: now,
        pulls: pulled && notify ? state.pulls + 1 : null,
      );
    } on Exception catch (error) {
      _fail(error);
    } finally {
      _running = false;
    }
  }

  Future<DropboxClient> _clientFor() async => _client ??= DropboxClient(
    ref.read(syncDioProvider),
    appKey: _env.dropboxAppKey!,
    refreshToken: (await _store.read()).refreshToken!,
  );

  void _fail(Exception error) {
    if (error is DropboxAuthException) _client = null;
    state = state.copyWith(
      phase: error is DropboxOfflineException
          ? SyncPhase.offline
          : SyncPhase.error,
      error: _message(error),
    );
  }

  static String _message(Exception error) => switch (error) {
    DropboxAuthException() =>
      'O acesso ao Dropbox expirou ou foi revogado. Conecte de novo.',
    DropboxOfflineException() => 'Sem conexão com o Dropbox.',
    FormatException(:final message) => message,
    _ => 'Não foi possível sincronizar ($error).',
  };
}

/// Os dados do aparelho para o [SyncEngine]: o mesmo caminho do importar,
/// que recarrega as telas.
class _LocalTarget implements SyncTarget {
  _LocalTarget(this._ref);

  final Ref _ref;

  @override
  Map<String, dynamic> currentFile() =>
      _ref.read(localDataProvider)!.currentFile();

  @override
  Future<void> apply(Map<String, dynamic> file, {required bool merge}) => _ref
      .read(localDataActionsProvider)
      .import(file, merge: merge, notify: false);
}
