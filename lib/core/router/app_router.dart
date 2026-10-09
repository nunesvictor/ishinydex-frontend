import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/responsive/adaptive_shell.dart';
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
  /// Entrada do app: redireciona para o último dex usado ([homeLocation]).
  static const home = '/';
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

  /// Caçadas do shiny dex [dexId]; com [active], já na aba Ativas.
  static String hunts(int dexId, {bool active = false}) =>
      '$dexes/$dexId/hunts${active ? '?tab=active' : ''}';

  static String specimen(int id) => '$specimens/$id';
}

/// Ao entrar no app ([Routes.home]), abre o último dex usado (ou o único);
/// se não der para decidir, fica na lista.
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
  final router = GoRouter(
    initialLocation: Routes.home,
    routes: [
      // A entrada: decide qual dex abrir (consulta o backend local).
      GoRoute(
        path: Routes.home,
        redirect: (context, state) => homeLocation(ref),
      ),
      StatefulShellRoute.indexedStack(
        // O estado do sync fica sempre à vista: a faixa de "sincronizando"
        // e um selo em Ajustes quando há problema.
        builder: (context, state, shell) => AdaptiveShell(
          navigationShell: shell,
          activity: const SyncActivityBar(),
          decorateIcon: (index, icon) =>
              index == settingsDestination ? SyncBadge(child: icon) : icon,
        ),
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
                          initialTab:
                              state.uri.queryParameters['tab'] == 'active'
                              ? HuntsTab.active
                              : HuntsTab.missing,
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
