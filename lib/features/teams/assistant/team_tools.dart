import 'package:ishinydex/core/utils/pokemon_types.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/moves/domain/moves_data.dart';
import 'package:ishinydex/features/moves/presentation/moves_widgets.dart';
import 'package:ishinydex/features/teams/domain/models.dart';
import 'package:ishinydex/features/teams/domain/synergy.dart';
import 'package:ishinydex/features/teams/presentation/synergy_page.dart';
import 'package:ishinydex/features/teams/presentation/team_widgets.dart';

/// Spike #418: as ferramentas que o modelo de linguagem chama.
///
/// O modelo não faz contas: cada ferramenta roda as regras que o app já tem
/// (a sinergia do #374) e devolve um mapa pequeno, em pt-BR, que o modelo só
/// explica. Os nomes e as descrições são o que o modelo lê para decidir
/// quando chamar; os mapas são o que ele vê depois.
///
/// Fica separado do pacote de IA (só Dart puro) para dar para testar sem
/// modelo nenhum.
class TeamTools {
  TeamTools({
    required this.team,
    required this.catalog,
    required this.data,
    this.owned = const {},
  });

  final Team team;
  final Catalog catalog;
  final MovesData data;

  /// As formas que o usuário tem (espécimes nos saves).
  final Set<int> owned;

  late final Synergy synergy = teamSynergy(team, catalog, data);

  /// As declarações, no formato JSON Schema que o pacote repassa ao modelo.
  static const declarations = <ToolDeclaration>[
    (
      name: 'analisar_time',
      description:
          'Devolve a nota de sinergia do time (0 a 100), as três partes '
          '(defesa, ataque, equilíbrio), os membros e o que tira pontos. '
          'Use antes de opinar sobre o time.',
      parameters: {'type': 'object'},
    ),
    (
      name: 'sugerir_formas',
      description:
          'Sugere combinações de tipos (e Pokémon que as têm) que mais '
          'aumentam a nota, numa vaga ou no lugar de um membro. Marca os que '
          'o usuário já tem. Use quando pedirem uma troca ou um reforço.',
      parameters: {'type': 'object'},
    ),
    (
      name: 'sugerir_golpes',
      description:
          'Sugere golpes que os membros já aprendem neste jogo e que '
          'aumentam o ataque do time. Use quando perguntarem sobre golpes.',
      parameters: {'type': 'object'},
    ),
    (
      name: 'simular_troca',
      description:
          'Calcula a nota do time trocando um membro por outro Pokémon. Use '
          'para conferir uma troca antes de recomendá-la.',
      parameters: {
        'type': 'object',
        'properties': {
          'sai': {
            'type': 'string',
            'description': 'Nome do membro que sai (como em analisar_time).',
          },
          'entra': {
            'type': 'string',
            'description': 'Nome do Pokémon que entra (ex.: Garchomp).',
          },
        },
        'required': ['sai', 'entra'],
      },
    ),
  ];

  /// Roda a ferramenta [name]. Erros viram `{erro: …}`, para o modelo
  /// explicar em vez de o app quebrar.
  Map<String, Object?> run(String name, Map<String, Object?> args) =>
      switch (name) {
        'analisar_time' => analyze(),
        'sugerir_formas' => suggestForms(),
        'sugerir_golpes' => suggestMoves(),
        'simular_troca' => simulateSwap(
          '${args['sai'] ?? ''}',
          '${args['entra'] ?? ''}',
        ),
        _ => {'erro': 'Ferramenta desconhecida: $name.'},
      };

  Map<String, Object?> analyze() => {
    'jogo': gameLabel(catalog, team.versionGroup),
    ..._score(synergy),
    'membros': [
      for (final m in synergy.members)
        {
          'nome': m.name,
          'tipos': [for (final t in m.types) typeLabel(t)],
          'papel': switch (m.role) {
            'physical' => 'físico',
            'special' => 'especial',
            _ => 'sem golpe de dano',
          },
          'velocidade_nivel_50': m.speed,
          if (m.tera != null) 'tera': typeLabel(m.tera!),
        },
    ],
    'problemas': [for (final i in synergy.issues) issueText(i)],
  };

