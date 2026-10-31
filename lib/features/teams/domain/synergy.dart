import 'package:ishinydex/core/utils/type_chart.dart';

/// A sinergia do time (#374): uma nota de 0 a 100, com a explicação de
/// cada desconto, a análise do Tera e as sugestões. O domínio só faz as
/// contas; quem monta os membros (tipos, golpes, velocidade) é a tela.
///
/// - **Defesa (40):** para cada tipo de ataque, quantos membros são fracos,
///   resistem ou são imunes. Cada buraco (3 ou mais fracos, ou 2 fracos e
///   ninguém resiste) tira 8; cada membro que leva 4× tira 2.
/// - **Ataque (30):** os tipos de defesa que os golpes de dano acertam em
///   super efetivo valem até 24; mais 6 se nenhum tipo resiste a todos
///   os golpes (2 a menos por tipo que resiste).
/// - **Equilíbrio (30):** físicos e especiais (10 com 2 ou mais de cada, 5
///   com algum de cada), velocidade (10 com 2 ou mais rápidos, 5 com um; com
///   Trick Room no time, contam os lentos) e repetição (10, menos 5 por tipo
///   em 3 ou mais membros, 5 por membro sem golpe de dano e 2 por vaga).
///
/// Os pesos são o ponto de partida, para ajustar com o uso.
class SynergyRules {
  const SynergyRules({this.withFairy = true});

  /// Da 6ª geração em diante; antes, sem o Fairy e com o Steel mais forte.
  final bool withFairy;

  List<String> get types => [
    for (final type in pokemonTypes)
      if (withFairy || type != 'fairy') type,
  ];

  double effect(String attack, String defense) =>
      effectiveness(attack, defense, withFairy: withFairy);

  static const defenseMax = 40;
  static const attackMax = 30;
  static const balanceMax = 30;
  static const holePoints = 8;
  static const quadPoints = 2;
  static const coveragePoints = 24;
  static const wallPoints = 6;
  static const wallStep = 2;
  static const mixPoints = 10;
  static const speedPoints = 10;
  static const repeatPoints = 10;
  static const repeatedTypePoints = 5;
  static const noDamagePoints = 5;
  static const emptySlotPoints = 2;

  /// Rápido: 150 ou mais de velocidade no nível 50.
  static const fastSpeed = 150;

  /// Com Trick Room, lento: 80 ou menos no nível 50.
  static const slowSpeed = 80;

  static const slots = 6;
}

/// Um golpe de dano: o tipo (no jogo) e a categoria.
typedef SynergyMove = ({
  String name,
  String label,
  String type,
  String category,
  int? power,
});

/// Um membro, do jeito que a sinergia precisa: os tipos, a habilidade, os
/// golpes de dano, a velocidade no nível 50, se tem Trick Room e o Tera.
class SynergyMember {
  const SynergyMember({
    required this.name,
    required this.types,
    this.ability,
    this.moves = const [],
    this.speed = 0,
    this.trickRoom = false,
    this.tera,
  });

  final String name;
  final List<String> types;
  final String? ability;

  /// Só os de dano.
  final List<SynergyMove> moves;
  final int speed;
  final bool trickRoom;
  final String? tera;

  /// Físico ou especial, pela maioria dos golpes de dano; `null` sem golpe.
  String? get role {
    final physical = moves.where((m) => m.category == 'physical').length;
    final special = moves.where((m) => m.category == 'special').length;
    if (physical == 0 && special == 0) return null;
    return physical >= special ? 'physical' : 'special';
  }

  SynergyMember copyWith({List<String>? types, List<SynergyMove>? moves}) =>
      SynergyMember(
        name: name,
        types: types ?? this.types,
        ability: ability,
        moves: moves ?? this.moves,
        speed: speed,
        trickRoom: trickRoom,
        tera: tera,
      );
}

