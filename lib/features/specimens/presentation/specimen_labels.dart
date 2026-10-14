import 'package:intl/intl.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/l10n/app_localizations.dart';

/// Os textos dos modelos de espécimes no idioma da tela
/// (ishinydex-frontend#178): o domínio guarda só os valores.
extension SpecimenLabels on AppLocalizations {
  String ordering(SpecimenOrdering ordering) => switch (ordering) {
    SpecimenOrdering.box => orderingBox,
    SpecimenOrdering.national => orderingNational,
    SpecimenOrdering.capturedDesc => orderingCapturedDesc,
    SpecimenOrdering.capturedAsc => orderingCapturedAsc,
    SpecimenOrdering.createdDesc => orderingCreatedDesc,
  };

  /// Nome do status base ([FormStat.stat]) como nos jogos.
  String stat(String stat) => switch (stat) {
    'hp' => statHp,
    'attack' => statAttack,
    'defense' => statDefense,
    'special-attack' => statSpecialAttack,
    'special-defense' => statSpecialDefense,
    'speed' => statSpeed,
    _ => prettifyName(stat),
  };

  /// A unidade de um método de shiny (`resets`, `encounters`...).
  String huntUnit(String unit) => switch (unit) {
    'encounters' => unitEncounters,
    'hours' => unitHours,
    'resets' => unitResets,
    'eggs' => unitEggs,
    'chains' => unitChains,
    'runs' => unitRuns,
    'raids' => unitRaids,
    'hordes' => unitHordes,
    'combo' => unitCombo,
    _ => unit,
  };

  /// `"4.213 resets"` (o número no formato do idioma), ou `"38 h 30 min"`
  /// em horas (a contagem são minutos).
  String huntCount(int count, String? unit) {
    if (unit == 'hours') {
      final (h, m) = (count ~/ 60, count % 60);
      return m == 0 ? '$h h' : (h == 0 ? '$m min' : '$h h $m min');
    }
    final number = NumberFormat.decimalPattern(localeName).format(count);
    return unit == null ? number : '$number ${huntUnit(unit)}';
  }

  /// Quanto durou a caçada, de [start] até [end]: `"12 dias"`, `"3 meses"`,
  /// `"2 anos"`. No mesmo dia, `"menos de um dia"`.
  String huntDuration(DateTime start, DateTime end) {
    final days = end.difference(start).inDays;
    if (days < 1) return durationUnderADay;
    if (days < 30) return durationDays(days);
    if (days < 365) return durationMonths(days ~/ 30);
    return durationYears(days ~/ 365);
  }

  /// `"hoje"`, `"há 1 dia"`, `"há 203 dias"` ([daysSince]).
  String awayFor(DateTime since, {DateTime? today}) =>
      switch (daysSince(since, today: today)) {
        <= 0 => awayToday,
        final days => awayDaysAgo(days),
      };

  /// Explicação do "Tenho o Shiny Charm" do [save], com onde o Charm não
  /// vale no jogo dele.
  String shinyCharmHint(Save save) {
    final exceptions = switch (save.trainer.version) {
      'sword' || 'shield' => charmExceptSwordShield,
      'brilliant-diamond' || 'shining-pearl' => charmExceptBdsp,
      'scarlet' || 'violet' => charmExceptScarletViolet,
      'legends-za' => charmExceptLegendsZa,
      _ => null,
    };
    return exceptions == null ? charmHint : charmHintExcept(exceptions);
  }

  /// "Galar nº 383", "Tundra Coroada nº 139 (DLC)", "Aventura Dinamax
  /// (DLC)", com o nome da pokédex já no idioma da tela ([name]).
  String pokedexEntry(PokedexEntry entry, String name) {
    final number = entry.number;
    final text = number == null ? name : pokedexNumber(name, '$number');
    return entry.dlc ? '$text (DLC)' : text;
  }
}
