import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
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

  /// O registro da caçada do espécime, ao terminar ("Encontrei!"). Em horas,
  /// a contagem são os minutos do cronômetro.
  HuntRecord toRecord(DateTime now) {
    final value = timed ? elapsed(now).inMinutes : count;
    return HuntRecord(
      method: method,
      // Zero não é contagem (o registro exige mais que zero).
      count: value > 0 ? value : null,
      unit: unit,
      startedAt: startedAt,
    );
  }
}

/// `"5 h 12 min"`: o tempo do cronômetro.
String timerLabel(Duration elapsed) {
  final (h, m) = (elapsed.inHours, elapsed.inMinutes % 60);
  return h == 0 ? '$m min' : '$h h ${m.toString().padLeft(2, '0')} min';
}
