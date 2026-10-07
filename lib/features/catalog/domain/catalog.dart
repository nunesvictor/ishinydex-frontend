import 'package:ishinydex/features/personal_dex/domain/models.dart';
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
    required this.defaultDex,
    required this.options,
    required this.versions,
    required this.transferVersions,
    required this.shinyLocks,
    required this._forms,
    required this._pokemon,
    required this._species,
    required this._originMarks,
    required this._spriteBase,
    required this._groupOrder,
    required this._pokedexes,
    required this._exclusives,
  });

  /// Lê o JSON do pacote. Formato mais novo que [schemaVersion] →
  /// [FormatException] (o app precisa ser atualizado).
  factory Catalog.fromJson(
    Map<String, dynamic> json, {
    required String spriteBase,
  }) {
    final schema = json['schemaVersion'] as int;
    if (schema > schemaVersion) {
      throw FormatException(
        'Catálogo no formato $schema; este app lê até o $schemaVersion.',
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
    final versionList = [
      for (final v in _objects(json['versions']))
        (
          name: v['name'] as String,
          group: v['versionGroup'] as String,
          receives: v['receivesFromHome'] as bool,
        ),
    ];
    final groupOrder = {for (final g in groups) g.name: g.order};
    versionList.sort(
      (a, b) => (groupOrder[a.group] ?? 0).compareTo(groupOrder[b.group] ?? 0),
    );

    List<Choice> choices(String key) => [
      for (final c in _objects((json['choices'] as Map<String, dynamic>)[key]))
        Choice(
          value: c['value'] as String,
          label: c['label'] as String,
          spriteUrl: sprite(c['sprite']),
          increased: c['increased'] as String?,
          decreased: c['decreased'] as String?,
        ),
    ];

    return Catalog._(
      version: json['version'] as String,
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
          ),
      },
      pokemon: {
        for (final p in _objects(json['pokemon']))
          p['id'] as int: _Pokemon(
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
      // Catálogos antigos não têm as pokédex nem os exclusivos.
      pokedexes: [
        for (final p in _objects(json['pokedexes'] ?? const <Object>[]))
          _Pokedex(
            label: p['label'] as String,
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
    );
  }

  /// Maior `schemaVersion` que este app sabe ler.
  static const schemaVersion = 1;

  /// `catalog-AAAA.MM.DD`.
  final String version;

  /// Formas de um dex padrão novo, na ordem do esquema.
  final List<int> defaultDex;

  final SpecimenOptions options;

  /// Versões de jogo em ordem de lançamento.
  final List<GameVersion> versions;

  /// Jogos que recebem Pokémon do HOME (podem ser um save).
  final Set<String> transferVersions;

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

  /// As pokédex dos jogos que recebem do HOME (vazio em catálogo antigo).
  final List<_Pokedex> _pokedexes;

  /// Versões de que cada forma é exclusiva (pode ser de mais de um jogo).
  final Map<int, Set<String>> _exclusives;

  /// O catálogo diz em que pokédex cada espécie está (os saves compatíveis).
  bool get hasPokedexes => _pokedexes.isNotEmpty;

  /// Ids de todas as formas, na ordem da dex nacional.
  Iterable<int> get formIds => _forms.keys;

  bool hasForm(int formId) => _forms.containsKey(formId);

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
      evolutionChain: species == null ? const [] : _evolutionChain(species),
      otherForms: [
        if (species != null)
          for (final other in _formsOfSpecies[species.name] ?? const <int>[])
            if (other != formId) formRef(other),
      ],
      pokedexes: pokedexesOf(formId),
    );
  }

  /// Versões que recebem do HOME, por grupo, na ordem do catálogo.
  late final Map<String, List<String>> _homeVersions = () {
    final result = <String, List<String>>{};
    for (final v in versions) {
      if (transferVersions.contains(v.name)) {
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
        if (!_existsBy(form, group)) continue;
        (entries[group] ??= []).add(
          PokedexEntry(
            label: dex.label,
            number: dex.entries[species],
            dlc: dex.dlc != null,
          ),
        );
      }
    }
    final groups = entries.keys.toList()
      ..sort((a, b) => (_groupOrder[a] ?? 0).compareTo(_groupOrder[b] ?? 0));
    return [
      for (final group in groups)
        GamePokedex(
          versionGroup: group,
          versions: _homeVersions[group] ?? const [],
          entries: entries[group]!,
        ),
    ];
  }

  /// O Pokémon pode ter vindo do jogo [version] (o do OT): a forma, ou uma
  /// pré-evolução dela (evoluiu depois, em outro jogo), está numa pokédex do
  /// jogo. Os exclusivos não contam (há eventos fora da versão), e jogos sem
  /// pokédex no catálogo (GO, Let's Go, os antigos) sempre servem.
  bool originFits(int formId, String? version) {
    final group = _groupOfVersion[version];
    if (group == null ||
        !_pokedexes.any((dex) => dex.versionGroups.contains(group))) {
      return true;
    }
    final seen = <int>{};
    for (
      int? id = formId;
      id != null && seen.add(id);
      id = evolvesFromForm(id)
    ) {
      if (pokedexesOf(id).any((game) => game.versionGroup == group)) {
        return true;
      }
    }
    return false;
  }

  /// Versões (das que recebem do HOME) em que a forma pode ser caçada: a
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
    final species = _speciesOf(_forms[formId]!);
    final from = _species[species?.evolvesFrom];
    return from == null ? null : _defaultFormOf(from);
  }

  /// `gender_rate` da espécie da forma.
  int? genderRate(int formId) => _speciesOf(_forms[formId]!)?.genderRate;

  /// Geração da espécie da forma (`generation-i`...).
  String? generation(int formId) => _speciesOf(_forms[formId]!)?.generation;

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

  /// Marca de origem de um jogo (`null` se o jogo não tiver marca).
  String? originMarkOf(String? version) =>
      version == null ? null : _originMarks[version];
}

/// Lista de objetos JSON.
List<Map<String, dynamic>> _objects(Object? value) =>
    (value! as List).cast<Map<String, dynamic>>();

/// Uma pokédex de jogo do HOME: as espécies (pelo nome) e o número de cada
/// uma (`null` nas pokédex especiais).
class _Pokedex {
  const _Pokedex({
    required this.label,
    required this.versionGroups,
    required this.dlc,
    required this.entries,
  });

  final String label;
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
  });

  final int id;
  final String name;
  final String formName;
  final int? pokemon;
  final bool isDefault;
  final String versionGroup;
  final List<String> types;
  final String sprite;
  final String shinySprite;
}

class _Pokemon {
  const _Pokemon({
    required this.species,
    required this.isDefault,
    required this.height,
    required this.weight,
    required this.abilities,
    required this.stats,
  });

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
