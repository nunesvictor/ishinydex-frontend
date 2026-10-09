import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/shiny_hunts/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/domain/shiny_hunt_repository.dart';

final shinyHuntRepositoryProvider = Provider<ShinyHuntRepository>(
  (ref) => ref.watch(fakeBackendProvider),
);

/// As caçadas em andamento e pausadas.
final FutureProvider<List<ShinyHunt>> shinyHuntsProvider =
    FutureProvider.autoDispose<List<ShinyHunt>>(
      (ref) => ref.watch(shinyHuntRepositoryProvider).fetchShinyHunts(),
    );

/// O relógio das caçadas (nos testes, fixo).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Formas com caçada em andamento (não pausada): o selo no slot da box.
final Provider<Set<int>> huntedFormsProvider = Provider.autoDispose<Set<int>>(
  (ref) => {
    for (final h in ref.watch(shinyHuntsProvider).value ?? const <ShinyHunt>[])
      if (!h.paused) h.form,
  },
);

final shinyHuntActionsProvider = Provider<ShinyHuntActions>(
  ShinyHuntActions.new,
);

/// O que se faz com uma caçada; cada ação grava e recarrega a lista. Falhas
/// (`AppFailure`) sobem para a tela mostrar.
class ShinyHuntActions {
  ShinyHuntActions(this._ref);

  final Ref _ref;

  DateTime get _now => _ref.read(clockProvider)();

  DateTime get _today {
    final now = _now;
    return DateTime(now.year, now.month, now.day);
  }

  Future<ShinyHunt> save(ShinyHunt hunt) async {
    final saved = await _ref
        .read(shinyHuntRepositoryProvider)
        .saveShinyHunt(hunt);
    _ref.invalidate(shinyHuntsProvider);
    return saved;
  }

  Future<ShinyHunt> add(ShinyHunt hunt, int delta) =>
      save(hunt.copyWith(count: max(0, hunt.count + delta)));

  /// Inicia ou para o cronômetro.
  Future<ShinyHunt> toggleTimer(ShinyHunt hunt) => save(
    hunt.running ? hunt.stopped(_now) : hunt.copyWith(runningSince: _now),
  );

  /// Desistir: vai para Pausadas, com o cronômetro parado.
  Future<ShinyHunt> pause(ShinyHunt hunt) =>
      save(hunt.stopped(_now).copyWith(paused: true, pausedAt: _today));

  Future<ShinyHunt> resume(ShinyHunt hunt) =>
      save(hunt.copyWith(paused: false, pausedAt: null));

  Future<void> delete(int huntId) async {
    await _ref.read(shinyHuntRepositoryProvider).deleteShinyHunt(huntId);
    _ref.invalidate(shinyHuntsProvider);
  }

  /// Hoje, para a data de início de uma caçada nova.
  DateTime today() => _today;

  DateTime now() => _now;
}
