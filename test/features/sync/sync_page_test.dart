import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/local/data/local_data_storage.dart';
import 'package:ishinydex/features/local/data/local_store.dart';
import 'package:ishinydex/features/local/local_data_providers.dart';
import 'package:ishinydex/features/local/presentation/local_data_tiles.dart';
import 'package:ishinydex/features/sync/data/sync_session.dart';
import 'package:ishinydex/features/sync/presentation/sync_page.dart';
import 'package:ishinydex/features/sync/sync_providers.dart';

import '../../fixtures/catalog_fixture.dart';
import '../../helpers/helpers.dart';
import 'fake_dropbox.dart';

const _page = 'https://x.github.io/app/';

const _syncEnv = Env(localData: true, dropboxAppKey: 'chave');

class _FakeBrowser implements Browser {
  @override
  Uri page = Uri.parse(_page);
  final opened = <Uri>[];
  final replaced = <Uri>[];

  @override
  void open(Uri url) => opened.add(url);

  @override
  void replace(Uri url) => replaced.add(url);
}

void main() {
  late FakeDropbox dropbox;
  late _FakeBrowser browser;
  late SyncSessionStore sessions;
  late FakeBackend backend;
  late LocalData data;

  setUp(() {
    dropbox = FakeDropbox();
    browser = _FakeBrowser();
    sessions = SyncSessionStore(InMemoryLocalDataStorage());
    backend = FakeBackend.seeded();
    data = LocalData(
      store: LocalStore(InMemoryLocalDataStorage()),
      backend: backend,
      catalogVersion: 'catalog-x',
    );
  });

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

  Future<void> pumpApp(
    WidgetTester tester, {
    Env env = _syncEnv,
    Size size = compactSize,
  }) async {
    await pumpFullApp(
      tester,
      backend: backend,
      size: size,
      env: env,
      overrides: [
        localDataProvider.overrideWithValue(data),
        syncSessionStoreProvider.overrideWithValue(sessions),
        syncDioProvider.overrideWithValue(dropbox.dio()),
        browserProvider.overrideWithValue(browser),
      ],
    );
    // O start() roda numa microtask, depois do primeiro quadro.
    await tester.pumpAndSettle();
  }

  Future<void> openSync(WidgetTester tester) async {
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sincronização'));
    await tester.pumpAndSettle();
  }

  /// Volta do login do Dropbox: o app abre com `?code=...&state=...`.
  Future<void> returnFromLogin(WidgetTester tester) async {
    final url = await DropboxLogin(
      dio: dropbox.dio(),
      store: sessions,
      appKey: 'chave',
      redirectUri: _page,
    ).begin();
    browser.page = Uri.parse(
      '$_page?code=bom&state=${url.queryParameters['state']}',
    );
    await pumpApp(tester);
  }

  /// Já conectado (o login foi em outra abertura do app).
  Future<void> connected() =>
      sessions.write(const SyncSession(refreshToken: 'rt', account: 'V.'));

  Map<String, dynamic> otherDevice() {
    final other = LocalData(
      store: LocalStore(InMemoryLocalDataStorage()),
      backend: FakeBackend.local(
        Catalog.fromJson(catalogJson(), spriteBase: Env.defaultSpritesBaseUrl),
      )..addTrainer(name: 'Misty', trainerId: '222222'),
      catalogVersion: 'catalog-x',
    );
    return other.currentFile();
  }

  for (final size in [compactSize, expandedSize]) {
    testWidgets('desligada: explica e conecta ao Dropbox ($size)', (
      tester,
    ) async {
      await pumpApp(tester, size: size);
      await openSync(tester);
      expect(find.textContaining('só neste aparelho'), findsWidgets);
      expect(find.text('opcional'), findsOneWidget);
      await tester.tap(find.text('Conectar ao Dropbox'));
      await tester.pumpAndSettle();
      final url = browser.opened.single;
      expect(url.host, 'www.dropbox.com');
      expect(url.queryParameters['redirect_uri'], _page);
      expect((await sessions.read()).verifier, isNotNull);
    });
  }

  testWidgets('sem app key ou fora do modo local, não há sincronização', (
    tester,
  ) async {
    await pumpApp(tester, env: const Env(localData: true));
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Exportar dados'), findsOneWidget);
    expect(find.text('Sincronização'), findsNothing);
  });

  testWidgets('volta do login sem dados no Dropbox: envia os daqui', (
    tester,
  ) async {
    await returnFromLogin(tester);
    expect(browser.replaced.single.toString(), _page);
    expect(find.text('Sincronização'), findsOneWidget);
    expect(find.text('Dropbox de Victor N.'), findsOneWidget);
    expect(find.text('Sincronizado agora há pouco'), findsOneWidget);
    expect(dropbox.content?['kind'], LocalStore.kind);
    expect((await sessions.read()).account, 'Victor N.');
  });

  testWidgets('primeira conexão com dados nos dois lados: pergunta', (
    tester,
  ) async {
    dropbox.put(otherDevice());
    await returnFromLogin(tester);
    expect(find.text('Já há dados no Dropbox'), findsOneWidget);
    expect(find.text('No Dropbox'), findsWidgets);
    await tester.tap(find.text('Usar só os do Dropbox'));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect([for (final t in await backend.fetchTrainers()) t.name], ['Misty']);
    expect(find.textContaining('Sincronizado'), findsOneWidget);
  });

  testWidgets('primeira conexão: cancelar desconecta', (tester) async {
    dropbox.put(otherDevice());
    await returnFromLogin(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Conectar ao Dropbox'), findsOneWidget);
    expect((await sessions.read()).connected, isFalse);
  });

  testWidgets('primeira conexão sem diferença: só sincroniza', (tester) async {
    dropbox.put(data.currentFile());
    await returnFromLogin(tester);
    expect(find.text('Já há dados no Dropbox'), findsNothing);
    expect(find.textContaining('Sincronizado'), findsOneWidget);
  });

  testWidgets('primeira conexão: falha ao buscar a conta', (tester) async {
    dropbox
      ..forced = (status: 500, body: 'fora do ar')
      ..forcedOn = 'get_current_account';
    await returnFromLogin(tester);
    expect(find.text('Não foi possível sincronizar'), findsOneWidget);
    expect(
      find.text('Não foi possível sincronizar (500 fora do ar).'),
      findsOneWidget,
    );
  });

  testWidgets('login recusado: volta para Sincronização com o motivo', (
    tester,
  ) async {
    browser.page = Uri.parse('$_page?error=access_denied');
    await pumpApp(tester);
    expect(browser.replaced.single.toString(), _page);
    expect(find.text('Conectar ao Dropbox'), findsOneWidget);
    expect(find.text('O login no Dropbox foi recusado.'), findsOneWidget);
  });

  testWidgets('conectado: sincroniza ao abrir e mostra na lista de dexes', (
    tester,
  ) async {
    await connected();
    await pumpApp(tester);
    expect(dropbox.file, isNotNull);
    await tester.tap(find.text('PersonalDex').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sincronizado agora há pouco'));
    await tester.pumpAndSettle();
    expect(find.text('Dropbox de V.'), findsOneWidget);
  });

  testWidgets('mudança no aparelho: sincroniza alguns segundos depois', (
    tester,
  ) async {
    await connected();
    await pumpApp(tester);
    final rev = dropbox.rev;
    await backend.createTrainer(name: 'Brock', trainerId: '333333');
    await data.save();
    await tester.pump(SyncController.changeDelay);
    await tester.pumpAndSettle();
    expect(dropbox.rev, isNot(rev));
    expect(utf8.decode(dropbox.file!), contains('Brock'));
  });

  testWidgets('ao voltar para o app, sincroniza', (tester) async {
    await connected();
    await pumpApp(tester);
    dropbox.put(otherDevice());
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect([
      for (final t in await backend.fetchTrainers()) t.name,
    ], contains('Misty'));
  });

  testWidgets('puxar a lista de dexes sincroniza', (tester) async {
    await connected();
    await pumpApp(tester);
    await tester.tap(find.text('PersonalDex').last);
    await tester.pumpAndSettle();
    dropbox.put(otherDevice());
    await tester.fling(find.byType(GridView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect([
      for (final t in await backend.fetchTrainers()) t.name,
    ], contains('Misty'));
  });

  testWidgets('sem conexão e acesso revogado: avisa', (tester) async {
    await connected();
    await pumpApp(tester);
    await openSync(tester);
    dropbox.offline = true;
    await tester.tap(find.text('Sincronizar agora'));
    await tester.pumpAndSettle();
    expect(find.text('Sem conexão com o Dropbox.'), findsOneWidget);
    expect(find.text('Sem conexão · sincroniza quando voltar'), findsOneWidget);

    dropbox
      ..offline = false
      ..revoked = true
      ..forced = (status: 401, body: {'error_summary': 'expired'});
    await tester.tap(find.text('Sincronizar agora'));
    await tester.pumpAndSettle();
    expect(find.textContaining('expirou ou foi revogado'), findsOneWidget);
  });

  testWidgets('arquivo do Dropbox inválido: mostra o motivo', (tester) async {
    await connected();
    dropbox.put({'kind': 'outro'});
    await pumpApp(tester);
    await openSync(tester);
    expect(
      find.text('Não é um arquivo de dados do iShinyDex.'),
      findsOneWidget,
    );
  });

  testWidgets('desconectar pede confirmação', (tester) async {
    await connected();
    await pumpApp(tester);
    await openSync(tester);
    await tester.tap(find.text('Desconectar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Desconectar'));
    await tester.pumpAndSettle();
    expect(find.text('Conectar ao Dropbox'), findsOneWidget);
    expect((await sessions.read()).connected, isFalse);
  });

  testWidgets('importar com o Dropbox ligado avisa que sobe junto', (
    tester,
  ) async {
    await pumpWidgetApp(
      tester,
      ImportDialog(
        name: 'a.json',
        summary: LocalData.summarize(data.currentFile()),
        syncing: true,
      ),
    );
    expect(
      find.text('Com o Dropbox ligado, o resultado também vai para lá.'),
      findsOneWidget,
    );
  });

  testWidgets('sem Dropbox, puxar a lista só recarrega', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('PersonalDex').last);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(GridView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(dropbox.requests, isEmpty);
  });

  testWidgets('pedidos durante um sync viram mais uma volta', (tester) async {
    await connected();
    await pumpApp(tester);
    final controller = containerOf(tester)
        .read(syncControllerProvider.notifier);
    // Um pedido no meio do envio: depois desta volta, vem outra.
    dropbox.beforeUpload = () => unawaited(controller.sync());
    await backend.createTrainer(name: 'Brock', trainerId: '333333');
    // Tempo real: no tempo simulado do teste, os timers do Dio não andam.
    await tester.runAsync(controller.sync);
    await tester.pumpAndSettle();
    // Ao abrir, a volta pedida e a seguinte.
    expect(
      dropbox.requests.where((r) => r.uri.path.endsWith('get_metadata')),
      hasLength(3),
    );
  });

  test('describeLastSync e describeSync', () {
    final now = DateTime(2026, 10, 6, 12);
    expect(describeLastSync(now, now), 'agora há pouco');
    expect(
      describeLastSync(now.subtract(const Duration(minutes: 5)), now),
      'há 5 min',
    );
    expect(
      describeLastSync(DateTime(2026, 10, 6, 9, 12), now),
      'hoje às 09:12',
    );
    expect(
      describeLastSync(DateTime(2026, 10, 3, 21, 40), now),
      '03/10 às 21:40',
    );
    expect(
      describeSync(const SyncState(connected: true, phase: SyncPhase.idle)),
      'Conectada',
    );
    expect(
      describeSync(
        SyncState(connected: true, phase: SyncPhase.idle, lastSync: now),
        now: now,
      ),
      'Sincronizado agora há pouco',
    );
    expect(
      describeSync(const SyncState(connected: true, phase: SyncPhase.syncing)),
      'Sincronizando…',
    );
  });

  test('padrões: sessão no shared_preferences, numa chave própria', () {
    final container = createContainer();
    final store = container.read(syncSessionStoreProvider);
    expect((store.storage as PrefsLocalDataStorage).key, 'ishinydex.sync');
    expect(container.read(syncDioProvider).options.baseUrl, isEmpty);
    expect(container.read(browserProvider), isA<Browser>());
  });

  test('o navegador de verdade só existe no navegador', () {
    const real = Browser();
    expect(real.page, Uri.base);
    expect(() => real.open(Uri.parse(_page)), throwsUnsupportedError);
    expect(() => real.replace(Uri.parse(_page)), throwsUnsupportedError);
  });
}