/// As habilidades que tiram ou reduzem o dano de um tipo (a lista curta do
/// #374): o multiplicador por tipo de ataque.
const abilityDefense = <String, Map<String, double>>{
  'levitate': {'ground': 0},
  'earth-eater': {'ground': 0},
  'flash-fire': {'fire': 0},
  'well-baked-body': {'fire': 0},
  'water-absorb': {'water': 0},
  'storm-drain': {'water': 0},
  'dry-skin': {'water': 0},
  'volt-absorb': {'electric': 0},
  'lightning-rod': {'electric': 0},
  'motor-drive': {'electric': 0},
  'sap-sipper': {'grass': 0},
  'thick-fat': {'fire': 0.5, 'ice': 0.5},
  'heatproof': {'fire': 0.5},
  'water-bubble': {'fire': 0.5},
  'purifying-salt': {'ghost': 0.5},
};

/// Uma linha da tabela de defesa: o tipo de ataque, o dano em cada membro
/// e se é buraco.
typedef DefenseRow = ({
  String type,
  List<double> multipliers,
  int weak,
  int resist,
  bool hole,
});

/// O que tira pontos da nota.
sealed class SynergyIssue {
  const SynergyIssue(this.points);

  /// Quanto tira (positivo).
  final int points;
}

/// Buraco: os membros [weak] são fracos a [type].
class HoleIssue extends SynergyIssue {
  const HoleIssue(this.type, this.weak, {required this.resisted})
    : super(SynergyRules.holePoints);

  final String type;
  final List<String> weak;

  /// Alguém resiste (o buraco é de 3 ou mais fracos).
  final bool resisted;
}

/// [member] leva 4× de [type].
class QuadIssue extends SynergyIssue {
  const QuadIssue(this.type, this.member) : super(SynergyRules.quadPoints);

  final String type;
  final String member;
}

/// Nenhum golpe de dano acerta [types] em super efetivo.
class UncoveredIssue extends SynergyIssue {
  const UncoveredIssue(this.types, super.points);

  final List<String> types;
}

/// [types] resistem a todos os golpes de dano do time.
class WallIssue extends SynergyIssue {
  const WallIssue(this.types, super.points);

  final List<String> types;
}

/// Poucos físicos ou especiais.
class MixIssue extends SynergyIssue {
  const MixIssue(this.physical, this.special, super.points);

  final int physical;
  final int special;
}

/// Poucos rápidos (ou, com Trick Room, poucos lentos).
class SpeedIssue extends SynergyIssue {
  const SpeedIssue(this.count, super.points, {required this.trickRoom});

  final int count;
  final bool trickRoom;
}

/// [type] em [count] membros.
class RepeatedTypeIssue extends SynergyIssue {
  const RepeatedTypeIssue(this.type, this.count)
    : super(SynergyRules.repeatedTypePoints);

  final String type;
  final int count;
}

/// [member] sem golpe de dano.
class NoDamageIssue extends SynergyIssue {
  const NoDamageIssue(this.member) : super(SynergyRules.noDamagePoints);

  final String member;
}

/// [count] vagas no time.
class EmptySlotsIssue extends SynergyIssue {
  const EmptySlotsIssue(this.count)
    : super(SynergyRules.emptySlotPoints * count);

  final int count;
}

/// O que acontece com a defesa se o membro `index` terastalizar no `tera`:
/// a diferença na defesa, os buracos que fecha e abre e, se outro Tera
/// fosse melhor, qual.
typedef TeraOutcome = ({
  int index,
  String tera,
  int delta,
  List<String> closes,
  List<String> opens,
  ({String type, int delta})? better,
});

/// Um golpe que o membro `index` já aprende e que aumenta o ataque.
typedef MoveSuggestion = ({
  int index,
  SynergyMove move,
  int gain,
  List<String> hits,
  bool stab,
});

/// Uma combinação de tipos que aumenta a nota: numa vaga (`replaces`
/// `null`) ou no lugar do membro `replaces`, e as formas que a têm.
typedef FormSuggestion = ({
  List<String> types,
  int? replaces,
  int gain,
  List<String> closes,
  List<String> covers,
  List<int> forms,
});

