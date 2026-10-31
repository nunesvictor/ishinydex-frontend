import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/utils/origin_mark.dart';
import 'package:ishinydex/features/catalog/domain/catalog_labels.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/domain/shiny_odds.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';

/// Pacote do catálogo (`catalog.json`, gerado pelo `exportcatalog` do
/// backend): os dados de referência que o app usa sem servidor.
///
/// As formas são identificadas pelo id da PokéAPI, que não muda de uma base
/// para outra; os sprites são caminhos relativos ao repositório
/// PokeAPI/sprites, resolvidos contra `spriteBase`. Os métodos devolvem os
/// mesmos modelos que a API entrega (`FormRef`, `FormDetail`...), com as
/// mesmas regras do backend.
class Catalog {
  Catalog._({
    required this.version,
    required this.movesFile,
    required this._groupVersions,
    required this.defaultDex,
    required this.options,
    required this.versions,
    required this.transferVersions,
    required this.homeCutoffs,
    required this.shinyLocks,
    required this._forms,
    required this._pokemon,
    required this._species,
    required this._originMarks,
    required this._spriteBase,
    required this._groupOrder,
    required this._groupGenerations,
    required this._pokedexes,
    required this._exclusives,
    required this._gameFormIds,
    required this._gameLocks,
    required this._alphaForms,
    required this._homeEggs,
    required this.shinyMethods,
    required this.shinyOdds,
    required this._formEvolutions,
    required this._withoutEvolution,
    required this._evolutionEdges,
    required this._heldItems,
    required this._heldItemsByGroup,
  });

