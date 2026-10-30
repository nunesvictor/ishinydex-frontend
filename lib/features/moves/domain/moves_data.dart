/// O pacote dos golpes (`moves-AAAA.MM.DD.json`, backend#134), à parte do
/// catálogo: o app só o baixa ao abrir a aba Golpes (#36).
///
/// Compacto, com índices: `moves` (os golpes, cada um com os valores atuais
/// e, em `past`, os de jogos antigos), `versionGroups` e `methods` (nomes por
/// índice), `learnsets` (por id de Pokémon e índice do grupo, a lista plana
/// `[golpe, modo, nível...]`) e `machines` (por grupo, o item da TM de cada
/// golpe). As listas de cada Pokémon só são lidas quando ele é aberto.
class MovesData {
  MovesData._({
    required this.moves,
    required this.versionGroups,
    required this.methods,
    required this._learnsets,
    required this._machines,
  });

  factory MovesData.fromJson(Map<String, dynamic> json) => MovesData._(
    moves: [
      for (final (i, m) in (json['moves'] as List).indexed)
        MoveInfo.fromJson(i, m as Map<String, dynamic>),
    ],
    versionGroups: [for (final g in json['versionGroups'] as List) g as String],
    methods: [for (final m in json['methods'] as List) m as String],
    learnsets: json['learnsets'] as Map<String, dynamic>,
    machines: json['machines'] as Map<String, dynamic>,
  );

  final List<MoveInfo> moves;
  final List<String> versionGroups;
  final List<String> methods;
  final Map<String, dynamic> _learnsets;
  final Map<String, dynamic> _machines;

  /// Os grupos de versões em que o Pokémon [pokemonId] aprende golpes.
  List<String> groupsOf(int pokemonId) => switch (_learnsets['$pokemonId']) {
    final Map<String, dynamic> byGroup => [
      for (final index in byGroup.keys) versionGroups[int.parse(index)],
    ],
    _ => const [],
  };

  /// O que o Pokémon [pokemonId] aprende no grupo [group].
  List<MoveLearn> learnset(int pokemonId, String group) {
    final index = versionGroups.indexOf(group);
    final flat = switch (_learnsets['$pokemonId']) {
      final Map<String, dynamic> byGroup => byGroup['$index'] as List?,
      _ => null,
    };
    if (flat == null) return const [];
    return [
      for (var i = 0; i + 2 < flat.length; i += 3)
        MoveLearn(
          move: moves[flat[i] as int],
          method: methods[flat[i + 1] as int],
          level: flat[i + 2] as int,
          machine: switch (_machines[group]) {
            final Map<String, dynamic> byMove =>
              byMove['${flat[i]}'] as String?,
            _ => null,
          },
        ),
    ];
  }
}

/// Um golpe: nome em inglês, tipo, categoria e os valores atuais; os de jogos
/// antigos em [past].
class MoveInfo {
  const MoveInfo({
    required this.index,
    required this.name,
    required this.label,
    required this.type,
    required this.category,
    required this.pp,
    this.power,
    this.accuracy,
    this.priority = 0,
    this.target = '',
    this.effect = '',
    this.past = const [],
  });

  factory MoveInfo.fromJson(int index, Map<String, dynamic> json) => MoveInfo(
    index: index,
    name: json['name'] as String,
    label: json['label'] as String,
    type: json['type'] as String,
    category: json['category'] as String,
    power: json['power'] as int?,
    accuracy: json['accuracy'] as int?,
    pp: json['pp'] as int,
    priority: json['priority'] as int? ?? 0,
    target: json['target'] as String? ?? '',
    effect: json['effect'] as String? ?? '',
    past: [
      for (final p in json['past'] as List? ?? const [])
        PastMoveValues.fromJson(p as Map<String, dynamic>),
    ],
  );

  /// A posição no pacote (a chave das TMs).
  final int index;

  /// O nome na PokéAPI (`flamethrower`).
  final String name;

  /// O nome em inglês (`Flamethrower`).
  final String label;
  final String type;

  /// `physical`, `special` ou `status`.
  final String category;
  final int? power;
  final int? accuracy;
  final int pp;
  final int priority;
  final String target;

  /// O efeito em inglês (vazio quando a PokéAPI não tem).
  final String effect;
  final List<PastMoveValues> past;

  /// Os valores no grupo [group]: os de [past] valem nos grupos anteriores
  /// ao de cada um ([orderOf] dá a ordem de lançamento); o mais próximo
  /// depois de [group] vence, e `null` nele é "igual ao atual".
  MoveStats statsIn(String group, int Function(String group) orderOf) {
    final order = orderOf(group);
    final later =
        [
          for (final p in past)
            if (orderOf(p.versionGroup) > order) p,
        ]..sort(
          (a, b) => orderOf(a.versionGroup).compareTo(orderOf(b.versionGroup)),
        );
    final values = later.firstOrNull;
    return (
      type: values?.type ?? type,
      power: values?.power ?? power,
      accuracy: values?.accuracy ?? accuracy,
      pp: values?.pp ?? pp,
    );
  }
}

/// Os valores de um golpe antes de [versionGroup] (`null` = igual ao atual).
class PastMoveValues {
  const PastMoveValues({
    required this.versionGroup,
    this.power,
    this.accuracy,
    this.pp,
    this.type,
  });

  factory PastMoveValues.fromJson(Map<String, dynamic> json) => PastMoveValues(
    versionGroup: json['versionGroup'] as String,
    power: json['power'] as int?,
    accuracy: json['accuracy'] as int?,
    pp: json['pp'] as int?,
    type: json['type'] as String?,
  );

  final String versionGroup;
  final int? power;
  final int? accuracy;
  final int? pp;
  final String? type;
}

/// Os valores de um golpe num jogo.
typedef MoveStats = ({String type, int? power, int? accuracy, int pp});

/// Um golpe que a forma aprende num jogo: o modo (`level-up`, `machine`,
/// `egg`, `tutor`...), o nível e, por TM, o item (`tm71`).
class MoveLearn {
  const MoveLearn({
    required this.move,
    required this.method,
    required this.level,
    this.machine,
  });

  final MoveInfo move;
  final String method;
  final int level;
  final String? machine;

  /// O número da TM (`tm71` → 71); `null` sem TM.
  int? get machineNumber => switch (machine) {
    final String item => int.tryParse(item.replaceAll(RegExp('[^0-9]'), '')),
    null => null,
  };

  /// O tipo de máquina, em maiúsculas: `TM`, `HM` ou `TR`.
  String get machineKind =>
      (machine ?? 'tm').replaceAll(RegExp('[0-9]'), '').toUpperCase();
}