/// A sinergia de um time.
class Synergy {
  Synergy._({
    required this.rules,
    required this.members,
    required this.rows,
    required this.coverage,
    required this.defense,
    required this.attack,
    required this.balance,
    required this.issues,
    required this.physical,
    required this.special,
    required this.trickRoom,
  });

  factory Synergy.of(
    List<SynergyMember> members, {
    SynergyRules rules = const SynergyRules(),
  }) {
    final (defense, rows, defenseIssues) = _defense(members, rules);
    final (attack, coverage, attackIssues) = _attack(members, rules);
    final physical = members.where((m) => m.role == 'physical').length;
    final special = members.where((m) => m.role == 'special').length;
    final trickRoom = members.any((m) => m.trickRoom);
    final balanceIssues = <SynergyIssue>[];
    final mix = physical >= 2 && special >= 2
        ? SynergyRules.mixPoints
        : physical > 0 && special > 0
        ? SynergyRules.mixPoints ~/ 2
        : 0;
    if (mix < SynergyRules.mixPoints) {
      balanceIssues.add(
        MixIssue(physical, special, SynergyRules.mixPoints - mix),
      );
    }
    final quick = members
        .where(
          (m) => trickRoom
              ? m.speed <= SynergyRules.slowSpeed
              : m.speed >= SynergyRules.fastSpeed,
        )
        .length;
    final speed = quick >= 2
        ? SynergyRules.speedPoints
        : quick == 1
        ? SynergyRules.speedPoints ~/ 2
        : 0;
    if (speed < SynergyRules.speedPoints) {
      balanceIssues.add(
        SpeedIssue(
          quick,
          SynergyRules.speedPoints - speed,
          trickRoom: trickRoom,
        ),
      );
    }
    var repeat = SynergyRules.repeatPoints;
    for (final type in rules.types) {
      final count = members.where((m) => m.types.contains(type)).length;
      if (count >= 3) {
        repeat -= SynergyRules.repeatedTypePoints;
        balanceIssues.add(RepeatedTypeIssue(type, count));
      }
    }
    for (final m in members) {
      if (m.moves.isEmpty) {
        repeat -= SynergyRules.noDamagePoints;
        balanceIssues.add(NoDamageIssue(m.name));
      }
    }
    final empty = SynergyRules.slots - members.length;
    if (empty > 0) {
      repeat -= SynergyRules.emptySlotPoints * empty;
      balanceIssues.add(EmptySlotsIssue(empty));
    }
    return Synergy._(
      rules: rules,
      members: members,
      rows: rows,
      coverage: coverage,
      defense: defense,
      attack: attack,
      balance: mix + speed + (repeat < 0 ? 0 : repeat),
      issues: [...defenseIssues, ...attackIssues, ...balanceIssues],
      physical: physical,
      special: special,
      trickRoom: trickRoom,
    );
  }

  final SynergyRules rules;
  final List<SynergyMember> members;
  final List<DefenseRow> rows;

  /// Por tipo de defesa, os golpes (membro, golpe) que o acertam em 2×.
  final Map<String, List<(int, SynergyMove)>> coverage;
  final int defense;
  final int attack;
  final int balance;
  final List<SynergyIssue> issues;
  final int physical;
  final int special;

  /// Algum membro tem Trick Room: a velocidade conta ao contrário.
  final bool trickRoom;

  int get score => defense + attack + balance;

  /// O dano de [attack] num membro: os tipos e a habilidade.
  static double _taken(SynergyMember m, String attack, SynergyRules rules) {
    var result = 1.0;
    for (final type in m.types) {
      if (isChartType(type)) result *= rules.effect(attack, type);
    }
    return result * (abilityDefense[m.ability]?[attack] ?? 1);
  }