  /// Lê o JSON do pacote. Formato mais novo que [schemaVersion] →
  /// [DataFailure] (o app precisa ser atualizado).
  factory Catalog.fromJson(
    Map<String, dynamic> json, {
    required String spriteBase,
  }) {
    final schema = json['schemaVersion'] as int;
    if (schema > schemaVersion) {
      throw DataFailure(
        Problem.catalogTooNew(schema: schema, supported: schemaVersion),
      );
    }
    final base = spriteBase.endsWith('/')
        ? spriteBase.substring(0, spriteBase.length - 1)
        : spriteBase;
    String? sprite(Object? path) => path == null ? null : '$base/$path';

    final groups = [
      for (final g in _objects(json['versionGroups']))
        (
          name: g['name'] as String,
          generation: g['generation'] as String,
          order: g['order'] as int,
          versions: [for (final v in g['versions'] as List) v as String],
          originMark: g['originMark'] as String?,
        ),
    ]..sort((a, b) => a.order.compareTo(b.order));
    final groupByName = {for (final g in groups) g.name: g};
    // Os itens seguráveis (backend#138); catálogo antigo, sem a chave: nenhum.
    final held = (json['heldItems'] as Map<String, dynamic>?) ?? const {};
    final heldItems = [
      for (final i in _objects(held['items'] ?? const <Object>[]))
        HeldItem(
          name: i['name'] as String,
          label: i['label'] as String,
          spriteUrl: sprite(i['sprite']),
        ),
    ];
    final versionList = [
      for (final v in _objects(json['versions']))
        (
          name: v['name'] as String,
          group: v['versionGroup'] as String,
          receives: v['receivesFromHome'] as bool,
        ),
    ];
    // A data de corte do HOME (#222): os jogos do Pokémon Bank.
    final homeCutoffs = {
      for (final v in _objects(json['versions']))
        if (v['homeUntil'] case final String until)
          v['name'] as String: DateTime.parse(until),
    };
    // A ordem da série: o grupo (geração e lançamento) e, dentro dele, a
    // ordem do par no grupo (Sun antes de Moon), não a alfabética.
    final groupOrder = {for (final g in groups) g.name: g.order};
    int inGroup(({String name, String group, bool receives}) v) =>
        groupByName[v.group]?.versions.indexOf(v.name) ?? 0;
    versionList.sort(
      (a, b) => switch ((groupOrder[a.group] ?? 0).compareTo(
        groupOrder[b.group] ?? 0,
      )) {
        0 => inGroup(a).compareTo(inGroup(b)),
        final c => c,
      },
    );

    // Os métodos de evolução (backend#133), com os nomes em inglês dos
    // itens, golpes e lugares; catálogo antigo, sem a chave: nenhum.
    final evolution = switch (json['evolutionMethods']) {
      final Map<String, dynamic> e => e,
      _ => const <String, dynamic>{},
    };
    final evolutionNames = switch (evolution['names']) {
      final Map<String, dynamic> n => {
        for (final MapEntry(:key, :value) in n.entries)
          key: (value as Map<String, dynamic>).cast<String, String>(),
      },
      _ => const <String, Map<String, String>>{},
    };
    String? named(String kind, Object? slug) => switch (slug) {
      final String s => evolutionNames[kind]?[s] ?? prettifyName(s),
      _ => null,
    };
    String? species(Object? slug) => slug is String ? prettifyName(slug) : null;
    EvolutionMethod evolutionMethod(Map<String, dynamic> m) {
      final group = m['versionGroup'] as String;
      final item = m['item'] as String?;
      return EvolutionMethod(
        versionGroup: group,
        trigger: m['trigger'] as String,
        versions: groupByName[group]?.versions ?? const [],
        isDefault: m['default'] as bool? ?? false,
        minLevel: m['minLevel'] as int?,
        item: named('items', item),
        itemSpriteUrl: item == null ? null : sprite('items/$item.png'),
        heldItem: named('items', m['heldItem']),
        knownMove: named('moves', m['knownMove']),
        knownMoveType: m['knownMoveType'] as String?,
        usedMove: named('moves', m['usedMove']),
        minMoveCount: m['minMoveCount'] as int?,
        location: named('locations', m['location']),
        nearSpecialRock: m['nearSpecialRock'] as bool?,
        timeOfDay: m['timeOfDay'] as String?,
        minHappiness: m['minHappiness'] as int?,
        minAffection: m['minAffection'] as int?,
        minBeauty: m['minBeauty'] as int?,
        gender: m['gender'] as String?,
        region: m['region'] as String?,
        relativePhysicalStats: m['relativePhysicalStats'] as int?,
        allowedNatures: [
          for (final n in m['allowedNatures'] as List? ?? const []) n as String,
        ],
        needsOverworldRain: m['needsOverworldRain'] as bool?,
        needsMultiplayer: m['needsMultiplayer'] as bool?,
        turnUpsideDown: m['turnUpsideDown'] as bool?,
        tradeSpecies: species(m['tradeSpecies']),
        partySpecies: species(m['partySpecies']),
        partyType: m['partyType'] as String?,
        minSteps: m['minSteps'] as int?,
        minDamageTaken: m['minDamageTaken'] as int?,
        chance: (m['chance'] as num?)?.toDouble(),
      );
    }

    List<Choice> choices(String key) => [
      for (final c in _objects((json['choices'] as Map<String, dynamic>)[key]))
        Choice(
          value: c['value'] as String,
          label: c['label'] as String,
          labels: catalogLabels(c['labels']),
          spriteUrl: sprite(c['sprite']),
          increased: c['increased'] as String?,
          decreased: c['decreased'] as String?,
        ),
    ];

    return Catalog._(
      version: json['version'] as String,
      movesFile: json['movesFile'] as String?,
      groupVersions: {for (final g in groups) g.name: g.versions},
      defaultDex: [for (final id in json['defaultDex'] as List) id as int],
      options: SpecimenOptions(
        language: choices('language'),
        gender: choices('gender'),
        nature: choices('nature'),
        pokeball: choices('pokeball'),
        type: choices('type'),
        generation: choices('generation'),
        originMark: choices('origin_mark'),
      ),
      versions: [
        for (final v in versionList)
          GameVersion(
            name: v.name,
            versionGroup: v.group,
            generation: groupByName[v.group]?.generation ?? '',
          ),
      ],
      homeCutoffs: homeCutoffs,
      transferVersions: {
        for (final v in versionList)
          if (v.receives) v.name,
      },
      shinyLocks: [
        for (final l in _objects(json['shinyLocks']))
          CatalogShinyLock(
            caption: l['caption'] as String,
            description: (l['description'] as String?) ?? '',
            lockType:
                ShinyLockType.fromParam(l['lockType'] as String) ??
                ShinyLockType.unobtainable,
            active: l['active'] as bool,
            forms: [for (final id in l['forms'] as List) id as int],
          ),
      ],
      forms: {
        for (final f in _objects(json['forms']))
          f['id'] as int: _Form(
            id: f['id'] as int,
            name: f['name'] as String,
            formName: f['formName'] as String,
            pokemon: f['pokemon'] as int?,
            isDefault: f['isDefault'] as bool,
            versionGroup: f['versionGroup'] as String,
            types: [for (final t in f['types'] as List) t as String],
            sprite: sprite(f['sprite']) ?? '',
            shinySprite: sprite(f['shinySprite']) ?? '',
            inBattleOnly:
                (f['isBattleOnly'] as bool? ?? false) ||
                (f['isMega'] as bool? ?? false),
          ),
      },
      pokemon: {
        for (final p in _objects(json['pokemon']))
          p['id'] as int: _Pokemon(
            name: p['name'] as String,
            species: p['species'] as String?,
            isDefault: p['isDefault'] as bool,
            height: p['height'] as int,
            weight: p['weight'] as int,
            abilities: [
              for (final a in _objects(p['abilities']))
                FormAbility(
                  slot: a['slot'] as int,
                  ability: a['ability'] as String,
                  isHidden: a['isHidden'] as bool,
                ),
            ],
            stats: [
              for (final s in _objects(p['stats']))
                FormStat(
                  stat: s['stat'] as String,
                  baseStat: s['base'] as int,
                  effort: s['effort'] as int,
                ),
            ],
          ),
      },
      species: {
        for (final s in _objects(json['species']))
          s['name'] as String: _Species(
            name: s['name'] as String,
            nationalNumber: s['nationalNumber'] as int?,
            generation: s['generation'] as String,
            genderRate: s['genderRate'] as int,
            captureRate: s['captureRate'] as int,
            hatchCounter: s['hatchCounter'] as int,
            isBaby: s['isBaby'] as bool,
            isLegendary: s['isLegendary'] as bool,
            isMythical: s['isMythical'] as bool,
            evolvesFrom: s['evolvesFrom'] as String?,
          ),
      },
      originMarks: {
        for (final g in groups)
          for (final v in g.versions) v: g.originMark,
      },
      spriteBase: base,
      groupOrder: groupOrder,
      groupGenerations: {for (final g in groups) g.name: g.generation},
      // Catálogos antigos não têm as pokédex nem os exclusivos.
      pokedexes: [
        for (final p in _objects(json['pokedexes'] ?? const <Object>[]))
          _Pokedex(
            name: p['name'] as String,
            label: p['label'] as String,
            labels: catalogLabels(p['labels']),
            versionGroups: [
              for (final g in p['versionGroups'] as List) g as String,
            ],
            dlc: p['dlc'] as String?,
            entries: {
              for (final e in p['entries'] as List)
                (e as List)[0] as String: e[1] as int?,
            },
          ),
      ],
      exclusives: () {
        final result = <int, Set<String>>{};
        for (final e in _objects(
          json['versionExclusives'] ?? const <Object>[],
        )) {
          for (final id in e['forms'] as List) {
            (result[id as int] ??= {}).add(e['version'] as String);
          }
        }
        return result;
      }(),
      gameFormIds: {
        for (final g in _objects(json['gameForms'] ?? const <Object>[]))
          g['versionGroup'] as String: {
            for (final id in g['forms'] as List) id as int,
          },
      },
      gameLocks: () {
        final result = <int, Set<String>>{};
        for (final l in _objects(json['gameShinyLocks'] ?? const <Object>[])) {
          for (final id in l['forms'] as List) {
            (result[id as int] ??= {}).add(l['version'] as String);
          }
        }
        return result;
      }(),
      // Catálogo antigo, sem a chave: nenhuma forma alfa (#280).
      // Catálogo antigo, sem a chave: nenhuma (#314).
      homeEggs: {
        for (final g in _objects(json['homeEggs'] ?? const <Object>[]))
          g['versionGroup'] as String: {
            for (final id in g['forms'] as List) id as int,
          },
      },
      alphaForms: {
        for (final g in _objects(json['alphaForms'] ?? const <Object>[]))
          g['versionGroup'] as String: {
            for (final id in g['forms'] as List) id as int,
          },
      },
      shinyMethods: [
        for (final m in _objects(json['shinyMethods'] ?? const <Object>[]))
          ShinyMethod(
            id: m['id'] as String,
            label: m['label'] as String,
            labels: catalogLabels(m['labels']),
            units: [for (final u in m['units'] as List) u as String],
            versions: {for (final v in m['versions'] as List) v as String},
          ),
      ],
      shinyOdds: [
        for (final o in _objects(json['shinyOdds'] ?? const <Object>[]))
          OddsRule.fromJson(o),
      ],
      // Catálogo antigo, sem a chave: a linha evolutiva só pela espécie.
      formEvolutions: switch (json['formEvolutions']) {
        {'evolutions': final List<Object?> edges} => [
          for (final e in edges.cast<List<Object?>>())
            (from: e[0]! as int, to: e[1]! as int),
        ],
        _ => const [],
      },
      withoutEvolution: switch (json['formEvolutions']) {
        {'withoutEvolution': final List<Object?> ids} => {
          for (final id in ids) id! as int,
        },
        _ => const {},
      },
      evolutionEdges: {
        for (final e in _objects(evolution['edges'] ?? const <Object>[]))
          (e['from'] as int, e['to'] as int): EvolutionEdge(
            fromId: e['from'] as int,
            toId: e['to'] as int,
            methods: [
              for (final m in _objects(e['methods'])) evolutionMethod(m),
            ],
            texts: catalogLabels(e['texts']),
            link: e['link'] as String?,
          ),
      },
      heldItems: heldItems,
      heldItemsByGroup: {
        for (final MapEntry(:key, :value)
            in ((held['versionGroups'] as Map<String, dynamic>?) ?? const {})
                .entries)
          key: [for (final i in value as List) heldItems[i as int]],
      },
    );
  }

