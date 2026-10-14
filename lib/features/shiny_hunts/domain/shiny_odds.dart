import 'dart:math';

import 'package:ishinydex/features/catalog/domain/catalog_labels.dart';

/// As odds de shiny de um método num jogo (`shinyOdds` do catálogo,
/// backend#113). Curadoria: `docs/roadmap/ideias/odds-das-cacadas.md` no
/// ishinydex.
///
/// Três tipos de regra:
/// - **sorteios** ([OddsKind.rolls]): cada encontro sorteia `rolls` vezes,
///   com chance de 1/`base` cada; Charm, modificadores e cadeia somam
///   sorteios. Odds = 1 − (1 − 1/base)^sorteios.
/// - **chance** ([OddsKind.chance]): 1/x direto, fixo (`odds`), por cadeia
///   (`steps`) ou por tabela (`table`).
/// - **DexNav** ([OddsKind.dexnav]): a fórmula do ORAS (Search Level,
///   checagens e o sorteio normal).
enum OddsKind { rolls, chance, dexnav }

class OddsRule {
  const OddsRule({
    required this.method,
    required this.versions,
    required this.kind,
    this.base = 4096,
    this.rolls = 1,
    this.charm,
    this.odds,
    this.charmOdds,
    this.steps = const [],
    this.resetAfter,
    this.modifiers = const [],
    this.table,
    this.charmExceptForms = const {},
    this.note,
    this.notes = const {},
  });

  factory OddsRule.fromJson(Map<String, dynamic> json) {
    final chain = json['chain'] as Map<String, dynamic>?;
    final table = json['table'] as Map<String, dynamic>?;
    return OddsRule(
      method: json['method'] as String,
      versions: {for (final v in json['versions'] as List) v as String},
      kind: OddsKind.values.byName(json['kind'] as String),
      base: json['base'] as int,
      rolls: json['rolls'] as int? ?? 1,
      charm: json['charm'] as int?,
      odds: (json['odds'] as num?)?.toDouble(),
      charmOdds: (json['charmOdds'] as num?)?.toDouble(),
      steps: [
        for (final s in (chain?['steps'] as List?) ?? const [])
          ChainStep.fromJson(s as Map<String, dynamic>),
      ],
      resetAfter: chain?['resetAfter'] as int?,
      modifiers: [
        for (final m in (json['modifiers'] as List?) ?? const [])
          OddsModifier.fromJson(m as Map<String, dynamic>),
      ],
      table: table == null ? null : OddsTable.fromJson(table),
      charmExceptForms: {
        for (final f in (json['charmExceptForms'] as List?) ?? const [])
          f as int,
      },
      note: json['note'] as String?,
      notes: catalogLabels(json['notes']),
    );
  }

  final String method;
  final Set<String> versions;
  final OddsKind kind;

  /// 4096, ou 8192 até a Gen V (FRLG).
  final int base;

  /// Sorteios de cada encontro, sem bônus.
  final int rolls;

  /// Sorteios que o Charm soma; `null` = o Charm não vale.
  final int? charm;

  /// Chance fixa (1/x), com e sem o Charm ([OddsKind.chance]).
  final double? odds;
  final double? charmOdds;

  /// Bônus por cadeia, em ordem; vazio = método sem cadeia.
  final List<ChainStep> steps;

  /// A cadeia volta a 0 depois deste valor (SOS no Sun/Moon).
  final int? resetAfter;

  final List<OddsModifier> modifiers;
  final OddsTable? table;

  /// Formas em que o Charm não vale (os Regis no SwSh).
  final Set<int> charmExceptForms;

  /// Observação curta da curadoria, para o cartão.
  final String? note;

  /// [note] em cada idioma da interface; vazio em catálogos antigos.
  final Map<String, String> notes;

  bool get hasChain => steps.isNotEmpty || kind == OddsKind.dexnav;

  /// O Charm tem efeito em algum caso desta regra.
  bool get charmCounts =>
      charm != null ||
      charmOdds != null ||
      steps.any((s) => s.charmOdds != null);

  /// O Charm vale para a forma [form] com o save [hasCharm].
  bool charmApplies(int form, {required bool hasCharm}) =>
      hasCharm && charmCounts && !charmExceptForms.contains(form);

  /// Os modificadores que aparecem com os [values] escolhidos (um pode
  /// depender da opção de outro, como os derrotados da aura no SwSh).
  List<OddsModifier> visibleModifiers(Map<String, int> values) => [
    for (final m in modifiers)
      if (m.when == null || (values[m.when!.$1] ?? 0) == m.when!.$2) m,
  ];

  /// A chance de o próximo encontro ser shiny, de 0 a 1.
  double chance({
    required int form,
    required bool hasCharm,
    Map<String, int> values = const {},
    int chain = 0,
  }) {
    final charmOn = charmApplies(form, hasCharm: hasCharm);
    switch (kind) {
      case OddsKind.rolls:
        var total = rolls + (charmOn ? charm! : 0);
        for (final m in visibleModifiers(values)) {
          total += m.rollsFor(values[m.id]);
        }
        total += _step(chain)?.rolls ?? 0;
        return rollsChance(total, base);
      case OddsKind.chance:
        if (table case final t?) {
          final x = t.oddsAt(values[t.rows] ?? 0, values[t.columns] ?? 0);
          return x == null ? 0 : 1 / x;
        }
        if (_step(chain) case final step?) {
          return 1 / (charmOn ? step.charmOdds ?? step.odds! : step.odds!);
        }
        return 1 / (charmOn ? charmOdds ?? odds! : odds!);
      case OddsKind.dexnav:
        return dexNavChance(
          searchLevel: values['searchLevel'] ?? 0,
          encounter: chain + 1,
          charm: charmOn,
        );
    }
  }