  Map<String, Object?> suggestForms() {
    final inTeam = {for (final m in team.members) m.form};
    final group = team.versionGroup;
    final suggestions = synergy.formSuggestions({
      for (final id in catalog.formIds)
        if (!inTeam.contains(id) &&
            catalog.isDefaultForm(id) &&
            formInGame(data, catalog, id, group))
          id: [for (final t in catalog.formDetail(id).types) t.type],
    });
    return {
      'sugestoes': [
        for (final s in suggestions)
          {
            'tipos': [for (final t in s.types) typeLabel(t)],
            'onde': switch (s.replaces) {
              final i? => 'no lugar de ${synergy.members[i].name}',
              null => 'numa vaga',
            },
            'pontos_a_mais': s.gain,
            if (s.closes.isNotEmpty)
              'fecha_fraquezas': [for (final t in s.closes) typeLabel(t)],
            if (s.covers.isNotEmpty)
              'passa_a_acertar': [for (final t in s.covers) typeLabel(t)],
            'pokemon': _examples(s.forms),
          },
      ],
    };
  }

  /// Até 5 nomes: os que o usuário tem primeiro, depois pela Pokédex.
  List<String> _examples(List<int> forms) {
    final refs = [for (final id in forms) catalog.formRef(id)]
      ..sort((a, b) {
        final owns = (owned.contains(b.id) ? 1 : 0).compareTo(
          owned.contains(a.id) ? 1 : 0,
        );
        return owns != 0
            ? owns
            : (a.nationalNumber ?? 0).compareTo(b.nationalNumber ?? 0);
      });
    return [
      for (final f in refs.take(5))
        if (owned.contains(f.id))
          '${f.displayName} (você tem)'
        else
          f.displayName,
    ];
  }

  Map<String, Object?> suggestMoves() {
    final group = team.versionGroup;
    final suggestions = synergy.moveSuggestions((i) {
      final member = team.members[i];
      final form = catalog.formDetail(member.form).name;
      return [
        for (final learns in formLearnset(
          data,
          catalog,
          member.form,
          group,
        ).values)
          if (learns.first.move.category != 'status')
            synergyMove(learns.first.move, form, group, catalog),
      ];
    });
    return {
      'sugestoes': [
        for (final s in suggestions)
          {
            'membro': synergy.members[s.index].name,
            'golpe': s.move.label,
            'tipo': typeLabel(s.move.type),
            'mesmo_tipo_do_pokemon': s.stab,
            'pontos_a_mais': s.gain,
            if (s.hits.isNotEmpty)
              'passa_a_acertar': [for (final t in s.hits) typeLabel(t)],
          },
      ],
    };
  }

  Map<String, Object?> simulateSwap(String out, String into) {
    final index = synergy.members.indexWhere((m) => _same(m.name, out));
    if (index < 0) {
      return {
        'erro':
            '"$out" não está no time. Membros: '
            '${synergy.members.map((m) => m.name).join(', ')}.',
      };
    }
    final form = findForm(into);
    if (form == null) return {'erro': 'Não achei o Pokémon "$into".'};
    final group = team.versionGroup;
    if (!formInGame(data, catalog, form, group)) {
      return {
        'erro':
            '${catalog.formRef(form).displayName} não está em '
            '${gameLabel(catalog, group)}.',
      };
    }
    final types = [for (final t in catalog.formDetail(form).types) t.type];
    final name = catalog.formRef(form).displayName;
    // Como nas sugestões de formas: o novo membro conta com um golpe de
    // cada tipo seu (os golpes se escolhem depois).
    final candidate = SynergyMember(
      name: name,
      types: types,
      moves: [
        for (final type in types)
          (name: type, label: type, type: type, category: '', power: null),
      ],
    );
    final after = Synergy.of([
      for (final (i, m) in synergy.members.indexed)
        if (i == index) candidate else m,
    ], rules: synergy.rules);
    final before = synergy.issues.whereType<HoleIssue>().map((h) => h.type);
    final holes = after.issues.whereType<HoleIssue>().map((h) => h.type);
    return {
      'troca': '${synergy.members[index].name} → $name',
      'tipos_de_quem_entra': [for (final t in types) typeLabel(t)],
      'voce_tem': owned.contains(form),
      'nota_antes': synergy.score,
      ..._score(after),
      'diferenca': after.score - synergy.score,
      'fecha_fraquezas': [
        for (final t in before)
          if (!holes.contains(t)) typeLabel(t),
      ],
      'abre_fraquezas': [
        for (final t in holes)
          if (!before.contains(t)) typeLabel(t),
      ],
      'observacao':
          'Quem entra conta só com golpes dos próprios tipos; os golpes de '
          'verdade mudam a nota.',
    };
  }