  /// Os métodos de evolução por par de formas (de, para).
  final Map<(int, int), EvolutionEdge> _evolutionEdges;

  /// As ligações por par de espécies, para quando a linha liga formas sem
  /// aresta própria (o Linoone comum → Obstagoon; o Spewpa → Vivillon).
  late final Map<(String?, String?), List<EvolutionEdge>> _edgesBySpecies = () {
    final result = <(String?, String?), List<EvolutionEdge>>{};
    for (final edge in _evolutionEdges.values) {
      final key = (_speciesNameOf(edge.fromId), _speciesNameOf(edge.toId));
      (result[key] ??= []).add(edge);
    }
    return result;
  }();

  String? _speciesNameOf(int formId) => switch (_forms[formId]) {
    final form? => _speciesOf(form)?.name,
    null => null,
  };

  /// As ligações de uma [chain]: cada forma de um estágio com a forma do
  /// estágio anterior da qual vem, e os métodos dessa ligação.
  List<EvolutionEdge> _chainEdges(List<List<FormRef>> chain) => [
    for (final (i, stage) in chain.indexed)
      if (i > 0)
        for (final to in stage) _edgeTo(chain[i - 1], to.id),
  ];

  /// A ligação que chega em [to] vinda de uma das [previous]: pela aresta
  /// do par de formas; sem ela, pelo par de espécies (de preferência com a
  /// mesma forma de destino); sem métodos, se não houver nenhuma.
  EvolutionEdge _edgeTo(List<FormRef> previous, int to) {
    for (final from in previous) {
      if (_evolutionEdges[(from.id, to)] case final edge?) return edge;
    }
    final toSpecies = _speciesNameOf(to);
    final parentSpecies = _species[toSpecies]?.evolvesFrom;
    final from =
        previous
            .where((f) => _speciesNameOf(f.id) == parentSpecies)
            .firstOrNull ??
        previous.first;
    final candidates =
        _edgesBySpecies[(_speciesNameOf(from.id), toSpecies)] ?? const [];
    final edge =
        candidates.where((e) => e.toId == to).firstOrNull ??
        candidates.where((e) => e.fromId == from.id).firstOrNull ??
        candidates.firstOrNull;
    return (edge ?? EvolutionEdge(fromId: from.id, toId: to)).copyWith(
      fromId: from.id,
      toId: to,
    );
  }

  /// As evoluções entre formas das famílias com forma regional
  /// (backend#121): o Rattata de Alola vira o Raticate de Alola, e não o
  /// comum. Vazio em catálogo antigo.
  final List<({int from, int to})> _formEvolutions;

  /// Formas dessas famílias que não evoluem (o Farfetch'd comum).
  final Set<int> _withoutEvolution;

  /// Forma → a forma da qual ela evolui, pelas arestas curadas.
  late final Map<int, int> _formParent = {
    for (final e in _formEvolutions) e.to: e.from,
  };

  /// Forma → as formas em que ela evolui, pelas arestas curadas.
  late final Map<int, List<int>> _formChildren = () {
    final result = <int, List<int>>{};
    for (final e in _formEvolutions) {
      (result[e.from] ??= []).add(e.to);
    }
    return result;
  }();

  /// A forma tem a evolução curada (está numa aresta ou não evolui).
  bool _curated(int formId) =>
      _withoutEvolution.contains(formId) ||
      _formParent.containsKey(formId) ||
      _formChildren.containsKey(formId);

  /// A linha evolutiva de uma forma curada: só o caminho dela, das formas
  /// das quais ela vem até as que vêm dela (o Raichu de Alola: Pichu →
  /// Pikachu → Raichu de Alola). Vazia se ela não evolui nem vem de outra.
  List<List<FormRef>> _formChain(int formId) {
    final up = <int>[];
    final seen = {formId};
    for (var id = _formParent[formId]; id != null && seen.add(id);) {
      up.insert(0, id);
      id = _formParent[id];
    }
    final stages = [
      for (final id in up) [id],
      [formId],
    ];
    while (true) {
      final next = [for (final id in stages.last) ...?_formChildren[id]]
          .where(seen.add)
          .toList();
      if (next.isEmpty) break;
      stages.add(next);
    }
    if (stages.length == 1) return const [];
    return [
      for (final stage in stages) [for (final id in stage) formRef(id)],
    ];
  }

  /// As regras de odds (backend#113; vazio em catálogo antigo).
  final List<OddsRule> shinyOdds;

  /// Os itens seguráveis (backend#138), em ordem de nome em inglês.
  final List<HeldItem> _heldItems;
  final Map<String, List<HeldItem>> _heldItemsByGroup;

  /// Os itens que se seguram no grupo [group] (vazio sem item segurado, ou
  /// em catálogo antigo).
  List<HeldItem> heldItemsIn(String group) =>
      _heldItemsByGroup[group] ?? const [];

  /// O item [name], de qualquer jogo; `null` se o catálogo não o tem.
  HeldItem? heldItem(String name) =>
      _heldItems.where((i) => i.name == name).firstOrNull;

