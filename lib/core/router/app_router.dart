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
import 'package:ishinydex/features/personal_dex/presentation/hunts_page.dart';
import 'package:ishinydex/features/settings/presentation/about_page.dart';
import 'package:ishinydex/features/settings/presentation/settings_page.dart';
import 'package:ishinydex/features/shiny_locks/presentation/shiny_locks_page.dart';
import 'package:ishinydex/features/specimens/presentation/away_page.dart';
import 'package:ishinydex/features/specimens/presentation/saves_page.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_detail.dart';
import 'package:ishinydex/features/specimens/presentation/specimens_page.dart';
import 'package:ishinydex/features/sync/presentation/sync_page.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const dexes = '/dexes';
  static const specimens = '/specimens';
  static const settings = '/settings';

  /// Ajustes → Meus saves.
  static const saves = '$settings/saves';

  /// Ajustes → Shiny locks.
  static const shinyLocks = '$settings/shiny-locks';

  /// Ajustes → Sincronização com o Dropbox (só no modo local com a app key).
  static const sync = '$settings/sync';

  /// Ajustes → Sobre o iShinyDex.
  static const about = '$settings/about';

  /// Espécimes fora do HOME, por save.
  static const away = '$specimens/away';

  /// Dex [id]; com [boxId]/[slotId], abre naquela box com o slot selecionado.
  static String dex(int id, {int? boxId, int? slotId}) => Uri(
    path: '$dexes/$id',
    queryParameters: {
      if (boxId != null) 'box': '$boxId',
      if (slotId != null) 'slot': '$slotId',
    }.nullIfEmpty,
  ).toString();

  /// Caçadas do shiny dex [dexId].
  static String hunts(int dexId) => '$dexes/$dexId/hunts';

  static String specimen(int id) => '$specimens/$id';
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
                      final query = state.uri.queryParameters;
                      final boxId = int.tryParse(query['box'] ?? '');
                      final slotId = int.tryParse(query['slot'] ?? '');
                      // Trocar de dex (ou de slot pedido na URL) recria a
                      // página, com box e seleção novas.
                      return DexDetailPage(
                        key: ValueKey((dexId, boxId, slotId)),
                        dexId: dexId,
                        initialBoxId: boxId,
                        initialSlotId: slotId,
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'hunts',
                        builder: (context, state) => HuntsPage(
                          dexId:
                              int.tryParse(state.pathParameters['dexId']!) ?? 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.specimens,
                builder: (context, state) => const SpecimensPage(),
                routes: [
                  // Antes de ':specimenId', que também casaria com "away".
                  GoRoute(
                    path: 'away',
                    builder: (context, state) => const AwayPage(),
                  ),
                  GoRoute(
                    path: ':specimenId',
                    builder: (context, state) => SpecimenDetailPage(
                      specimenId:
                          int.tryParse(state.pathParameters['specimenId']!) ??
                          0,
                    ),
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
                routes: [
                  GoRoute(
                    path: 'saves',
                    builder: (context, state) => const SavesPage(),
                  ),
                  GoRoute(
                    path: 'shiny-locks',
                    builder: (context, state) => const ShinyLocksPage(),
                  ),
                  GoRoute(
                    path: 'about',
                    builder: (context, state) => const AboutPage(),
                  ),
                  GoRoute(
                    path: 'sync',
                    builder: (context, state) => const SyncPage(),
                  ),
                ],
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

extension on Map<String, String> {
  Map<String, String>? get nullIfEmpty => isEmpty ? null : this;
}
