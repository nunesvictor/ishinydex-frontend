import 'dart:math';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/domain/shiny_odds.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';

part 'models.freezed.dart';

/// Uma caçada em andamento ou pausada (#164). Termina de dois jeitos: o
/// "Encontrei!" (vira o registro da caçada do espécime, [toRecord]) ou a
/// exclusão, que só existe nas pausadas.
@freezed
abstract class ShinyHunt with _$ShinyHunt {
  const factory ShinyHunt({
    required int id,
    required int form,
    FormRef? formRef,

    /// Pausada: a pessoa desistiu por ora; a contagem fica guardada.
    @Default(false) bool paused,

    /// Save onde a caçada acontece (o jogo filtra os métodos).
    int? save,
    String? method,
    @Default('encounters') String unit,

    /// A contagem; em horas, o cronômetro ([elapsed]) vale no lugar.
    @Default(0) int count,

    /// Segundos já contados pelo cronômetro, fora a parte que está rodando.
    @Default(0) int accumulatedSeconds,

    /// Desde quando o cronômetro roda; `null` = parado. Guardar o início, e
    /// não um contador, faz o tempo continuar com o app fechado.
    DateTime? runningSince,
    DateTime? startedAt,
    DateTime? pausedAt,

    /// Os modificadores das odds (#221): id → opção escolhida (índice) ou
    /// número (o Search Level do DexNav).
    @Default(<String, int>{}) Map<String, int> modifiers,

    /// A cadeia atual e a maior cadeia, nos métodos de cadeia.
    @Default(0) int chain,
    @Default(0) int bestChain,

    /// A chance acumulada de o shiny ainda não ter saído, atualizada a cada
    /// +1 com as odds daquele momento. `null` = sem odds até aqui: vale a
    /// conta com as odds atuais ([missChance]).
    double? miss,

    /// Parte da contagem foi digitada numa caçada de cadeia: a chance
    /// acumulada desse trecho é estimada com a cadeia do momento.
    @Default(false) bool estimated,
  }) = _ShinyHunt;

  const ShinyHunt._();

  bool get running => runningSince != null;

  bool get timed => unit == 'hours';

  /// O tempo do cronômetro até [now].
  Duration elapsed(DateTime now) => Duration(
    seconds:
        accumulatedSeconds +
        (runningSince == null ? 0 : now.difference(runningSince!).inSeconds),
  );

  /// O cronômetro parado em [now], com o tempo somado.
  ShinyHunt stopped(DateTime now) =>
      copyWith(accumulatedSeconds: elapsed(now).inSeconds, runningSince: null);

  /// A chance de o próximo encontro ser shiny pela [rule].
  double chance(OddsRule rule, {required bool hasCharm}) => rule.chance(
    form: form,
    hasCharm: hasCharm,
    values: modifiers,
    chain: chain,
  );

  /// A chance acumulada de o shiny ainda não ter saído. Sem o registro
  /// ([miss]), a conta usa as odds atuais em toda a contagem.
  double missChance(OddsRule rule, {required bool hasCharm}) =>
      miss ?? pow(1 - chance(rule, hasCharm: hasCharm), count).toDouble();

  /// Quantas vezes as odds já foram "gastas": o número esperado de shinies
  /// até aqui (1,0× = a contagem bateu nas odds).
  double multiple(OddsRule rule, {required bool hasCharm}) {
    final m = missChance(rule, hasCharm: hasCharm);
    return m <= 0 ? double.infinity : -log(m);
  }

  /// [steps] encontros a mais (ou a menos, negativo), um a um: cada um
  /// multiplica a chance acumulada pelas odds daquele momento, soma na
  /// cadeia (e na maior cadeia) e no Search Level, quando ele acompanha a
  /// contagem. O −1 desfaz na ordem inversa.
  ShinyHunt advanced(OddsRule rule, int steps, {required bool hasCharm}) {
    var hunt = this;
    var m = missChance(rule, hasCharm: hasCharm);
    final follows = [
      for (final mod in rule.modifiers)
        if (mod.followsCount) mod,
    ];
    ShinyHunt following(ShinyHunt h, int delta) => h.copyWith(
      modifiers: {
        ...h.modifiers,
        for (final mod in follows)
          mod.id: ((h.modifiers[mod.id] ?? mod.min ?? 0) + delta).clamp(
            mod.min ?? 0,
            mod.max ?? 1 << 30,
          ),
      },
    );
    for (var i = 0; i < steps; i++) {
      m *= 1 - hunt.chance(rule, hasCharm: hasCharm);
      var next = hunt.chain + (rule.hasChain ? 1 : 0);
      if (rule.resetAfter case final limit? when next > limit) next = 0;
      hunt = following(
        hunt.copyWith(
          count: hunt.count + 1,
          chain: next,
          bestChain: max(hunt.bestChain, next),
        ),
        1,
      );
    }
    for (var i = 0; i > steps && hunt.count > 0; i--) {
      hunt = following(
        hunt.copyWith(
          count: hunt.count - 1,
          chain: max(0, hunt.chain - (rule.hasChain ? 1 : 0)),
        ),
        -1,
      );
      final p = hunt.chance(rule, hasCharm: hasCharm);
      m = hunt.count == 0 || p >= 1 ? 1 : m / (1 - p);
    }
    return hunt.copyWith(miss: m.clamp(0, 1));
  }

  /// A contagem digitada: a diferença entra com as odds atuais. Nos
  /// métodos de cadeia, isso é uma estimativa.
  ShinyHunt withCount(OddsRule rule, int value, {required bool hasCharm}) {
    final p = chance(rule, hasCharm: hasCharm);
    final m =
        missChance(rule, hasCharm: hasCharm) *
        pow(1 - p, value - count).toDouble();
    return copyWith(
      count: value,
      miss: value == 0 ? 1 : m.clamp(0, 1),
      estimated: estimated || (rule.hasChain && value != count),
    );
  }

  /// "Quebrou": a cadeia volta a 0; o total e a maior cadeia ficam.
  ShinyHunt broken() => copyWith(chain: 0);

  /// O registro da caçada do espécime, ao terminar ("Encontrei!"). Em horas,
  /// a contagem são os minutos do cronômetro. Com a [rule], guarda as odds
  /// do fim e o múltiplo, porque o Charm e os modificadores podem mudar
  /// depois.
  HuntRecord toRecord(DateTime now, {OddsRule? rule, bool hasCharm = false}) {
    final value = timed ? elapsed(now).inMinutes : count;
    final odds = rule == null ? 0.0 : chance(rule, hasCharm: hasCharm);
    return HuntRecord(
      method: method,
      // Zero não é contagem (o registro exige mais que zero).
      count: value > 0 ? value : null,
      unit: unit,
      startedAt: startedAt,
      odds: odds > 0 ? 1 / odds : null,
      multiple: odds > 0 && !timed && count > 0
          ? multiple(rule!, hasCharm: hasCharm)
          : null,
      bestChain: bestChain > 0 ? bestChain : null,
    );
  }
}

/// `"5 h 12 min"`: o tempo do cronômetro.
String timerLabel(Duration elapsed) {
  final (h, m) = (elapsed.inHours, elapsed.inMinutes % 60);
  return h == 0 ? '$m min' : '$h h ${m.toString().padLeft(2, '0')} min';
}