  /// O nome do Pokémon da forma [formId] na PokéAPI e o da espécie
  /// (`ogerpon-cornerstone-mask`, `ogerpon`), e se é o padrão dela: a
  /// base do nome no Showdown (#231). `null` fora do catálogo.
  ({String pokemon, String species, bool isDefault})? pokemonNames(
    int formId,
  ) => switch (_forms[formId]) {
    final form? => switch (_pokemonOf(form)) {
      final pokemon? => (
        pokemon: pokemon.name,
        species: pokemon.species ?? pokemon.name,
        isDefault: pokemon.isDefault,
      ),
      null => null,
    },
    null => null,
  };

  /// A regra de odds do [method] no jogo [version]; `null` sem regra.
  OddsRule? oddsRule(String? method, String? version) => shinyOdds
      .where((o) => o.method == method && o.versions.contains(version))
      .firstOrNull;

  /// Métodos de shiny hunt (vazio em catálogo antigo).
  final List<ShinyMethod> shinyMethods;

  /// Os métodos do jogo [version] do OT: sem OT, ou num jogo sem métodos
  /// curados, todos; vindo do GO ([fromGo]), nenhum.
  List<ShinyMethod> shinyMethodsFor(
    String? version, {
    bool fromGo = false,
    int? formId,
  }) {
    if (fromGo) return const [];
    final mine = [
      for (final m in shinyMethods)
        if (m.versions.contains(version)) m,
    ];
    final all = mine.isEmpty ? shinyMethods : mine;
    // Só pelo HOME, por ovo (#314): os métodos que contam ovos.
    if (formId != null && onlyByEgg(formId, version)) {
      return [
        for (final m in all)
          if (m.units.contains('eggs')) m,
      ];
    }
    return all;
  }

  /// O jogo [version] só aceita a forma pelo HOME, e ela só se caça lá por
  /// ovo (o Phione no Scarlet/Violet, #314).
  bool onlyByEgg(int formId, String? version) =>
      _homeEggs[_groupOfVersion[version]]?.contains(formId) ?? false;

  /// Maior `schemaVersion` que este app sabe ler.
  static const schemaVersion = 1;

  /// `catalog-AAAA.MM.DD`.
  final String version;

  /// O arquivo dos golpes (`moves-AAAA.MM.DD.json`, backend#134), ao lado do
  /// catálogo; `null` em catálogo antigo (sem a aba Golpes).
  final String? movesFile;

  /// As versões de cada grupo (`scarlet-violet` → `scarlet`, `violet`).
  final Map<String, List<String>> _groupVersions;

  /// As versões do grupo [group]; vazio se o catálogo não o tem.
  List<String> versionsOfGroup(String group) =>
      _groupVersions[group] ?? const [];

  /// Os grupos de versões do catálogo.
  Iterable<String> get versionGroupNames => _groupOrder.keys;

  /// A ordem de lançamento do grupo [group] (0 se o catálogo não o tem).
  int versionGroupOrder(String group) => _groupOrder[group] ?? 0;

  /// A geração do grupo [group] (`generation-ix`); `null` se não o tem.
  String? versionGroupGeneration(String group) => _groupGenerations[group];

  /// O grupo da versão [version] (`scarlet` → `scarlet-violet`).
  String? versionGroupOf(String version) => _groupOfVersion[version];

  /// A forma padrão do Pokémon [pokemonId] (quem aprende um golpe, #369);
  /// `null` se o catálogo não o tem.
  FormRef? formOfPokemon(int pokemonId) => switch (_formOfPokemon[pokemonId]) {
    final id? => formRef(id),
    null => null,
  };

  late final Map<int, int> _formOfPokemon = () {
    final result = <int, int>{};
    for (final form in _forms.values) {
      final pokemon = form.pokemon;
      if (pokemon == null) continue;
      if (form.isDefault || !result.containsKey(pokemon)) {
        result[pokemon] = form.id;
      }
    }
    return result;
  }();

  /// Os Pokémon (ids) dos golpes de uma forma, na ordem de preferência: o
  /// dela e o padrão da espécie, para as formas sem golpes próprios na
  /// PokéAPI (as cosméticas).
  List<int> movesPokemonIds(int formId) {
    final form = _forms[formId];
    if (form == null) return const [];
    final species = _speciesOf(form);
    final fallback = species == null ? null : _defaultFormOf(species);
    return [
      ?form.pokemon,
      if (fallback != null)
        if (_forms[fallback]?.pokemon case final id? when id != form.pokemon)
          id,
    ];
  }

  /// Formas de um dex padrão novo, na ordem do esquema.
  final List<int> defaultDex;

  final SpecimenOptions options;

  /// Versões de jogo em ordem de lançamento.
  final List<GameVersion> versions;

  /// Jogos que recebem Pokémon do HOME (podem ser um save).
  final Set<String> transferVersions;

  /// Jogo → até quando ele chega ao HOME (`homeUntil`, #222). Vazio em
  /// catálogo antigo: tudo como antes.
  final Map<String, DateTime> homeCutoffs;

  /// Shiny locks padrão (formas pelo id).
  final List<CatalogShinyLock> shinyLocks;

  final Map<int, _Form> _forms;
  final Map<int, _Pokemon> _pokemon;
  final Map<String, _Species> _species;

  /// Marca de origem de cada versão (`null`: o jogo não tem marca).
  final Map<String, String?> _originMarks;
  final String _spriteBase;

  /// Ordem de lançamento de cada grupo de versões.
  final Map<String, int> _groupOrder;

  /// Geração de cada grupo de versões (`generation-vii`...).
  final Map<String, String> _groupGenerations;

  /// As pokédex dos jogos que recebem do HOME (vazio em catálogo antigo).
  final List<_Pokedex> _pokedexes;

  /// Versões de que cada forma é exclusiva (pode ser de mais de um jogo).
  final Map<int, Set<String>> _exclusives;

  /// Formas presentes em cada grupo, para as espécies com forma regional
  /// (vazio em catálogo antigo).
  final Map<String, Set<int>> _gameFormIds;

  /// Versões em que cada forma não pode ser shiny.
  /// Grupo de versões → formas que podem ser alfa nele.
  final Map<String, Set<int>> _alphaForms;

  /// Grupo de versões → formas que ele aceita pelo HOME, fora das pokédex,
  /// e que só se caçam por ovo.
  final Map<String, Set<int>> _homeEggs;

  final Map<int, Set<String>> _gameLocks;

  /// Grupo → espécies com forma regional listadas nele.
  late final Map<String, Set<String>> _gameFormSpecies = {
    for (final MapEntry(key: group, value: ids) in _gameFormIds.entries)
      group: {
        for (final id in ids)
          if (_forms[id] case final form?) ?_pokemonOf(form)?.species,
      },
  };

