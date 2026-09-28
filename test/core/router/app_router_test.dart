import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/router/app_router.dart';

import '../../helpers/helpers.dart';

void main() {
  group('authRedirect', () {
    test('lendo token salvo vai para o splash', () {
      expect(authRedirect(const AsyncLoading(), '/dexes'), Routes.splash);
      expect(authRedirect(const AsyncLoading(), Routes.splash), isNull);
    });

    test('login em andamento permanece no login', () {
      expect(authRedirect(const AsyncLoading(), Routes.login), isNull);
    });

    test('deslogado vai para o login', () {
      expect(authRedirect(const AsyncData(null), '/dexes/1'), Routes.login);
      expect(authRedirect(const AsyncData(null), Routes.login), isNull);
      expect(
        authRedirect(const AsyncError('x', StackTrace.empty), Routes.login),
        isNull,
      );
    });

    test('logado sai do login/splash', () {
      expect(authRedirect(const AsyncData('t'), Routes.login), Routes.dexes);
      expect(authRedirect(const AsyncData('t'), Routes.splash), Routes.dexes);
      expect(authRedirect(const AsyncData('t'), '/dexes/1'), isNull);
      expect(Routes.dex(3), '/dexes/3');
    });
  });

  testWidgets('sem token abre o login; logando vai para os dexes', (
    tester,
  ) async {
    await pumpFullApp(tester, token: null, size: compactSize);
    expect(find.text('Entrar'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'ash');
    await tester.enterText(find.byType(TextFormField).at(1), 'pika');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Shiny Living Dex'), findsOneWidget);
    // Navegação compacta: NavigationBar.
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('shell com NavigationRail e troca de aba', (tester) async {
    await pumpFullApp(tester, size: mediumSize);
    expect(find.byType(NavigationRail), findsOneWidget);
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Servidor'), findsOneWidget);
    await tester.tap(find.text('PersonalDex').first);
    await tester.pumpAndSettle();
    expect(find.text('Shiny Living Dex'), findsOneWidget);
    // Tocar na aba atual volta para a raiz da aba.
    await tester.tap(find.text('Shiny Living Dex'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.byIcon(Icons.catching_pokemon),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Shiny Living Dex'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('rail estendido no layout expandido', (tester) async {
    await pumpFullApp(tester);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, true);
  });

  testWidgets('dexId inválido mostra erro', (tester) async {
    await pumpFullApp(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    container.read(routerProvider).go('/dexes/abc');
    await tester.pumpAndSettle();
    expect(find.text('Recurso não encontrado.'), findsOneWidget);
  });
}