  /// A forma padrão cujo nome bate com [name] (sem acento nem caixa); se
  /// nenhuma padrão bater, qualquer forma.
  int? findForm(String name) {
    int? fallback;
    for (final id in catalog.formIds) {
      if (!_same(catalog.formRef(id).displayName, name)) continue;
      if (catalog.isDefaultForm(id)) return id;
      fallback ??= id;
    }
    return fallback;
  }

  static Map<String, Object?> _score(Synergy s) => {
    'nota': s.score,
    'defesa': '${s.defense}/${SynergyRules.defenseMax}',
    'ataque': '${s.attack}/${SynergyRules.attackMax}',
    'equilibrio': '${s.balance}/${SynergyRules.balanceMax}',
  };

  static bool _same(String a, String b) => _key(a) == _key(b);

  static String _key(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[áàâã]'), 'a')
      .replaceAll(RegExp('[éê]'), 'e')
      .replaceAll('í', 'i')
      .replaceAll(RegExp('[óôõ]'), 'o')
      .replaceAll('ú', 'u')
      .replaceAll(RegExp('[^a-z0-9]'), '');
}

/// Uma ferramenta: o nome, a descrição e os parâmetros (JSON Schema).
typedef ToolDeclaration = ({
  String name,
  String description,
  Map<String, Object?> parameters,
});

String _types(List<String> types) => types.map(typeLabel).join(', ');

/// O desconto em uma frase, para o modelo.
String issueText(SynergyIssue issue) => switch (issue) {
  HoleIssue(:final type, :final weak, :final resisted) =>
    'Buraco em ${typeLabel(type)}: ${weak.join(', ')} '
        '${weak.length == 1 ? 'é fraco' : 'são fracos'}'
        '${resisted ? '' : ' e ninguém resiste'} '
        '(−${issue.points}).',
  QuadIssue(:final type, :final member) =>
    '$member leva 4× de ${typeLabel(type)} (−${issue.points}).',
  UncoveredIssue(:final types) =>
    'Nenhum golpe acerta em super efetivo: ${_types(types)} '
        '(−${issue.points}).',
  WallIssue(:final types) =>
    'Resistem a todos os golpes do time: ${_types(types)} '
        '(−${issue.points}).',
  MixIssue(:final physical, :final special) =>
    'Pouca mistura: $physical físico(s) e $special especial(is) '
        '(−${issue.points}).',
  SpeedIssue(:final count, :final trickRoom) =>
    '${trickRoom ? 'Lentos para o Trick Room' : 'Rápidos'}: só $count '
        '(−${issue.points}).',
  RepeatedTypeIssue(:final type, :final count) =>
    '${typeLabel(type)} repetido em $count membros (−${issue.points}).',
  NoDamageIssue(:final member) =>
    '$member não tem golpe de dano (−${issue.points}).',
  EmptySlotsIssue(:final count) =>
    '$count vaga(s) vazia(s) (−${issue.points}).',
};