  /// A forma aparece no jogo: espécies com forma regional listadas no grupo
  /// só valem com as formas listadas (a Ponyta de Galar não está em
  /// Legends: Arceus, embora a espécie esteja).
  bool _formInGame(int formId, String species, String group) =>
      !(_gameFormSpecies[group]?.contains(species) ?? false) ||
      _gameFormIds[group]!.contains(formId);

  /// O catálogo diz em que pokédex cada espécie está (os saves compatíveis).
  bool get hasPokedexes => _pokedexes.isNotEmpty;

  /// Ids de todas as formas, na ordem da dex nacional.
  Iterable<int> get formIds => _forms.keys;

  bool hasForm(int formId) => _forms.containsKey(formId);

  /// A forma [formId] é mega ou só de batalha (não entra num time).
  bool isBattleForm(int formId) => _forms[formId]?.inBattleOnly ?? false;

  /// Sprite de um item (pokébola) pelo nome.
  String itemSprite(String item) => '$_spriteBase/items/$item.png';

  _Pokemon? _pokemonOf(_Form form) =>
      form.pokemon == null ? null : _pokemon[form.pokemon];

  _Species? _speciesOf(_Form form) {
    final name = _pokemonOf(form)?.species;
    return name == null ? null : _species[name];
  }

  FormRef formRef(int formId) {
    final form = _forms[formId]!;
    return FormRef(
      id: form.id,
      name: form.name,
      formName: form.formName,
      pokeapiId: form.id,
      nationalNumber: _speciesOf(form)?.nationalNumber,
      spriteUrl: form.sprite,
      shinySpriteUrl: form.shinySprite,
    );
  }

  /// Detalhe da forma, como `GET /forms/{id}/`. Os shiny locks dependem do
  /// que o usuário cadastrou: ficam `false` aqui.
  FormDetail formDetail(int formId) {
    final form = _forms[formId]!;
    final pokemon = _pokemonOf(form);
    final species = _speciesOf(form);
    final typeSprites = {for (final c in options.type) c.value: c.spriteUrl};
    final ref = formRef(formId);
    final chain = _curated(formId)
        ? _formChain(formId)
        : species == null
        ? const <List<FormRef>>[]
        : _evolutionChain(species);
    return FormDetail(
      id: ref.id,
      name: ref.name,
      formName: ref.formName,
      pokeapiId: ref.pokeapiId,
      nationalNumber: ref.nationalNumber,
      spriteUrl: ref.spriteUrl,
      shinySpriteUrl: ref.shinySpriteUrl,
      types: [
        for (final (i, type) in form.types.indexed)
          FormType(slot: i + 1, type: type, spriteUrl: typeSprites[type]),
      ],
      abilities: pokemon?.abilities ?? const [],
      stats: pokemon?.stats ?? const [],
      genderRate: species?.genderRate,
      captureRate: species?.captureRate,
      hatchCounter: species?.hatchCounter,
      height: pokemon?.height,
      weight: pokemon?.weight,
      debutVersions: [
        for (final entry in _originMarks.keys)
          if (_groupOfVersion[entry] == form.versionGroup) entry,
      ],
      evolutionChain: chain,
      evolutionEdges: _chainEdges(chain),
      otherForms: [
        if (species != null)
          for (final other in _formsOfSpecies[species.name] ?? const <int>[])
            if (other != formId) formRef(other),
      ],
      pokedexes: pokedexesOf(formId),
    );
  }

  /// Versões dos jogos ligados ao HOME (os que têm pokédex no catálogo), por
  /// grupo, na ordem do catálogo. Não são só os que recebem do HOME
  /// ([transferVersions]): FireRed/LeafGreen do Switch só enviam (só ida),
  /// mas dá para caçar neles e mandar o shiny para o HOME.
  late final Map<String, List<String>> _homeVersions = () {
    final groups = {for (final dex in _pokedexes) ...dex.versionGroups};
    final result = <String, List<String>>{};
    for (final v in versions) {
      if (groups.contains(v.versionGroup)) {
        (result[v.versionGroup] ??= []).add(v.name);
      }
    }
    return result;
  }();

  /// Grupos das DLCs → os grupos dos jogos delas (pelas pokédex das DLCs).
  late final Map<String, List<String>> _gamesOfDlc = {
    for (final p in _pokedexes) ?p.dlc: p.versionGroups,
  };

  /// A forma pode estar no jogo [group]: não foi lançada depois dele (uma
  /// forma de DLC conta como do jogo da DLC). Não pega tudo (um Meowth de
  /// Galar passaria no BDSP), mas tira as regionais dos jogos anteriores.
  bool _existsBy(_Form form, String group) {
    final debut = form.versionGroup;
    if (_gamesOfDlc[debut]?.contains(group) ?? false) return true;
    return (_groupOrder[debut] ?? 0) <= (_groupOrder[group] ?? 0);
  }

  /// Os jogos do HOME em cuja pokédex a espécie da forma está, na ordem de
  /// lançamento, com cada pokédex e o número.
  List<GamePokedex> pokedexesOf(int formId) {
    final form = _forms[formId]!;
    final species = _pokemonOf(form)?.species;
    if (species == null) return const [];
    final entries = <String, List<PokedexEntry>>{};
    for (final dex in _pokedexes) {
      if (!dex.entries.containsKey(species)) continue;
      for (final group in dex.versionGroups) {
        if (!_existsBy(form, group) || !_formInGame(formId, species, group)) {
          continue;
        }
        (entries[group] ??= []).add(
          PokedexEntry(
            label: dex.label,
            labels: dex.labels,
            number: dex.entries[species],
            dlc: dex.dlc != null,
          ),
        );
      }
    }
    // Os jogos que só a aceitam pelo HOME, por ovo (#314): sem entrada.
    final byEgg = {
      for (final MapEntry(key: group, value: forms) in _homeEggs.entries)
        if (forms.contains(formId) && !entries.containsKey(group)) group,
    };
    final groups = [...entries.keys, ...byEgg]
      ..sort((a, b) => (_groupOrder[a] ?? 0).compareTo(_groupOrder[b] ?? 0));
    final exclusive = _exclusives[formId] ?? const <String>{};
    List<String> exclusiveTo(List<String> versions) {
      final only = [...versions.where(exclusive.contains)];
      return only.length < versions.length ? only : const [];
    }

    return [
      for (final group in groups)
        GamePokedex(
          versionGroup: group,
          versions: _homeVersions[group] ?? const [],
          entries: entries[group] ?? const [],
          viaHomeEgg: byEgg.contains(group),
          exclusiveTo: exclusiveTo(_homeVersions[group] ?? const []),
          shinyLockedIn: [
            for (final v in _homeVersions[group] ?? const <String>[])
              if (lockedVersions(formId).contains(v)) v,
          ],
        ),
    ];
  }

