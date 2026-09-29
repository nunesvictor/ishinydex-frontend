import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/app.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/auth/auth_providers.dart';
import 'package:ishinydex/features/auth/data/token_storage.dart';
import 'package:ishinydex/features/personal_dex/data/last_dex_storage.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/settings/data/date_format_storage.dart';
import 'package:ishinydex/features/settings/settings_providers.dart';

/// Tamanhos de tela usados nos testes responsivos.
const compactSize = Size(400, 800);
const mediumSize = Size(800, 900);
const expandedSize = Size(1400, 900);
const largeSize = Size(1600, 1000);

const fakeEnv = Env(apiBaseUrl: 'http://test/api', useFakeApi: true);

Future<void> setScreenSize(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

ProviderContainer createContainer({List<Override> overrides = const []}) {
  final container = ProviderContainer(retry: noRetry, overrides: overrides);
  addTearDown(container.dispose);
  return container;
}

/// Monta um widget isolado com tema, localização pt-BR e Riverpod.
Future<void> pumpWidgetApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  Size size = compactSize,
  TargetPlatform platform = TargetPlatform.android,
  DateFormatStorage? dateFormat,
}) async {
  await setScreenSize(tester, size);
  await tester.pumpWidget(
    ProviderScope(
      retry: noRetry,
      overrides: [
        dateFormatStorageProvider.overrideWithValue(
          dateFormat ?? InMemoryDateFormatStorage(),
        ),
        ...overrides,
      ],
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: child,
      ),
    ),
  );
}

/// Monta o app completo (rotas + shell) sobre um [FakeBackend].
Future<FakeBackend> pumpFullApp(
  WidgetTester tester, {
  Size size = expandedSize,
  String? token = 'token',
  FakeBackend? backend,
  LastDexStorage? lastDex,
  DateFormatStorage? dateFormat,
  List<Override> overrides = const [],
}) async {
  final fake = backend ?? FakeBackend.seeded();
  await setScreenSize(tester, size);
  await tester.pumpWidget(
    ProviderScope(
      retry: noRetry,
      overrides: [
        envProvider.overrideWithValue(fakeEnv),
        fakeBackendProvider.overrideWithValue(fake),
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
        lastDexStorageProvider.overrideWithValue(
          lastDex ?? InMemoryLastDexStorage(),
        ),
        dateFormatStorageProvider.overrideWithValue(
          dateFormat ?? InMemoryDateFormatStorage(),
        ),
        ...overrides,
      ],
      child: const IShinyDexApp(),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}