  ChainStep? _step(int chain) => steps.isEmpty
      ? null
      : steps.lastWhere((s) => s.from <= chain, orElse: () => steps.first);
}

/// A chance de um encontro com [rolls] sorteios de 1/[base].
double rollsChance(int rolls, [int base = 4096]) =>
    1 - pow(1 - 1 / base, rolls).toDouble();

/// DexNav (ORAS): a chance de o encontro número [encounter] da cadeia ser
/// shiny, com o Search Level [searchLevel].
///
/// A chance forçada vem do nível (+6 por nível até o 100, +2 do 101 ao 200 e
/// +1 acima, em centésimos de 0,01%), checada uma vez, +2 com o Charm, +4 com
/// o boost (todo 5º encontro, ou 4% de chance nos outros: entra pela
/// média), +5 no 50º e +10 no 100º. O sorteio normal (1, ou 3 com o Charm)
/// continua valendo.
double dexNavChance({
  required int searchLevel,
  required int encounter,
  required bool charm,
}) {
  final level = searchLevel.clamp(0, 999);
  final target =
      6 * min(level, 100) +
      2 * (min(level, 200) - 100).clamp(0, 100) +
      max(0, level - 200);
  final forced = (target / 100).ceil() / 10000;
  final normal = pow(1 - 1 / 4096, charm ? 3 : 1);
  double chanceWith({required bool boost}) {
    final checks =
        1 +
        (charm ? 2 : 0) +
        (boost ? 4 : 0) +
        (encounter == 50 ? 5 : 0) +
        (encounter == 100 ? 10 : 0);
    return (1 - pow(1 - forced, checks) * normal).toDouble();
  }

  if (encounter % 5 == 0) return chanceWith(boost: true);
  return 0.96 * chanceWith(boost: false) + 0.04 * chanceWith(boost: true);
}

class ChainStep {
  const ChainStep(this.from, {this.rolls, this.odds, this.charmOdds});

  factory ChainStep.fromJson(Map<String, dynamic> json) => ChainStep(
    json['from'] as int,
    rolls: json['rolls'] as int?,
    odds: (json['odds'] as num?)?.toDouble(),
    charmOdds: (json['charmOdds'] as num?)?.toDouble(),
  );

  /// A partir de qual cadeia o passo vale.
  final int from;
  final int? rolls;
  final double? odds;
  final double? charmOdds;
}

/// Um modificador da caçada: uma escolha (com os sorteios de cada opção) ou
/// um número (o Search Level do DexNav).
class OddsModifier {
  const OddsModifier({
    required this.id,
    required this.label,
    this.labels = const {},
    this.options = const [],
    this.min,
    this.max,
    this.followsCount = false,
    this.when,
  });

  factory OddsModifier.fromJson(Map<String, dynamic> json) {
    final when = json['when'] as Map<String, dynamic>?;
    return OddsModifier(
      id: json['id'] as String,
      label: json['label'] as String,
      labels: catalogLabels(json['labels']),
      options: [
        for (final o in (json['options'] as List?) ?? const [])
          (
            label: (o as Map<String, dynamic>)['label'] as String,
            labels: catalogLabels(o['labels']),
            rolls: o['rolls'] as int,
          ),
      ],
      min: json['min'] as int?,
      max: json['max'] as int?,
      followsCount: json['followsCount'] as bool? ?? false,
      when: when == null
          ? null
          : (when['modifier'] as String, when['option'] as int),
    );
  }

  final String id;
  final String label;

  /// [label] em cada idioma da interface; vazio em catálogos antigos.
  final Map<String, String> labels;

  /// Opções da escolha; a primeira é a padrão. Vazio = numérico. Os
  /// `labels` são o `label` em cada idioma, como no modificador.
  final List<({String label, Map<String, String> labels, int rolls})> options;
  final int? min;
  final int? max;

  /// O número sobe com o +1 da caçada (o Search Level sobe a cada
  /// encontro).
  final bool followsCount;

  /// Só aparece com esta opção (índice) deste modificador.
  final (String, int)? when;

  bool get isNumber => options.isEmpty;

  int rollsFor(int? value) =>
      isNumber ? 0 : options[(value ?? 0).clamp(0, options.length - 1)].rolls;
}

/// Odds por duas escolhas (Ultra Wormhole: anéis × distância). `null` =
/// combinação que não existe.
class OddsTable {
  const OddsTable({
    required this.rows,
    required this.columns,
    required this.odds,
  });

  factory OddsTable.fromJson(Map<String, dynamic> json) => OddsTable(
    rows: json['rows'] as String,
    columns: json['columns'] as String,
    odds: [
      for (final row in json['odds'] as List)
        [for (final x in row as List) (x as num?)?.toDouble()],
    ],
  );

  final String rows;
  final String columns;
  final List<List<double?>> odds;

  double? oddsAt(int row, int column) => odds[row][column];
}

/// `"1/1365"`: a chance como fração (arredonda o denominador).
String oddsLabel(double chance) {
  if (chance <= 0) return '—';
  final x = 1 / chance;
  return x < 10
      ? '1/${x.toStringAsFixed(1).replaceAll('.', ',')}'
      : '1/${x.round()}';
}