  /// O Pokémon pode ter vindo do jogo [version] (o do OT): a forma, ou uma
  /// pré-evolução dela (evoluiu depois, em outro jogo), está numa pokédex do
  /// jogo. Os exclusivos não contam (há eventos fora da versão), e jogos sem
  /// pokédex no catálogo (GO, os antigos) sempre servem.
  bool originFits(int formId, String? version) {
    final seen = <int>{};
    for (
      int? id = formId;
      id != null && seen.add(id);
      id = evolvesFromForm(id)
    ) {
      if (inGame(id, version)) return true;
    }
    return false;
  }

  /// A forma está numa pokédex do jogo [version] (pode estar num save
  /// dele); jogos sem pokédex no catálogo sempre servem.
  bool inGame(int formId, String? version) {
    final group = _groupOfVersion[version];
    if (group == null ||
        !_pokedexes.any((dex) => dex.versionGroups.contains(group))) {
      return true;
    }
    return pokedexesOf(formId).any((game) => game.versionGroup == group);
  }

  /// A forma pode ser caçada no jogo [version]: está numa pokédex dele e
  /// não é exclusiva da outra versão (o Koraidon só em Scarlet). Jogos sem
  /// pokédex no catálogo sempre servem.
  bool huntableIn(int formId, String? version) {
    if (!inGame(formId, version)) return false;
    final exclusive = _exclusives[formId] ?? const <String>{};
    final group = _groupOfVersion[version];
    final pair = [
      for (final v in versions)
        if (v.versionGroup == group) v.name,
    ];
    return !pair.any(exclusive.contains) || exclusive.contains(version);
  }

  late final Map<String, int> _versionIndex = {
    for (final (i, v) in versions.indexed) v.name: i,
  };

  /// Compara duas versões na ordem da série: geração, lançamento e a ordem
  /// do par (Sun antes de Moon). Versões fora do catálogo vão para o fim.
  int compareVersions(String a, String b) =>
      (_versionIndex[a] ?? versions.length).compareTo(
        _versionIndex[b] ?? versions.length,
      );

  /// O catálogo diz quais formas podem ser alfa (#280); um antigo, não.
  bool get hasAlphaForms => _alphaForms.isNotEmpty;

  /// Versões em que a forma pode aparecer como alfa (Legends: Arceus e
  /// Legends: Z-A), na ordem da série.
  List<String> alphaVersions(int formId) => [
    for (final v in versions)
      if (_alphaForms[v.versionGroup]?.contains(formId) ?? false) v.name,
  ];

  /// A forma pode ser alfa com a marca de origem [mark] (#362): a de um jogo
  /// em que ela aparece como alfa (Hisui ou Lumiose).
  bool canBeAlpha(int formId, String? mark) =>
      mark != null && alphaVersions(formId).any((v) => originMarkOf(v) == mark);

  /// Versões em que a forma não pode ser shiny (Solgaleo em Scarlet).
  Set<String> lockedVersions(int formId) =>
      _gameLocks[formId] ?? const <String>{};

  /// Versões (dos jogos ligados ao HOME) em que a forma pode ser caçada: a
  /// espécie está numa pokédex do jogo e a forma não é exclusiva da outra
  /// versão (o Koraidon só em Scarlet).
  List<String> huntableVersions(int formId) {
    final exclusive = _exclusives[formId] ?? const <String>{};
    return [
      for (final game in pokedexesOf(formId))
        for (final version in game.versions)
          if (!game.versions.any(exclusive.contains) ||
              exclusive.contains(version))
            version,
    ];
  }

  late final Map<String, String> _groupOfVersion = {
    for (final v in versions) v.name: v.versionGroup,
  };

  /// Formas de cada espécie, na ordem da dex nacional.
  late final Map<String, List<int>> _formsOfSpecies = () {
    final result = <String, List<int>>{};
    for (final form in _forms.values) {
      final name = _pokemonOf(form)?.species;
      if (name != null) (result[name] ??= []).add(form.id);
    }
    return result;
  }();

  /// Espécies que evoluem diretamente de cada espécie, na ordem nacional
  /// (no backend, a ordem da PokéAPI, que dá o mesmo resultado).
  late final Map<String, List<_Species>> _evolutions = () {
    final result = <String, List<_Species>>{};
    final ordered = _species.values.toList()
      ..sort(
        (a, b) => (a.nationalNumber ?? 0).compareTo(b.nationalNumber ?? 0),
      );
    for (final s in ordered) {
      final from = s.evolvesFrom;
      if (from != null) (result[from] ??= []).add(s);
    }
    return result;
  }();

  /// A forma que representa a espécie: a padrão do Pokémon padrão.
  int? _defaultFormOf(_Species species) {
    for (final id in _formsOfSpecies[species.name] ?? const <int>[]) {
      final form = _forms[id]!;
      if (form.isDefault && (_pokemonOf(form)?.isDefault ?? false)) return id;
    }
    return null;
  }

  /// Estágios da linha evolutiva, como no backend: a espécie base, as que
  /// evoluem dela e assim por diante; vazio se não evolui nem vem de outra.
  List<List<FormRef>> _evolutionChain(_Species species) {
    var root = species;
    final seen = {root.name};
    while (true) {
      final from = _species[root.evolvesFrom];
      if (from == null || !seen.add(from.name)) break;
      root = from;
    }
    final stages = [
      [root],
    ];
    while (true) {
      final next = [for (final s in stages.last) ...?_evolutions[s.name]];
      if (next.isEmpty) break;
      stages.add(next);
    }
    if (stages.length == 1) return const [];
    return [
      for (final stage in stages)
        [
          for (final s in stage)
            if (_defaultFormOf(s) case final id?) formRef(id),
        ],
    ];
  }

  /// Forma padrão da espécie da qual [formId] evolui (a regra do
  /// "evoluiu fora do HOME"); `null` se não evolui de nenhuma.
  int? evolvesFromForm(int formId) {
    // Nas famílias com forma regional, a forma certa (backend#121).
    if (_curated(formId)) return _formParent[formId];
    final species = _speciesOf(_forms[formId]!);
    final from = _species[species?.evolvesFrom];
    return from == null ? null : _defaultFormOf(from);
  }