  static (int, List<DefenseRow>, List<SynergyIssue>) _defense(
    List<SynergyMember> members,
    SynergyRules rules,
  ) {
    var points = SynergyRules.defenseMax;
    final rows = <DefenseRow>[];
    final issues = <SynergyIssue>[];
    for (final type in rules.types) {
      final multipliers = [for (final m in members) _taken(m, type, rules)];
      final weak = multipliers.where((x) => x > 1).length;
      final resist = multipliers.where((x) => x < 1).length;
      final hole = weak >= 3 || (weak >= 2 && resist == 0);
      if (hole) {
        points -= SynergyRules.holePoints;
        issues.add(
          HoleIssue(type, [
            for (final (i, x) in multipliers.indexed)
              if (x > 1) members[i].name,
          ], resisted: resist > 0),
        );
      }
      for (final (i, x) in multipliers.indexed) {
        if (x >= 4) {
          points -= SynergyRules.quadPoints;
          issues.add(QuadIssue(type, members[i].name));
        }
      }
      rows.add((
        type: type,
        multipliers: multipliers,
        weak: weak,
        resist: resist,
        hole: hole,
      ));
    }
    return (points < 0 ? 0 : points, rows, issues);
  }

  static (int, Map<String, List<(int, SynergyMove)>>, List<SynergyIssue>)
  _attack(List<SynergyMember> members, SynergyRules rules) {
    final types = rules.types;
    final coverage = {
      for (final defense in types)
        defense: [
          for (final (i, m) in members.indexed)
            for (final move in m.moves)
              if (rules.effect(move.type, defense) > 1) (i, move),
        ],
    };
    final uncovered = [
      for (final type in types)
        if (coverage[type]!.isEmpty) type,
    ];
    final moves = [for (final m in members) ...m.moves];
    final walls = [
      for (final type in types)
        if (moves.every((move) => rules.effect(move.type, type) < 1)) type,
    ];
    final covered =
        (SynergyRules.coveragePoints *
                (types.length - uncovered.length) /
                types.length)
            .round();
    final wallPoints =
        SynergyRules.wallPoints - SynergyRules.wallStep * walls.length;
    final wall = wallPoints < 0 ? 0 : wallPoints;
    return (
      covered + wall,
      coverage,
      [
        if (uncovered.isNotEmpty)
          UncoveredIssue(uncovered, SynergyRules.coveragePoints - covered),
        if (walls.isNotEmpty) WallIssue(walls, SynergyRules.wallPoints - wall),
      ],
    );
  }

  /// Os buracos da defesa (tipos).
  Set<String> get _holes => {
    for (final row in rows)
      if (row.hole) row.type,
  };

  /// Se o membro [index] terastalizar no [tera] (só a defesa: só um
  /// membro terastaliza por batalha). O Stellar não muda os tipos.
  TeraOutcome teraOf(int index, String tera) {
    int delta(String type) => _withTypes(index, [type]).defense - defense;
    final teraTypes = tera == 'stellar' ? members[index].types : [tera];
    final after = _withTypes(index, teraTypes);
    final chosen = after.defense - defense;
    ({String type, int delta})? better;
    for (final type in rules.types) {
      final d = delta(type);
      if (d > chosen && (better == null || d > better.delta)) {
        better = (type: type, delta: d);
      }
    }
    return (
      index: index,
      tera: tera,
      delta: chosen,
      closes: [
        for (final type in _holes)
          if (!after._holes.contains(type)) type,
      ],
      opens: [
        for (final type in after._holes)
          if (!_holes.contains(type)) type,
      ],
      better: better,
    );
  }

  Synergy _withTypes(int index, List<String> types) => Synergy.of([
    for (final (i, m) in members.indexed)
      if (i == index) m.copyWith(types: types) else m,
  ], rules: rules);

