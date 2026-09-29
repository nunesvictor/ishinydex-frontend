import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/responsive/adaptive_shell.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/features/auth/auth_providers.dart';
import 'package:ishinydex/features/auth/presentation/login_page.dart';
import 'package:ishinydex/features/personal_dex/data/last_dex_storage.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/dex_detail_page.dart';
import 'package:ishinydex/features/personal_dex/presentation/dex_list_page.dart';
import 'package:ishinydex/features/settings/presentation/settings_page.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const dexes = '/dexes';
  static const settings = '/settings';

  static String dex(int id) => '$dexes/$id';
}

/// Decide para onde ir conforme o estado de autenticação.
String? authRedirect(AsyncValue<String?> auth, String location) {
  // Login em andamento: fica na tela de login.
  if (auth.isLoading && location == Routes.login) return null;
  // Ainda lendo o token salvo.
  if (!auth.hasValue && !auth.hasError) {
    return location == Routes.splash ? null : Routes.splash;
  }
  final loggedIn = auth.value != null;
  if (!loggedIn) return location == Routes.login ? null : Routes.login;
  if (location == Routes.login || location == Routes.splash) {
    return Routes.dexes;
  }
  return null;
}

/// Ao entrar no app ([authRedirect] mandou para [Routes.dexes]), abre o
/// último dex usado (ou o único); se não der para decidir, fica na lista.
Future<String> homeLocation(Ref ref) async {
  try {
    final dexId = await resolveHomeDexId(
      storage: ref.read(lastDexStorageProvider),
      repository: ref.read(personalDexRepositoryProvider),
    );
    return dexId == null ? Routes.dexes : Routes.dex(dexId);
  } on Object {
    // A lista mostra o erro com "Tentar novamente".
    return Routes.dexes;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref
    ..listen(authControllerProvider, (_, _) => refresh.value++)
    ..onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    // Síncrono na maioria das vezes; só consulta a API (Future) ao entrar
    // no app, para decidir qual dex abrir.
    redirect: (context, state) {
      final target = authRedirect(
        ref.read(authControllerProvider),
        state.matchedLocation,
      );
      return target == Routes.dexes ? homeLocation(ref) : target;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const Scaffold(body: LoadingView()),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            AdaptiveShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.dexes,
                builder: (context, state) => const DexListPage(),
                routes: [
                  GoRoute(
                    path: ':dexId',
                    builder: (context, state) {
                      final dexId =
                          int.tryParse(state.pathParameters['dexId']!) ?? 0;
                      // Trocar de dex recria a página (box e seleção zeradas).
                      return DexDetailPage(key: ValueKey(dexId), dexId: dexId);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
