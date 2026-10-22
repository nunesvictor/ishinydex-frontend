import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/clock.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/shiny_hunts/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/domain/shiny_hunt_repository.dart';
import 'package:ishinydex/features/shiny_hunts/domain/shiny_odds.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

export 'package:ishinydex/core/clock.dart';

final shinyHuntRepositoryProvider = Provider<ShinyHuntRepository>(
  (ref) => ref.watch(fakeBackendProvider),
);

/// As caçadas em andamento e pausadas.
final FutureProvider<List<ShinyHunt>> shinyHuntsProvider =
    FutureProvider.autoDispose<List<ShinyHunt>>(
      (ref) => ref.watch(shinyHuntRepositoryProvider).fetchShinyHunts(),
    );

/// Formas com caçada em andamento (não pausada): o selo no slot da box.
final Provider<Set<int>> huntedFormsProvider = Provider.autoDispose<Set<int>>(
  (ref) => {
    for (final h in ref.watch(shinyHuntsProvider).value ?? const <ShinyHunt>[])
      if (!h.paused) h.form,
  },
);

/// As odds de uma caçada (#221): a regra do método no jogo do save e se o
/// save tem o Shiny Charm. `null` sem save, sem método ou sem regra no
/// catálogo (catálogo antigo).
typedef HuntOdds = ({OddsRule rule, bool hasCharm});

/// A regra de odds do método no jogo do save.
final oddsRuleProvider =
    Provider<OddsRule? Function(String? method, Save? save)>((ref) {
      final catalog = ref.watch(fakeBackendProvider).catalog;
      return (method, save) => catalog?.oddsRule(method, save?.trainer.version);
    });

final Provider<HuntOdds? Function(ShinyHunt)> huntOddsProvider =
    Provider.autoDispose<HuntOdds? Function(ShinyHunt)>((ref) {
      final saves = ref.watch(savesProvider).value ?? const <Save>[];
      final ruleFor = ref.watch(oddsRuleProvider);
      return (hunt) {
        final save = saves.where((s) => s.id == hunt.save).firstOrNull;
        if (save == null) return null;
        final rule = ruleFor(hunt.method, save);
        return rule == null ? null : (rule: rule, hasCharm: save.hasShinyCharm);
      };
    });

/// A última caçada retomada e quando (#279). A tela de Caçadas vai para a
/// aba Ativas, com o cartão dela no topo e um destaque breve; o instante
/// distingue retomar a mesma caçada duas vezes.
typedef ResumedHunt = ({int id, DateTime at});

final resumedHuntProvider = NotifierProvider<ResumedHuntNotifier, ResumedHunt?>(
  ResumedHuntNotifier.new,
);

class ResumedHuntNotifier extends Notifier<ResumedHunt?> {
  @override
  ResumedHunt? build() => null;

  void mark(int id, DateTime at) => state = (id: id, at: at);
}

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

  HuntOdds? _odds(ShinyHunt hunt) => _ref.read(huntOddsProvider)(hunt);

  /// +1/−1 (ou o que andou segurando): com odds, cada encontro entra na
  /// chance acumulada e na cadeia.
  Future<ShinyHunt> add(ShinyHunt hunt, int delta) =>
      save(switch (_odds(hunt)) {
        (:final rule, :final hasCharm) => hunt.advanced(
          rule,
          delta,
          hasCharm: hasCharm,
        ),
        null => hunt.copyWith(count: max(0, hunt.count + delta)),
      });

  /// A contagem digitada.
  Future<ShinyHunt> setCount(ShinyHunt hunt, int count) =>
      save(switch (_odds(hunt)) {
        (:final rule, :final hasCharm) => hunt.withCount(
          rule,
          count,
          hasCharm: hasCharm,
        ),
        null => hunt.copyWith(count: count),
      });

  /// "Quebrou": a cadeia volta a 0.
  Future<ShinyHunt> breakChain(ShinyHunt hunt) => save(hunt.broken());

  /// Inicia ou para o cronômetro.
  Future<ShinyHunt> toggleTimer(ShinyHunt hunt) => save(
    hunt.running ? hunt.stopped(_now) : hunt.copyWith(runningSince: _now),
  );

  /// Pausar: vai para Pausadas, com o cronômetro parado.
  Future<ShinyHunt> pause(ShinyHunt hunt) =>
      save(hunt.stopped(_now).copyWith(paused: true, pausedAt: _today));

  /// Retomar: volta para Ativas, e a tela vai atrás dela (#279).
  Future<ShinyHunt> resume(ShinyHunt hunt) async {
    final saved = await save(hunt.copyWith(paused: false, pausedAt: null));
    _ref.read(resumedHuntProvider.notifier).mark(saved.id, _now);
    return saved;
  }

  Future<void> delete(int huntId) async {
    await _ref.read(shinyHuntRepositoryProvider).deleteShinyHunt(huntId);
    _ref.invalidate(shinyHuntsProvider);
  }

  /// Hoje, para a data de início de uma caçada nova.
  DateTime today() => _today;

  DateTime now() => _now;
}