  /// As formas de um dex novo com as chaves de [recipe] (#34), na ordem em
  /// que entram nas boxes: [dexSections] em sequência.
  List<int> dexForms(DexRecipe recipe) => [
    for (final section in dexSections(recipe)) ...section,
  ];

  /// As formas de um dex novo em seções: as gerações no Nacional, as
  /// pokédex no dex por jogo. Com "nova box" ligado, cada seção começa numa
  /// box.
  ///
  /// No Nacional, o conjunto padrão ([defaultDex]) com as chaves:
  /// - sem as regionais, saem as formas de Alola, Galar, Hisui e Paldea;
  /// - sem as pré-evoluções, ficam só as formas que não evoluem mais pelo
  ///   próprio caminho: nas famílias com forma regional, pelas arestas
  ///   curadas (o Farfetch'd comum fica, o de Galar sai); nas outras, pela
  ///   espécie (o Eevee sai, as eeveeluções ficam);
  /// - sem as formas alternativas, uma forma por espécie (a padrão; sem ela
  ///   no conjunto, a primeira, como o núcleo vermelho do Minior), além das
  ///   regionais.
  ///
  /// No dex por jogo, as espécies das pokédex escolhidas, na ordem delas (a
  /// que já entrou numa pokédex anterior não se repete), cada uma com as
  /// formas do conjunto padrão que existem no jogo; as duas outras chaves
  /// valem igual.
  List<List<int>> dexSections(DexRecipe recipe) {
    final group = recipe.versionGroup;
    if (group == null) return _nationalSections(recipe);
    final bySpecies = <String, List<int>>{};
    for (final id in defaultDex) {
      final form = _forms[id];
      final species = form == null ? null : _speciesOf(form)?.name;
      if (species == null) continue;
      if (!_existsBy(form!, group) || !_formInGame(id, species, group)) {
        continue;
      }
      (bySpecies[species] ??= []).add(id);
    }
    final seen = <String>{};
    return [
      for (final dex in _pokedexes)
        if (dex.versionGroups.contains(group) &&
            recipe.pokedexes.contains(dex.name))
          [
            for (final species in _orderedEntries(dex))
              if (seen.add(species))
                ..._withKeys(bySpecies[species] ?? const [], recipe),
          ],
    ]..removeWhere((section) => section.isEmpty);
  }

  List<List<int>> _nationalSections(DexRecipe recipe) {
    final picked = <int>[];
    final speciesSeen = <String>{};
    final withBase = {
      for (final id in defaultDex)
        if (_forms.containsKey(id) && _isBaseForm(id))
          _speciesOf(_forms[id]!)?.name,
    };
    for (final id in defaultDex) {
      final form = _forms[id];
      if (form == null) continue;
      final species = _speciesOf(form)?.name;
      final regional = _isRegional(form);
      if (regional && !recipe.regional) continue;
      if (!recipe.preEvolutions && _evolves(id)) continue;
      if (!recipe.alternateForms && !regional) {
        final first = _isBaseForm(id) || !withBase.contains(species);
        if (!first || !speciesSeen.add(species ?? '$id')) continue;
      }
      picked.add(id);
    }
    final sections = <List<int>>[];
    for (final id in picked) {
      if (sections.isEmpty ||
          generation(id) != generation(sections.last.last)) {
        sections.add([]);
      }
      sections.last.add(id);
    }
    return sections;
  }

  /// As formas de uma espécie no dex por jogo, com as chaves de
  /// pré-evoluções e formas alternativas. As regionais do jogo ficam
  /// sempre (não há a chave delas): sem as alternativas, a forma padrão (ou
  /// a primeira) e as regionais, como o Meowth comum e o de Galar no
  /// Sword/Shield.
  List<int> _withKeys(List<int> forms, DexRecipe recipe) {
    final kept = [
      for (final id in forms)
        if (recipe.preEvolutions || !_evolves(id)) id,
    ];
    if (recipe.alternateForms) return kept;
    final others = [
      for (final id in kept)
        if (!_isRegional(_forms[id]!)) id,
    ];
    final one = others.isEmpty
        ? null
        : others.firstWhere(_isBaseForm, orElse: () => others.first);
    return [
      for (final id in kept)
        if (id == one || _isRegional(_forms[id]!)) id,
    ];
  }

  /// As espécies de uma pokédex na ordem dela: pelo número; as sem número
  /// (as listas extras), na ordem do catálogo, depois.
  List<String> _orderedEntries(_Pokedex dex) {
    final names = dex.entries.keys.toList();
    final indexed = {for (final (i, name) in names.indexed) name: i};
    // Sem número, depois de todas as numeradas.
    int number(String species) => dex.entries[species] ?? 1 << 30;
    return names..sort(
      (a, b) => number(a) == number(b)
          ? indexed[a]!.compareTo(indexed[b]!)
          : number(a).compareTo(number(b)),
    );
  }

  /// Os jogos do HOME com pokédex no catálogo, na ordem de lançamento: os
  /// que dão para um dex por jogo (#34).
  List<String> get dexGames {
    final groups = {for (final dex in _pokedexes) ...dex.versionGroups}
        .where(_homeVersions.containsKey)
        .toList();
    return groups
      ..sort((a, b) => (_groupOrder[a] ?? 0).compareTo(_groupOrder[b] ?? 0));
  }

  /// As versões do jogo que recebem do HOME (`scarlet`, `violet`).
  List<String> gameVersions(String group) => _homeVersions[group] ?? const [];

  /// O grupo da versão (`scarlet` → `scarlet-violet`).
  String? groupOf(String version) => _groupOfVersion[version];

  /// Quantas espécies as pokédex do jogo têm juntas.
  int gameSpecies(String group) => {
    for (final dex in _pokedexes)
      if (dex.versionGroups.contains(group)) ...dex.entries.keys,
  }.length;

  /// As pokédex de um jogo, para escolher no dex por jogo, na ordem do
  /// catálogo (a principal, depois as das DLCs e as listas extras).
  List<GameDexChoice> gamePokedexes(String group) {
    final dexes = [
      for (final dex in _pokedexes)
        if (dex.versionGroups.contains(group)) dex,
    ];
    final picked = <_Pokedex>[];
    return [
      for (final dex in dexes)
        () {
          final extra = dex.entries.values.every((n) => n == null);
          final cover = dexes
              .where(
                (other) =>
                    other != dex &&
                    dexes.indexOf(other) < dexes.indexOf(dex) &&
                    dex.entries.keys.every(other.entries.containsKey),
              )
              .firstOrNull;
          final selected = !extra && cover == null;
          if (selected) picked.add(dex);
          return GameDexChoice(
            name: dex.name,
            label: dex.label,
            labels: dex.labels,
            species: dex.entries.length,
            dlc: dex.dlc,
            extra: extra,
            coveredBy: cover?.label,
            coveredByLabels: cover?.labels ?? const {},
            selectedByDefault: selected,
          );
        }(),
    ];
  }

