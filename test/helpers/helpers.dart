import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/app.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/l10n/app_language.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/personal_dex/data/last_dex_storage.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/shiny_hunts/domain/shiny_hunt_repository.dart';
import 'package:ishinydex/features/shiny_hunts/shiny_hunt_providers.dart';

/// Sprite de pokébola do `SpecimenHeadline`: o nome da bola fica no rótulo
/// de acessibilidade, não num texto.
Finder ballSprite(Pattern label) => find.byWidgetPredicate(
  (w) => w is PokemonSprite && (w.semanticLabel?.contains(label) ?? false),
);

/// Tamanhos de tela usados nos testes responsivos.
/// Os textos de cada idioma, para testar rótulos sem montar uma tela.
final AppLocalizations ptText = lookupAppLocalizations(const Locale('pt'));
final AppLocalizations enText = lookupAppLocalizations(const Locale('en'));

const compactSize = Size(400, 800);
const mediumSize = Size(900, 900);
const expandedSize = Size(1400, 900);
const largeSize = Size(1600, 1000);

/// A demonstração (sem `LOCAL_DATA`).
const fakeEnv = Env();

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

/// Monta um widget isolado com tema, localização (pt-BR por padrão, como os
/// textos dos testes; `locale: english` para os testes em inglês) e
/// Riverpod.
Future<void> pumpWidgetApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  Size size = compactSize,
  TargetPlatform platform = TargetPlatform.android,
  Locale locale = portuguese,

  /// As caçadas em andamento (#164); por padrão, nenhuma, sem latência.
  ShinyHuntRepository? hunts,
}) async {
  await setScreenSize(tester, size);
  await tester.pumpWidget(
    ProviderScope(
      retry: noRetry,
      overrides: [
        shinyHuntRepositoryProvider.overrideWithValue(hunts ?? FakeBackend()),
        ...overrides,
      ],
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        locale: locale,
        supportedLocales: supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: child,
      ),
    ),
  );
}

/// Monta o app completo (rotas + shell) sobre um [FakeBackend].
Future<FakeBackend> pumpFullApp(
  WidgetTester tester, {
  Size size = expandedSize,
  FakeBackend? backend,
  LastDexStorage? lastDex,
  Env env = fakeEnv,
  List<Override> overrides = const [],

  /// O idioma escolhido em Ajustes; pt-BR, como os textos dos testes (o
  /// aparelho dos testes é en-US).
  AppLanguage language = AppLanguage.pt,
  LanguageStorage? languageStorage,
}) async {
  final fake = backend ?? FakeBackend.seeded();
  await setScreenSize(tester, size);
  await tester.pumpWidget(
    ProviderScope(
      retry: noRetry,
      overrides: [
        envProvider.overrideWithValue(env),
        fakeBackendProvider.overrideWithValue(fake),
        lastDexStorageProvider.overrideWithValue(
          lastDex ?? InMemoryLastDexStorage(),
        ),
        initialLanguageProvider.overrideWithValue(language),
        languageStorageProvider.overrideWithValue(
          languageStorage ?? InMemoryLanguageStorage(language),
        ),
        ...overrides,
      ],
      child: const IShinyDexApp(),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

/// Abre a folha "Mais ações" (painel do slot, detalhe do espécime) e toca
/// na ação [label].
Future<void> tapMoreAction(WidgetTester tester, String label) async {
  // Uma mensagem da ação anterior cobriria a barra de ações.
  ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last))
      .removeCurrentSnackBar();
  await tester.pumpAndSettle();
  // A barra visível (uma tela por trás pode ter a sua).
  await tester.tap(find.byTooltip('Mais ações').hitTestable().last);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, label));
  await tester.pumpAndSettle();
}