  /// Os golpes que os membros já aprendem ([learnable]: membro → golpes de
  /// dano do jogo) e que aumentam o ataque: da categoria do membro, com
  /// poder 60 ou mais (quando o jogo tem o poder). O melhor de cada membro,
  /// do que mais soma ao que menos, até [limit].
  List<MoveSuggestion> moveSuggestions(
    List<SynergyMove> Function(int index) learnable, {
    int limit = 6,
  }) {
    final result = <MoveSuggestion>[];
    for (final (i, m) in members.indexed) {
      final known = {for (final move in m.moves) move.name};
      MoveSuggestion? best;
      for (final move in learnable(i)) {
        if (known.contains(move.name)) continue;
        if (m.role != null && move.category != m.role) continue;
        if ((move.power ?? 60) < 60) continue;
        final after = _attack([
          for (final (j, other) in members.indexed)
            if (j == i)
              other.copyWith(moves: [...other.moves, move])
            else
              other,
        ], rules);
        final gain = after.$1 - attack;
        if (gain <= 0) continue;
        final suggestion = (
          index: i,
          move: move,
          gain: gain,
          hits: [
            for (final type in rules.types)
              if (coverage[type]!.isEmpty && after.$2[type]!.isNotEmpty) type,
          ],
          stab: m.types.contains(move.type),
        );
        if (best == null || _rank(suggestion).compareTo(_rank(best)) > 0) {
          best = suggestion;
        }
      }
      if (best != null) result.add(best);
    }
    result.sort((a, b) => _rank(b).compareTo(_rank(a)));
    return result.take(limit).toList();
  }

  /// Mais ganho; no empate, o do mesmo tipo e, depois, o mais forte.
  static int _rank(MoveSuggestion s) =>
      s.gain * 100000 + (s.stab ? 10000 : 0) + (s.move.power ?? 0);

  /// As combinações de tipos das formas do jogo ([candidates]: forma →
  /// tipos) que mais aumentam a defesa e o ataque: numa vaga, ou no lugar
  /// do membro que menos soma. A forma sugerida conta só com os golpes dos
  /// próprios tipos (os golpes se escolhem depois). Até [limit] grupos.
  List<FormSuggestion> formSuggestions(
    Map<int, List<String>> candidates, {
    int limit = 3,
  }) {
    final base = defense + attack;
    final groups = <String, List<int>>{};
    final typesOf = <String, List<String>>{};
    for (final MapEntry(key: form, value: types) in candidates.entries) {
      // Flying/Steel e Steel/Flying são o mesmo grupo.
      final key = ([...types]..sort()).join('/');
      (groups[key] ??= []).add(form);
      typesOf[key] ??= types;
    }
    final result = <FormSuggestion>[];
    for (final MapEntry(:key, value: forms) in groups.entries) {
      final types = typesOf[key]!;
      final candidate = SynergyMember(
        name: key,
        types: types,
        moves: [
          for (final type in types)
            (name: type, label: type, type: type, category: '', power: null),
        ],
      );
      final options = members.length < SynergyRules.slots
          ? [
              (null, [...members, candidate]),
            ]
          : [
              for (var j = 0; j < members.length; j++)
                (
                  j,
                  [
                    for (final (i, m) in members.indexed)
                      if (i == j) candidate else m,
                  ],
                ),
            ];
      ({int? replaces, Synergy after, int gain})? best;
      for (final (replaces, team) in options) {
        final after = Synergy.of(team, rules: rules);
        final gain = after.defense + after.attack - base;
        if (best == null || gain > best.gain) {
          best = (replaces: replaces, after: after, gain: gain);
        }
      }
      if (best == null || best.gain <= 0) continue;
      final after = best.after;
      result.add((
        types: types,
        replaces: best.replaces,
        gain: best.gain,
        closes: [
          for (final type in _holes)
            if (!after._holes.contains(type)) type,
        ],
        covers: [
          for (final type in rules.types)
            if (coverage[type]!.isEmpty && after.coverage[type]!.isNotEmpty)
              type,
        ],
        forms: forms,
      ));
    }
    result.sort((a, b) => b.gain.compareTo(a.gain));
    return result.take(limit).toList();
  }
}