  /// A forma padrão do Pokémon padrão da espécie.
  bool _isBaseForm(int formId) {
    final form = _forms[formId]!;
    return form.isDefault && (_pokemonOf(form)?.isDefault ?? false);
  }

  static final _regionalName = RegExp(r'(^|-)(alola|galar|hisui|paldea)(-|$)');

  /// Forma regional: o nome da forma diz a região (`alola`,
  /// `galar-standard`, `paldea-combat-breed`...).
  bool _isRegional(_Form form) => _regionalName.hasMatch(form.formName);

  /// A forma ainda evolui pelo próprio caminho: nas famílias com forma
  /// regional, pelas arestas curadas (backend#121); nas outras, pela
  /// espécie.
  bool _evolves(int formId) {
    if (_curated(formId)) return _formChildren.containsKey(formId);
    final species = _speciesOf(_forms[formId]!);
    return _evolutions[species?.name]?.isNotEmpty ?? false;
  }

  /// `gender_rate` da espécie da forma.
  int? genderRate(int formId) => _speciesOf(_forms[formId]!)?.genderRate;

  /// Geração da espécie da forma (`generation-i`...).
  String? generation(int formId) => _speciesOf(_forms[formId]!)?.generation;

  /// Geração em que a forma estreou, pelo grupo de versões dela (#343): o
  /// Raticate de Alola é da geração VII, embora o Raticate seja da I.
  /// `null` se a forma ou o grupo não estiverem no catálogo.
  String? formGeneration(int formId) =>
      _groupGenerations[_forms[formId]?.versionGroup];

  /// Categoria da espécie, como nos filtros do backend (a primeira que
  /// vale): lendário, mítico, Ultra Beast (habilidade Beast Boost), bebê ou
  /// comum.
  SpeciesCategory category(int formId) {
    final form = _forms[formId]!;
    final species = _speciesOf(form);
    final abilities = _pokemonOf(form)?.abilities ?? const <FormAbility>[];
    if (species?.isLegendary ?? false) return SpeciesCategory.legendary;
    if (species?.isMythical ?? false) return SpeciesCategory.mythical;
    if (abilities.any((a) => a.ability == 'beast-boost')) {
      return SpeciesCategory.ultraBeast;
    }
    if (species?.isBaby ?? false) return SpeciesCategory.baby;
    return SpeciesCategory.regular;
  }

  /// Marca de origem de um jogo (`null` se o jogo não tiver marca). O GO
  /// não tem grupo de versão no catálogo (#360): a marca dele vem daqui.
  String? originMarkOf(String? version) => version == goVersion
      ? OriginMark.go.slug
      : version == null
      ? null
      : _originMarks[version];
}

/// Lista de objetos JSON.
List<Map<String, dynamic>> _objects(Object? value) =>
    (value! as List).cast<Map<String, dynamic>>();

/// Uma pokédex de jogo do HOME: as espécies (pelo nome) e o número de cada
/// uma (`null` nas pokédex especiais).
class _Pokedex {
  const _Pokedex({
    required this.name,
    required this.label,
    required this.labels,
    required this.versionGroups,
    required this.dlc,
    required this.entries,
  });

  /// O identificador (`paldea`, `the-teal-mask`...): o que o dex por jogo
  /// guarda (#34).
  final String name;
  final String label;
  final Map<String, String> labels;
  final List<String> versionGroups;

  /// O grupo de versões da DLC (`null`: jogo base).
  final String? dlc;
  final Map<String, int?> entries;
}

/// Shiny lock padrão do catálogo; as formas pelo id.
class CatalogShinyLock {
  const CatalogShinyLock({
    required this.caption,
    required this.description,
    required this.lockType,
    required this.active,
    required this.forms,
  });

  final String caption;
  final String description;
  final ShinyLockType lockType;
  final bool active;
  final List<int> forms;
}

class _Form {
  const _Form({
    required this.id,
    required this.name,
    required this.formName,
    required this.pokemon,
    required this.isDefault,
    required this.versionGroup,
    required this.types,
    required this.sprite,
    required this.shinySprite,
    this.inBattleOnly = false,
  });

  final int id;
  final String name;
  final String formName;
  final int? pokemon;
  final bool isDefault;

  /// Mega ou forma só de batalha: não entra num time (#231).
  final bool inBattleOnly;
  final String versionGroup;
  final List<String> types;
  final String sprite;
  final String shinySprite;
}

class _Pokemon {
  const _Pokemon({
    required this.name,
    required this.species,
    required this.isDefault,
    required this.height,
    required this.weight,
    required this.abilities,
    required this.stats,
  });

  final String name;
  final String? species;
  final bool isDefault;
  final int height;
  final int weight;
  final List<FormAbility> abilities;
  final List<FormStat> stats;
}

class _Species {
  const _Species({
    required this.name,
    required this.nationalNumber,
    required this.generation,
    required this.genderRate,
    required this.captureRate,
    required this.hatchCounter,
    required this.isBaby,
    required this.isLegendary,
    required this.isMythical,
    required this.evolvesFrom,
  });

  final String name;
  final int? nationalNumber;
  final String generation;
  final int genderRate;
  final int captureRate;
  final int hatchCounter;
  final bool isBaby;
  final bool isLegendary;
  final bool isMythical;
  final String? evolvesFrom;
}

/// Um método de shiny hunt do catálogo (backend#103).
class ShinyMethod {
  const ShinyMethod({
    required this.id,
    required this.label,
    required this.units,
    required this.versions,
    this.labels = const {},
  });

  final String id;
  final String label;

  /// [label] em cada idioma da interface; vazio em catálogos antigos.
  final Map<String, String> labels;

  /// Unidades aceitas; a primeira é a padrão.
  final List<String> units;
  final Set<String> versions;
}

/// Um item que se segura em batalha (backend#138): o nome da PokéAPI, o
/// nome em inglês e o sprite (`null` quando a PokéAPI não tem o item).
class HeldItem {
  const HeldItem({required this.name, required this.label, this.spriteUrl});

  final String name;
  final String label;
  final String? spriteUrl;
}
