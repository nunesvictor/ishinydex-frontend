import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/network/paginated.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/domain/personal_dex_repository.dart';
import 'package:ishinydex/features/shiny_hunts/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/domain/shiny_hunt_repository.dart';
import 'package:ishinydex/features/shiny_locks/domain/models.dart';
import 'package:ishinydex/features/shiny_locks/domain/shiny_lock_repository.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/domain/specimen_repository.dart';
import 'package:ishinydex/features/specimens/domain/transfer_rules.dart';

final fakeBackendProvider = Provider<FakeBackend>(
  (ref) => FakeBackend.seeded(latency: const Duration(milliseconds: 250)),
);

const _spriteBase =
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites';

/// Ícones pequenos de tipo, como em `/specimens/options/`.
const _typeBase = '$_spriteBase/types/generation-viii/sword-shield/small';

/// `gender_rate` das espécies da demonstração (as demais: 4, macho ou
/// fêmea). Nidoran♀ só fêmea; Nidoran♂ só macho.
const _seedNatures = ['adamant', 'modest', 'timid'];

/// Gênero de demonstração: o único permitido, ou alternado pela forma.
String _seedGender(FormDetail form, Map<int, int> genderRates) {
  final allowed = allowedGenders(form, genderRates);
  if (allowed.length == 1) return allowed.single;
  return form.id.isEven ? 'female' : 'male';
}

const _seedGenderRates = {29: 8, 30: 8, 31: 8, 32: 0, 33: 0, 34: 0};

/// Tipos das formas da demonstração (as demais são "normal").
const _seedTypes = {
  4: ['fire'],
  5: ['fire'],
  6: ['fire', 'flying'],
  7: ['water'],
  8: ['water'],
  9: ['water'],
  16: ['normal', 'flying'],
  17: ['normal', 'flying'],
  18: ['normal', 'flying'],
  21: ['normal', 'flying'],
  22: ['normal', 'flying'],
};

const _speciesNames = [
  'bulbasaur', 'ivysaur', 'venusaur', 'charmander', 'charmeleon', //
  'charizard', 'squirtle', 'wartortle', 'blastoise', 'caterpie',
  'metapod', 'butterfree', 'weedle', 'kakuna', 'beedrill',
  'pidgey', 'pidgeotto', 'pidgeot', 'rattata', 'raticate',
  'spearow', 'fearow', 'ekans', 'arbok', 'pikachu',
  'raichu', 'sandshrew', 'sandslash', 'nidoran-f', 'nidorina',
  'nidoqueen', 'nidoran-m', 'nidorino', 'nidoking', 'clefairy',
  'clefable', 'vulpix', 'ninetales', 'jigglypuff', 'wigglytuff',
  'zubat', 'golbat', 'oddish', 'gloom', 'vileplume',
  'paras', 'parasect', 'venonat', 'venomoth', 'diglett',
  'dugtrio', 'meowth', 'persian', 'psyduck', 'golduck',
  'mankey', 'primeape', 'growlithe',
];

/// Como o `slugify` do Django, que a API aplica à busca em nomes de forma e
/// habilidade (slugs da PokéAPI): "Iron Hands" → "iron-hands", "Mr. Mime" →
/// "mr-mime", "Flabébé" → "flabebe". Se não sobrar nada, o texto como veio.
String slugSearch(String text) {
  var slug = text.toLowerCase();
  for (final MapEntry(key: plain, value: accented) in _accents.entries) {
    slug = slug.replaceAll(RegExp('[$accented]'), plain);
  }
  slug = slug
      .replaceAll(RegExp(r'[^\w\s-]'), '')
      .replaceAll(RegExp(r'[-\s]+'), '-')
      .replaceAll(RegExp(r'^[-_]+|[-_]+$'), '');
  return slug.isEmpty ? text : slug;
}

/// Letra sem acento → variantes acentuadas (o `slugify` decompõe e descarta
/// o acento; o resto do que não é ASCII some).
const _accents = {
  'a': 'àáâãäå',
  'c': 'ç',
  'e': 'èéêë',
  'i': 'ìíîï',
  'n': 'ñ',
  'o': 'òóôõö',
  'u': 'ùúûü',
  'y': 'ýÿ',
};

/// Cadeias de evolução do seed: forma → forma da qual evolui.
const _seedEvolvesFrom = {
  2: 1, 3: 2, 5: 4, 6: 5, 8: 7, 9: 8, 11: 10, 12: 11, 14: 13, 15: 14, //
  17: 16, 18: 17, 20: 19, 22: 21, 24: 23, 26: 25, 28: 27, 30: 29, 31: 30,
  33: 32, 34: 33, 36: 35, 38: 37, 40: 39, 42: 41, 44: 43, 45: 44, 47: 46,
  49: 48, 51: 50, 53: 52, 55: 54, 57: 56,
};

class _SlotRecord {
  _SlotRecord({
    required this.id,
    required this.box,
    required this.row,
    required this.col,
    this.dexId,
    this.formId,
  });

  final int id;
  final BoxRef box;
  final int row;
  final int col;

  /// `null` nos slots livres, como no backend (`personal_dex = NULL`).
  /// Mutáveis: criar um dex instala o esquema em slots livres.
  int? dexId;
  int? formId;
  int? specimenId;
}

/// Um slot do dex na busca do Faltam: a caçada, se passa nos filtros, e se
/// ainda falta (#282).
typedef _HuntRow = ({_SlotRecord slot, bool missing, Hunt? hunt});

/// As formas de um dex novo e onde começa cada seção (ver o `_layoutFor` do
/// `FakeBackend`).
typedef DexLayout = ({List<FormDetail> forms, Set<int> starts});

/// O que o padrão de hoje mudou num dex (#308): a receita dele, o esquema
/// que ela dá, as formas que o dex tem (na ordem das boxes) e as que
/// entram e saem.
typedef DexChange = ({
  DexRecipe recipe,
  DexLayout target,
  List<int> current,
  List<int> added,
  List<int> removed,
});

/// O backend do app, em memória: as regras de negócio (dexes, boxes,
/// depósito, caçadas...) que antes ficavam no servidor. No modo local, os
/// dados vêm do aparelho e voltam para ele ([records]); na demonstração, são
/// de exemplo. O nome ficou do tempo em que imitava a API do servidor.
class FakeBackend
    implements
        PersonalDexRepository,
        SpecimenRepository,
        ShinyLockRepository,
        ShinyHuntRepository {
  FakeBackend({
    this.latency = Duration.zero,
    this.catalog,
    this.randomIds = false,
  });

  /// Dados de demonstração: um dex shiny (2 boxes) e um dex normal (1 box).
  factory FakeBackend.seeded({Duration latency = Duration.zero}) {
    final backend = FakeBackend(latency: latency);
    for (final (index, name) in _speciesNames.indexed) {
      backend.addForm(
        id: index + 1,
        name: name,
        types: _seedTypes[index + 1] ?? const ['normal'],
        genderRate: _seedGenderRates[index + 1] ?? 4,
        evolvesFrom: _seedEvolvesFrom[index + 1],
      );
    }
    backend
      .._seedUserData([for (var id = 1; id <= _speciesNames.length; id++) id])
      // Um shiny lock de exemplo (só por distribuição), para a tela de
      // cadastro e o aviso nas caçadas.
      ..addShinyLock(
        caption: 'Pikachu de evento',
        lockType: ShinyLockType.distroOnly,
        formIds: const [25],
      );
    return backend;
  }

  /// Demonstração com o catálogo real (`CATALOG_URL`): formas, opções,
  /// versões e shiny locks do pacote; dados do usuário fictícios, com um
  /// shiny dex do dex padrão inteiro.
  factory FakeBackend.fromCatalog(
    Catalog catalog, {
    Duration latency = Duration.zero,
  }) {
    final backend = FakeBackend(latency: latency, catalog: catalog);
    for (final id in catalog.formIds) {
      backend._forms[id] = catalog.formDetail(id);
      backend._genderRates[id] = catalog.genderRate(id) ?? 4;
      backend._categories[id] = catalog.category(id);
      if (catalog.evolvesFromForm(id) case final from?) {
        backend._evolvesFrom[id] = from;
      }
    }
    for (final lock in catalog.shinyLocks) {
      backend.addShinyLock(
        caption: lock.caption,
        description: lock.description,
        lockType: lock.lockType,
        active: lock.active,
        formIds: lock.forms.where(catalog.hasForm).toList(),
      );
    }
    return backend.._seedUserData(catalog.defaultDex);
  }

  /// Backend local (modo local) com o [catalog]: formas, opções e shiny
  /// locks padrão do pacote e os dados do usuário de [records] (vazios num
  /// aparelho novo), com ids aleatórios.
  factory FakeBackend.local(
    Catalog catalog, {
    Map<String, List<Map<String, dynamic>>> records = const {},
  }) {
    final backend = FakeBackend(catalog: catalog, randomIds: true);
    for (final id in catalog.formIds) {
      backend._forms[id] = catalog.formDetail(id);
      backend._genderRates[id] = catalog.genderRate(id) ?? 4;
      backend._categories[id] = catalog.category(id);
      if (catalog.evolvesFromForm(id) case final from?) {
        backend._evolvesFrom[id] = from;
      }
    }
    if (records.isEmpty) {
      // Aparelho novo: os shiny locks padrão do catálogo.
      for (final lock in catalog.shinyLocks) {
        backend.addShinyLock(
          caption: lock.caption,
          description: lock.description,
          lockType: lock.lockType,
          active: lock.active,
          formIds: lock.forms.where(catalog.hasForm).toList(),
        );
      }
    } else {
      backend._restore(records);
    }
    return backend;
  }

  /// Treinadores, saves, um shiny dex com todas as [forms] (30 por box), um
  /// living dex com as 30 primeiras, espécimes e três boxes livres.
  void _seedUserData(List<int> forms) {
    addTrainer(name: 'Ash', trainerId: '123456', version: 'scarlet');
    addTrainer(name: 'Ash', trainerId: '654321');
    // Outras origens, para a demonstração mostrar várias marcas.
    addTrainer(name: 'Rei', trainerId: '111111', version: 'legends-arceus');
    addTrainer(name: 'Ash', trainerId: '222222', version: 'legends-za');
    final shinyDex = addDex(name: 'Shiny Living Dex', isShinyDex: true);
    final livingDex = addDex(name: 'Living Dex');
    var box = 0;
    for (var i = 0; i < forms.length; i += 30) {
      addBox(
        dexId: shinyDex,
        name: 'HOME ${++box}',
        formIds: forms.sublist(i, (i + 30).clamp(0, forms.length)),
      );
    }
    addBox(
      dexId: livingDex,
      name: 'HOME ${++box}',
      formIds: forms.sublist(0, 30.clamp(0, forms.length)),
    );
    for (final slot in _slots.values) {
      final formId = slot.formId;
      if (formId == null) continue;
      final shiny = slot.dexId == shinyDex;
      if (formId % 3 == 0) {
        // Faltante: deixa um specimen disponível em alguns casos.
        if (shiny && formId.isEven) {
          addSpecimen(formId: formId, isShiny: true);
        }
        continue;
      }
      final specimen = addSpecimen(
        formId: formId,
        isShiny: shiny,
        isAlpha: formId % 5 == 1,
        isFromGo: formId % 7 == 0,
        gender: _seedGender(_forms[formId]!, _genderRates),
        // Alguns sem natureza, como cadastros antigos.
        nature: formId % 4 == 0 ? null : _seedNatures[formId % 3],
        pokeball: formId.isEven ? 'dream-ball' : 'poke-ball',
        ot: switch (formId % 4) {
          0 => 1,
          2 when formId % 3 == 1 => 3,
          2 when formId % 3 == 2 => 4,
          _ => null,
        },
        capturedAt: formId.isEven ? DateTime(2026, 1, formId) : null,
      );
      slot.specimenId = specimen;
    }
    addSpecimen(formId: forms[2], nickname: 'Saur');
    // Saves: o Scarlet (com um Pokémon do Living Dex fora do HOME) e o Z-A.
    final scarlet = addSave(trainerId: 1, label: 'Switch');
    addSave(trainerId: 4);
    final away = _slots.values.firstWhere(
      (s) => s.dexId == livingDex && s.formId == forms[1],
    );
    moveTo(away.specimenId!, scarlet, since: DateTime(2026, 3, 12));
    // Boxes livres: dá para criar um dex novo na demonstração.
    for (var i = 1; i <= 3; i++) {
      addFreeBox('HOME ${box + i}');
    }
  }

  /// O relógio da data de corte do HOME (#222); nos testes, fixo.
  DateTime Function() now = DateTime.now;

  /// O jogo do [save] já não chega ao HOME (o corte do catálogo passou).
  bool _cutOff(Save save) =>
      switch (catalog?.homeCutoffs[save.trainer.version]) {
        final until? => !now().isBefore(until),
        null => false,
      };

  /// Tipos de registro do arquivo de dados, na ordem em que se restauram
  /// (cada um só referencia os anteriores).
  static const recordTypes = [
    'trainers',
    'saves',
    'shinyHunts',
    'dexes',
    'boxes',
    'shinyLocks',
    'specimens',
    'slots',
  ];

  /// Registros que citam formas fora do catálogo atual: não entram no app,
  /// mas voltam no próximo [records], para nada se perder.
  final _orphans = <String, List<Map<String, dynamic>>>{};

  static String? _date(DateTime? value) =>
      value?.toIso8601String().substring(0, 10);

  /// Os dados do usuário em registros canônicos: só ids e valores, nada
  /// derivado (sprites, contagens, marca de origem). É o conteúdo do
  /// arquivo de dados (modo local, exportar/importar e sync).
  Map<String, List<Map<String, dynamic>>> get records => {
    'trainers': [
      for (final t in _trainers.values)
        {
          'id': t.id,
          'name': t.name,
          'trainerId': t.trainerId,
          'version': t.version,
        },
    ],
    'saves': [
      for (final s in _saves.values)
        {
          'id': s.id,
          'trainer': s.trainer.id,
          'label': s.label,
          // Só quando tem: o registro de quem não tem fica como antes.
          if (s.hasShinyCharm) 'shinyCharm': true,
        },
    ],
    'dexes': [
      for (final d in _dexes.values)
        {
          'id': d.id,
          'name': d.name,
          'isShinyDex': d.isShinyDex,
          'forceNewBox': d.forceNewBox,
          // Só nos dex do #34: os de antes continuam como eram.
          if (d.recipe case final recipe?) 'recipe': recipe.toJson(),
          // A decisão sobre a mudança do padrão (#308).
          'updateLater': ?d.updateLater,
          'updateIgnored': ?d.updateIgnored,
        },
    ],
    'boxes': [
      for (final b in _boxes.values)
        {'id': b.id, 'name': b.name, 'position': b.position},
    ],
    'shinyHunts': [
      for (final h in _hunts.values)
        {
          'id': h.id,
          'form': h.form,
          'paused': h.paused,
          'save': h.save,
          'method': h.method,
          'unit': h.unit,
          'count': h.count,
          'accumulatedSeconds': h.accumulatedSeconds,
          'runningSince': h.runningSince?.toUtc().toIso8601String(),
          'startedAt': _date(h.startedAt),
          'pausedAt': _date(h.pausedAt),
          // Odds (#221): só quando há, para o registro antigo ficar igual.
          if (h.modifiers.isNotEmpty) 'modifiers': h.modifiers,
          if (h.chain > 0) 'chain': h.chain,
          if (h.bestChain > 0) 'bestChain': h.bestChain,
          'miss': ?h.miss,
          if (h.estimated) 'estimated': true,
        },
      ...?_orphans['shinyHunts'],
    ],
    'shinyLocks': [
      for (final l in _shinyLocks.values)
        {
          'id': l.id,
          'caption': l.caption,
          'description': l.description,
          'lockType': l.lockType.param,
          'active': l.active,
          'forms': [for (final f in l.forms) f.id],
        },
      ...?_orphans['shinyLocks'],
    ],
    'specimens': [
      for (final s in _specimens.values)
        {
          'id': s.id,
          'form': s.form,
          'nickname': s.nickname,
          'ability': s.ability,
          'language': s.language,
          'gender': s.gender,
          'nature': s.nature,
          'isAlpha': s.isAlpha,
          'isShiny': s.isShiny,
          'isFromGo': s.isFromGo,
          'capturedAt': _date(s.capturedAt),
          'pokeball': s.pokeball,
          'observation': s.observation,
          'ot': s.ot,
          'location': s.location?.id,
          'locationSince': _date(s.locationSince),
          'championsSince': _date(s.championsSince),
          if (s.hunt case final h?)
            'hunt': {
              'method': h.method,
              'count': h.count,
              'unit': h.unit,
              'startedAt': _date(h.startedAt),
              'postUrl': h.postUrl,
              'odds': ?h.odds,
              'multiple': ?h.multiple,
              'bestChain': ?h.bestChain,
            },
        },
      ...?_orphans['specimens'],
    ],
    'slots': [
      for (final s in _slots.values)
        {
          'id': s.id,
          'box': s.box.id,
          'row': s.row,
          'col': s.col,
          'dex': s.dexId,
          'form': s.formId,
          'specimen': s.specimenId,
        },
      ...?_orphans['slots'],
    ],
  };

  /// Troca todos os dados do usuário pelos de [records] (importar, sync),
  /// mantendo o catálogo e esta mesma instância (os providers continuam
  /// apontando para ela).
  void replaceRecords(Map<String, List<Map<String, dynamic>>> records) {
    for (final map in [
      _trainers,
      _saves,
      _dexes,
      _boxes,
      _slots,
      _specimens,
      _shinyLocks,
      _hunts,
      _orphans,
    ]) {
      map.clear();
    }
    _restore(records);
  }

  void _restore(Map<String, List<Map<String, dynamic>>> records) {
    List<Map<String, dynamic>> of(String type) => records[type] ?? const [];
    DateTime? date(Object? value) =>
        value == null ? null : DateTime.parse(value as String);
    for (final t in of('trainers')) {
      final id = t['id'] as int;
      _trainers[id] = Trainer(
        id: id,
        name: t['name'] as String,
        trainerId: t['trainerId'] as String,
        version: t['version'] as String?,
      );
    }
    for (final s in of('saves')) {
      final id = s['id'] as int;
      _saves[id] = Save(
        id: id,
        trainer: _trainers[s['trainer'] as int]!,
        label: s['label'] as String,
        hasShinyCharm: s['shinyCharm'] as bool? ?? false,
      );
    }
    for (final d in of('dexes')) {
      final id = d['id'] as int;
      _dexes[id] = PersonalDex(
        id: id,
        name: d['name'] as String,
        total: 0,
        registered: 0,
        isShinyDex: d['isShinyDex'] as bool,
        forceNewBox: d['forceNewBox'] as bool,
        recipe: switch (d['recipe']) {
          final Map<String, dynamic> recipe => DexRecipe.fromJson(recipe),
          _ => null,
        },
        updateLater: d['updateLater'] as String?,
        updateIgnored: d['updateIgnored'] as String?,
      );
    }
    for (final b in of('boxes')) {
      final id = b['id'] as int;
      _boxes[id] = BoxRef(
        id: id,
        name: b['name'] as String,
        position: b['position'] as int,
      );
    }
    for (final l in of('shinyLocks')) {
      final forms = [for (final f in l['forms'] as List) f as int];
      if (!forms.every(_forms.containsKey)) {
        (_orphans['shinyLocks'] ??= []).add(l);
        continue;
      }
      final id = l['id'] as int;
      _shinyLocks[id] = ShinyLock(
        id: id,
        caption: l['caption'] as String,
        description: l['description'] as String?,
        lockType:
            ShinyLockType.fromParam(l['lockType'] as String) ??
            ShinyLockType.unobtainable,
        active: l['active'] as bool,
        forms: _lockForms(forms),
      );
    }
    for (final h in of('shinyHunts')) {
      final form = _forms[h['form'] as int];
      if (form == null) {
        (_orphans['shinyHunts'] ??= []).add(h);
        continue;
      }
      final id = h['id'] as int;
      _hunts[id] = ShinyHunt(
        id: id,
        form: form.id,
        formRef: _formRef(form),
        paused: h['paused'] as bool,
        save: _saves.containsKey(h['save']) ? h['save'] as int : null,
        method: h['method'] as String?,
        unit: h['unit'] as String,
        count: h['count'] as int,
        accumulatedSeconds: h['accumulatedSeconds'] as int,
        runningSince: switch (h['runningSince']) {
          final String t => DateTime.parse(t).toLocal(),
          _ => null,
        },
        startedAt: date(h['startedAt']),
        pausedAt: date(h['pausedAt']),
        modifiers: {
          for (final MapEntry(:key, :value)
              in ((h['modifiers'] as Map<String, dynamic>?) ?? const {})
                  .entries)
            key: value as int,
        },
        chain: h['chain'] as int? ?? 0,
        bestChain: h['bestChain'] as int? ?? 0,
        miss: (h['miss'] as num?)?.toDouble(),
        estimated: h['estimated'] as bool? ?? false,
      );
    }
    for (final s in of('specimens')) {
      final form = _forms[s['form'] as int];
      if (form == null) {
        (_orphans['specimens'] ??= []).add(s);
        continue;
      }
      final id = s['id'] as int;
      final ot = s['ot'] as int?;
      final pokeball = s['pokeball'] as String?;
      _specimens[id] = Specimen(
        id: id,
        form: form.id,
        formRef: _formRef(form),
        formName: form.name,
        nickname: s['nickname'] as String?,
        ability: s['ability'] as String?,
        language: s['language'] as String?,
        gender: s['gender'] as String?,
        nature: s['nature'] as String?,
        isAlpha: s['isAlpha'] as bool,
        isShiny: s['isShiny'] as bool,
        isFromGo: s['isFromGo'] as bool,
        capturedAt: date(s['capturedAt']),
        pokeball: pokeball,
        pokeballSpriteUrl: _ballSprite(pokeball),
        observation: s['observation'] as String?,
        ot: ot,
        location: _saves[s['location']],
        locationSince: date(s['locationSince']),
        championsSince: date(s['championsSince']),
        hunt: switch (s['hunt']) {
          final Map<String, dynamic> h => HuntRecord(
            method: h['method'] as String?,
            count: h['count'] as int?,
            unit: h['unit'] as String?,
            startedAt: date(h['startedAt']),
            postUrl: h['postUrl'] as String?,
            odds: (h['odds'] as num?)?.toDouble(),
            multiple: (h['multiple'] as num?)?.toDouble(),
            bestChain: h['bestChain'] as int?,
          ),
          _ => null,
        },
      ).withOrigin(_originMarkOf, _otVersion(ot));
    }
    for (final s in of('slots')) {
      final form = s['form'] as int?;
      if (form != null && !_forms.containsKey(form)) {
        (_orphans['slots'] ??= []).add(s);
        continue;
      }
      final id = s['id'] as int;
      final specimen = s['specimen'] as int?;
      _slots[id] = _SlotRecord(
        id: id,
        box: _boxes[s['box'] as int]!,
        row: s['row'] as int,
        col: s['col'] as int,
        dexId: s['dex'] as int?,
        formId: form,
      )..specimenId = _specimens.containsKey(specimen) ? specimen : null;
    }
  }

  final Duration latency;

  /// Catálogo real (modo demonstração com `CATALOG_URL`); `null` no seed
  /// fixo dos testes.
  final Catalog? catalog;

  /// Ids aleatórios de 53 bits (cabem num `int` do JavaScript), para
  /// aparelhos sem rede não gerarem o mesmo id (modo local). Sem isso, o
  /// próximo id é o maior + 1, como no banco.
  final bool randomIds;

  /// Chamado a cada uso do backend (leitura ou escrita), antes da operação:
  /// o modo local agenda a gravação a partir daqui.
  void Function()? onAccess;

  final _random = Random();

  // Constantes, e não `1 << 32`: no navegador, os operadores de bits do
  // JavaScript trabalham com 32 bits, e `1 << 32` dá 0.
  static const _twoTo32 = 4294967296;
  static const _twoTo21 = 2097152;

  int _newId(Iterable<int> used) {
    if (!randomIds) return used.fold(0, max) + 1;
    final taken = used.toSet();
    while (true) {
      final id =
          _random.nextInt(_twoTo32) * _twoTo21 + _random.nextInt(_twoTo21);
      if (id > 0 && !taken.contains(id)) return id;
    }
  }

  final _forms = <int, FormDetail>{};
  final _dexes = <int, PersonalDex>{};
  final _boxes = <int, BoxRef>{};
  final _slots = <int, _SlotRecord>{};
  final _specimens = <int, Specimen>{};
  final _hunts = <int, ShinyHunt>{};
  final _trainers = <int, Trainer>{};
  final _saves = <int, Save>{};

  /// Shiny locks cadastrados. Como na API, são eles que dão o
  /// `isShinylocked`/`isDistroOnly` das formas e o `shiny_lock` das caçadas.
  final _shinyLocks = <int, ShinyLock>{};

  /// Forma → forma da qual evolui (no backend, `evolves_from_species`).
  final _evolvesFrom = <int, int>{};

  /// `gender_rate` da espécie de cada forma (a API não expõe; a regra do
  /// lote usa).
  final _genderRates = <int, int>{};

  /// Categoria da espécie de cada forma (no backend, vem dos campos da
  /// espécie e da habilidade Beast Boost).
  final _categories = <int, SpeciesCategory>{};

  /// Grupo de versão de cada versão (a marca de origem depende dele).
  static final Map<String, String> versionGroups = {
    for (final v in gameVersions) v.name: v.versionGroup,
  };

  List<GameVersion> get versions => catalog?.versions ?? gameVersions;

  static const gameVersions = [
    GameVersion(
      name: 'red',
      versionGroup: 'red-blue',
      generation: 'generation-i',
    ),
    GameVersion(
      name: 'gold',
      versionGroup: 'gold-silver',
      generation: 'generation-ii',
    ),
    GameVersion(
      name: 'emerald',
      versionGroup: 'emerald',
      generation: 'generation-iii',
    ),
    GameVersion(
      name: 'sun',
      versionGroup: 'sun-moon',
      generation: 'generation-vii',
    ),
    GameVersion(
      name: 'lets-go-pikachu',
      versionGroup: 'lets-go-pikachu-lets-go-eevee',
      generation: 'generation-vii',
    ),
    GameVersion(
      name: 'sword',
      versionGroup: 'sword-shield',
      generation: 'generation-viii',
    ),
    GameVersion(
      name: 'legends-arceus',
      versionGroup: 'legends-arceus',
      generation: 'generation-viii',
    ),
    GameVersion(
      name: 'scarlet',
      versionGroup: 'scarlet-violet',
      generation: 'generation-ix',
    ),
    GameVersion(
      name: 'violet',
      versionGroup: 'scarlet-violet',
      generation: 'generation-ix',
    ),
    GameVersion(
      name: 'legends-za',
      versionGroup: 'legends-za',
      generation: 'generation-ix',
    ),
  ];

  SpecimenOptions get options => catalog?.options ?? _seedOptions;

  static const _seedOptions = SpecimenOptions(
    language: [
      Choice(value: 'pt-br', label: 'Português brasileiro'),
      Choice(value: 'en', label: 'Inglês'),
      Choice(value: 'ja', label: 'Japonês'),
    ],
    gender: [
      Choice(value: 'male', label: 'Macho'),
      Choice(value: 'female', label: 'Fêmea'),
      Choice(value: 'genderless', label: 'Sem gênero'),
    ],
    nature: [
      Choice(
        value: 'adamant',
        label: 'Adamant',
        increased: 'attack',
        decreased: 'special-attack',
      ),
      Choice(
        value: 'modest',
        label: 'Modest',
        increased: 'special-attack',
        decreased: 'attack',
      ),
      Choice(
        value: 'timid',
        label: 'Timid',
        increased: 'speed',
        decreased: 'attack',
      ),
      Choice(value: 'hardy', label: 'Hardy'),
    ],
    type: [
      Choice(value: 'normal', label: 'Normal', spriteUrl: '$_typeBase/1.png'),
      Choice(value: 'fire', label: 'Fogo', spriteUrl: '$_typeBase/10.png'),
      Choice(value: 'water', label: 'Água', spriteUrl: '$_typeBase/11.png'),
      Choice(value: 'flying', label: 'Voador', spriteUrl: '$_typeBase/3.png'),
    ],
    generation: [
      Choice(value: 'generation-i', label: 'Geração I'),
      Choice(value: 'generation-ii', label: 'Geração II'),
    ],
    // Mesma ordem do backend: marcas, GO e "sem marca".
    originMark: [
      Choice(value: 'game-boy', label: 'GB'),
      Choice(value: 'gba', label: 'GBA'),
      Choice(value: 'alola', label: 'SM/USUM'),
      Choice(value: 'lets-go', label: 'LGPE'),
      Choice(value: 'galar', label: 'SwSh'),
      Choice(value: 'hisui', label: 'PLA'),
      Choice(value: 'paldea', label: 'SV'),
      Choice(value: 'lumiose', label: 'PLZA'),
      Choice(value: 'go', label: 'GO'),
      Choice(value: 'none', label: 'Sem marca de origem'),
    ],
    pokeball: [
      Choice(
        value: 'poke-ball',
        label: 'Poké Ball',
        spriteUrl: '$_spriteBase/items/poke-ball.png',
      ),
      Choice(
        value: 'dream-ball',
        label: 'Dream Ball',
        spriteUrl: '$_spriteBase/items/dream-ball.png',
      ),
      Choice(
        value: 'beast-ball',
        label: 'Beast Ball',
        spriteUrl: '$_spriteBase/items/beast-ball.png',
      ),
    ],
  );

  // ---- Seed helpers ----

  /// Cadastra um shiny lock; retorna o id.
  int addShinyLock({
    required String caption,
    required List<int> formIds,
    ShinyLockType lockType = ShinyLockType.unobtainable,
    String? description,
    bool active = true,
  }) {
    final id = _newId(_shinyLocks.keys);
    _shinyLocks[id] = ShinyLock(
      id: id,
      caption: caption,
      description: description,
      lockType: lockType,
      active: active,
      forms: _lockForms(formIds),
    );
    return id;
  }

  /// Formas do lock como a API devolve: na ordem da dex nacional.
  List<FormRef> _lockForms(Iterable<int> formIds) =>
      [for (final id in formIds) _formRef(_forms[id]!)]..sort(
        (a, b) => (a.nationalNumber ?? a.pokeapiId).compareTo(
          b.nationalNumber ?? b.pokeapiId,
        ),
      );

  /// Lock ativo da forma; "impossível" vence "só por distribuição".
  ShinyLockType? _lockOf(int formId) {
    final types = {
      for (final lock in _shinyLocks.values)
        if (lock.active && lock.forms.any((f) => f.id == formId)) lock.lockType,
    };
    if (types.contains(ShinyLockType.unobtainable)) {
      return ShinyLockType.unobtainable;
    }
    return types.contains(ShinyLockType.distroOnly)
        ? ShinyLockType.distroOnly
        : null;
  }

  void addForm({
    required int id,
    required String name,
    List<String> types = const ['normal'],
    int genderRate = 4,
    SpeciesCategory category = SpeciesCategory.regular,
    ShinyLockType? shinyLock,

    /// Forma da qual esta evolui (a regra do `evolve`).
    int? evolvesFrom,
  }) {
    _genderRates[id] = genderRate;
    _categories[id] = category;
    if (evolvesFrom != null) _evolvesFrom[id] = evolvesFrom;
    _forms[id] = FormDetail(
      id: id,
      name: name,
      pokeapiId: id,
      nationalNumber: id,
      spriteUrl: '$_spriteBase/pokemon/other/home/$id.png',
      shinySpriteUrl: '$_spriteBase/pokemon/other/home/shiny/$id.png',
      types: [
        for (final (i, type) in types.indexed)
          FormType(slot: i + 1, type: type),
      ],
      abilities: const [
        FormAbility(slot: 1, ability: 'run-away'),
        FormAbility(slot: 3, ability: 'keen-eye', isHidden: true),
      ],
    );
    if (shinyLock != null) {
      addShinyLock(caption: name, lockType: shinyLock, formIds: [id]);
    }
  }

  int addTrainer({
    required String name,
    required String trainerId,
    String? version,
  }) {
    final id = _newId(_trainers.keys);
    _trainers[id] = Trainer(
      id: id,
      name: name,
      trainerId: trainerId,
      version: version,
    );
    return id;
  }

  /// Cria um save do treinador [trainerId] (sem validar a versão: os
  /// testes montam o cenário à vontade).
  int addSave({required int trainerId, String label = ''}) {
    final id = _newId(_saves.keys);
    _saves[id] = Save(id: id, trainer: _trainers[trainerId]!, label: label);
    return id;
  }

  /// Põe o espécime no save [saveId] (`null` = HOME), desde [since].
  void moveTo(int specimenId, int? saveId, {DateTime? since}) {
    final specimen = _specimens[specimenId]!;
    _specimens[specimenId] = saveId == null
        ? specimen.copyWith(location: null, locationSince: null)
        : specimen.copyWith(
            location: _saves[saveId],
            locationSince: since ?? _today(),
          );
  }

  int addDex({required String name, bool isShinyDex = false}) {
    final id = _newId(_dexes.keys);
    _dexes[id] = PersonalDex(
      id: id,
      name: name,
      total: 0,
      registered: 0,
      isShinyDex: isShinyDex,
    );
    return id;
  }

  /// Cria uma box de 30 slots; posições sem forma ficam livres e, como no
  /// backend, não pertencem a nenhum dex.
  int addBox({
    required int dexId,
    required String name,
    required List<int> formIds,
  }) {
    final id = _newId(_boxes.keys);
    final position = _boxes.values.map((b) => b.position).fold(0, max) + 1;
    final box = BoxRef(id: id, name: name, position: position);
    _boxes[id] = box;
    for (var index = 0; index < 30; index++) {
      final slotId = _newId(_slots.keys);
      final hasForm = index < formIds.length;
      _slots[slotId] = _SlotRecord(
        id: slotId,
        box: box,
        row: index ~/ 6,
        col: index % 6,
        dexId: hasForm ? dexId : null,
        formId: hasForm ? formIds[index] : null,
      );
    }
    return id;
  }

  /// "HOME n" pela posição da próxima box, pulando nomes já usados (como
  /// `create_boxes` no backend).
  String _nextBoxName() {
    final names = {for (final b in _boxes.values) b.name};
    var number = _boxes.length + 1;
    while (names.contains('HOME $number')) {
      number++;
    }
    return 'HOME $number';
  }

  /// Box de 30 slots sem forma nem dex (como as criadas por
  /// `create_home_boxes` no backend).
  int addFreeBox(String name) =>
      addBox(dexId: 0, name: name, formIds: const []);

  int addSpecimen({
    required int formId,
    bool isShiny = false,
    bool isAlpha = false,
    bool isFromGo = false,
    String? nickname,
    String? gender,
    String? nature,
    String? pokeball,
    int? ot,
    DateTime? capturedAt,
    String? observation,
    DateTime? championsSince,
    HuntRecord? hunt,
  }) {
    final id = _newId(_specimens.keys);
    final form = _forms[formId]!;
    _specimens[id] = Specimen(
      id: id,
      form: formId,
      formRef: _formRef(form),
      formName: form.name,
      nickname: nickname,
      gender: gender,
      nature: nature,
      isShiny: isShiny,
      isAlpha: isAlpha,
      isFromGo: isFromGo,
      pokeball: pokeball,
      pokeballSpriteUrl: _ballSprite(pokeball),
      ot: ot,
      capturedAt: capturedAt,
      observation: observation,
      championsSince: championsSince,
      hunt: hunt,
    ).withOrigin(_originMarkOf, _otVersion(ot));
    return id;
  }

  // ---- PersonalDexRepository ----

  @override
  Future<List<PersonalDex>> fetchDexes() async {
    await _delay();
    return [for (final id in _dexes.keys) _dexWithCounts(id)];
  }

  /// As formas de um dex novo, na ordem das boxes, e onde começa cada seção
  /// (uma geração no Nacional, uma pokédex no dex por jogo): com "nova box"
  /// ligado, cada seção abre uma box. Com catálogo, o conjunto padrão com as
  /// chaves de [recipe] (#34); no seed fixo, todas as formas cadastradas,
  /// com as gerações pelos iniciais (sem catálogo não há como saber o que é
  /// regional ou evolui).
  DexLayout _layoutFor(DexRecipe recipe) {
    final catalog = this.catalog;
    if (catalog == null) {
      final forms = _forms.values.toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      const starters = [
        'chikorita', 'treecko', 'turtwig', 'victini', //
        'chespin', 'rowlet', 'grookey', 'sprigatito',
      ];
      return (
        forms: forms,
        starts: {
          for (final (i, f) in forms.indexed)
            if (i > 0 && starters.contains(f.name)) i,
        },
      );
    }
    final forms = <FormDetail>[];
    final starts = <int>{};
    for (final section in catalog.dexSections(recipe)) {
      if (forms.isNotEmpty) starts.add(forms.length);
      forms.addAll([for (final id in section) ?_forms[id]]);
    }
    return (forms: forms, starts: starts);
  }

  /// Limite de boxes (o do HOME); os testes podem baixar.
  int maxBoxes = homeMaxBoxes;

  /// Mesmas regras do backend (`home/services.py`): simula o esquema e acha a
  /// 1ª sequência de boxes livres que comporte todas as formas; se nenhuma
  /// comportar, completa a sequência livre do fim com boxes novas, até
  /// [maxBoxes].
  ({int needed, int largest, List<BoxRef>? boxes, int toCreate}) _planDex(
    DexLayout layout,
    bool forceNewBox,
  ) {
    final (:forms, :starts) = layout;
    var needed = 0;
    for (var index = 0; index < forms.length;) {
      needed++;
      for (
        var position = 0;
        position < 30 && index < forms.length;
        position++
      ) {
        if (forceNewBox && position > 0 && starts.contains(index)) break;
        index++;
      }
    }
    final runs = <List<BoxRef>>[[]];
    for (final box
        in _boxes.values.toList()
          ..sort((a, b) => a.position.compareTo(b.position))) {
      final used = _slots.values.any(
        (s) => s.box.id == box.id && (s.dexId != null || s.formId != null),
      );
      if (used) {
        if (runs.last.isNotEmpty) runs.add([]);
      } else {
        runs.last.add(box);
      }
    }
    final largest = runs.map((r) => r.length).fold(0, (a, b) => a > b ? a : b);
    final fitting = runs.where((r) => r.length >= needed).firstOrNull;
    if (fitting != null) {
      return (
        needed: needed,
        largest: largest,
        boxes: fitting.sublist(0, needed),
        toCreate: 0,
      );
    }
    // Só a sequência que vai até a última box pode continuar em boxes novas.
    final last = _boxes.values.isEmpty
        ? null
        : _boxes.values.reduce((a, b) => a.position > b.position ? a : b);
    final trailing = runs.last.isNotEmpty && runs.last.last.id == last?.id
        ? runs.last
        : <BoxRef>[];
    final missing = needed - trailing.length;
    final fits = _boxes.length + missing <= maxBoxes;
    return (
      needed: needed,
      largest: largest,
      boxes: fits ? trailing : null,
      toCreate: fits ? missing : 0,
    );
  }

  @override
  Future<DexPreview> previewNewDex({
    required DexRecipe recipe,
    required bool forceNewBox,
  }) async {
    await _delay();
    final layout = _layoutFor(recipe);
    final plan = _planDex(layout, forceNewBox);
    return DexPreview(
      forms: layout.forms.length,
      boxesNeeded: plan.needed,
      largestFreeRun: plan.largest,
      enoughSpace: plan.boxes != null,
      boxesToCreate: plan.toCreate,
      firstBox: plan.boxes?.firstOrNull,
    );
  }

  @override
  Future<PersonalDex> createDex({
    required String name,
    required bool isShinyDex,
    required bool forceNewBox,
    DexRecipe recipe = const DexRecipe(),
  }) async {
    await _delay();
    if (name.trim().isEmpty) {
      throw const ValidationFailure({
        'name': [Problem.blank()],
      });
    }
    if (_dexes.values.any((d) => d.name == name)) {
      throw const ValidationFailure({
        'name': [Problem.dexNameTaken()],
      });
    }
    final layout = _layoutFor(recipe);
    final (:forms, :starts) = layout;
    final plan = _planDex(layout, forceNewBox);
    final boxes = plan.boxes;
    if (boxes == null) {
      throw ValidationFailure({
        ValidationFailure.nonFieldKey: [
          Problem.noFreeBoxes(
            needed: plan.needed,
            largest: plan.largest,
            max: maxBoxes,
          ),
        ],
      });
    }
    final id = addDex(name: name, isShinyDex: isShinyDex);
    _dexes[id] = _dexes[id]!.copyWith(forceNewBox: forceNewBox, recipe: recipe);
    final newBoxes = [
      for (var i = 0; i < plan.toCreate; i++)
        _boxes[addFreeBox(_nextBoxName())]!,
    ];
    var index = 0;
    for (final box in [...boxes, ...newBoxes]) {
      final slots = _slots.values.where((s) => s.box.id == box.id).toList();
      for (final (position, slot) in slots.indexed) {
        if (index >= forms.length) break;
        if (forceNewBox && position > 0 && starts.contains(index)) break;
        slot
          ..dexId = id
          ..formId = forms[index++].id;
      }
    }
    return _dexWithCounts(id);
  }

  /// Como o `PATCH` da API: nome e shiny dex; nome vazio ou repetido → 400.
  @override
  Future<PersonalDex> updateDex(
    int dexId, {
    required String name,
    required bool isShinyDex,
  }) async {
    await _delay();
    final dex = _dexes[dexId];
    if (dex == null) throw const NotFoundFailure();
    if (name.trim().isEmpty) {
      throw const ValidationFailure({
        'name': [Problem.blank()],
      });
    }
    if (_dexes.values.any((d) => d.id != dexId && d.name == name)) {
      throw const ValidationFailure({
        'name': [Problem.dexNameTaken()],
      });
    }
    _dexes[dexId] = dex.copyWith(name: name, isShinyDex: isShinyDex);
    return _dexWithCounts(dexId);
  }

  /// Como `delete_dex` da API: libera os slots (sem forma, dex nem
  /// espécime); os espécimes continuam, disponíveis.
  @override
  Future<void> deleteDex(int dexId) async {
    await _delay();
    if (_dexes.remove(dexId) == null) throw const NotFoundFailure();
    for (final slot in _slots.values.where((s) => s.dexId == dexId)) {
      slot
        ..dexId = null
        ..formId = null
        ..specimenId = null;
    }
  }

  // --- Dex desatualizado (#308) ---

  /// Os slots do dex com forma, na ordem das boxes.
  List<_SlotRecord> _dexSlots(int dexId) =>
      _slots.values.where((s) => s.dexId == dexId && s.formId != null).toList()
        ..sort(_slotOrder);

  static int _slotOrder(_SlotRecord a, _SlotRecord b) =>
      switch (a.box.position.compareTo(b.box.position)) {
        0 => (a.row * 6 + a.col).compareTo(b.row * 6 + b.col),
        final c => c,
      };

  /// O que o padrão de hoje mudou no dex [dexId]: o que a receita dele dá,
  /// as formas que entram e as que saem; `null` sem catálogo.
  DexChange? _dexChange(int dexId) {
    final dex = _dexes[dexId];
    if (dex == null) throw const NotFoundFailure();
    if (catalog == null) return null;
    final recipe = dex.recipe ?? const DexRecipe();
    final target = _layoutFor(recipe);
    final current = [for (final s in _dexSlots(dexId)) s.formId!];
    final targetIds = {for (final f in target.forms) f.id};
    final currentIds = current.toSet();
    return (
      recipe: recipe,
      target: target,
      current: current,
      added: [
        for (final f in target.forms)
          if (!currentIds.contains(f.id)) f.id,
      ],
      removed: [
        for (final id in current)
          if (!targetIds.contains(id)) id,
      ],
    );
  }

  static String _signature(List<int> added, List<int> removed) =>
      '+${(added.toList()..sort()).join(',')}'
      '-${(removed.toList()..sort()).join(',')}';

  /// As formas do dex "na ordem": o esquema do padrão de hoje; com as
  /// formas que saíram mantidas, cada uma logo depois da que vinha antes
  /// dela no dex (na mesma seção).
  DexLayout _inOrderLayout(DexChange change, {required bool dropRemoved}) {
    if (dropRemoved || change.removed.isEmpty) return change.target;
    final forms = [...change.target.forms];
    final sectionOf = <int>[];
    var section = 0;
    for (var i = 0; i < forms.length; i++) {
      if (change.target.starts.contains(i)) section++;
      sectionOf.add(section);
    }
    final removed = change.removed.toSet();
    int? previous;
    for (final id in change.current) {
      if (removed.contains(id)) {
        final at = previous == null
            ? 0
            : forms.indexWhere((f) => f.id == previous) + 1;
        forms.insert(at, _forms[id]!);
        sectionOf.insert(at, at == 0 ? 0 : sectionOf[at - 1]);
      }
      previous = id;
    }
    // No Nacional, a seção é a geração da própria forma, como ao criar o
    // dex (o Mewtwo mantido volta a uma box da 1ª geração); no dex por
    // jogo, a pokédex da forma de antes.
    final catalog = this.catalog!;
    final national = change.recipe.versionGroup == null;
    return (
      forms: forms,
      starts: {
        for (var i = 1; i < forms.length; i++)
          if (national
              ? catalog.generation(forms[i].id) !=
                    catalog.generation(forms[i - 1].id)
              : sectionOf[i] != sectionOf[i - 1])
            i,
      },
    );
  }

  /// As boxes que o dex pode usar, em ordem: as dele; depois, as livres que
  /// vêm depois da última dele; depois, até [needed], boxes novas no fim
  /// (só os nomes, sem criar).
  ({List<BoxRef> boxes, List<String> newNames}) _boxesForDex(
    int dexId,
    int needed,
  ) {
    final own = {for (final s in _dexSlots(dexId)) s.box.id: s.box}.values
        .toList();
    final last = own.isEmpty ? 0 : own.last.position;
    final used = {
      for (final s in _slots.values)
        if (s.dexId != null) s.box.id,
    };
    final free =
        _boxes.values
            .where((b) => b.position > last && !used.contains(b.id))
            .toList()
          ..sort((a, b) => a.position.compareTo(b.position));
    final boxes = [...own, ...free];
    final names = {for (final b in _boxes.values) b.name};
    final newNames = <String>[];
    var number = _boxes.length + 1;
    while (boxes.length + newNames.length < needed) {
      while (names.contains('HOME $number')) {
        number++;
      }
      names.add('HOME $number');
      newNames.add('HOME $number');
    }
    return (boxes: boxes, newNames: newNames);
  }

  /// Quantas boxes o esquema [layout] ocupa, com "nova box" por seção.
  static int _boxesNeeded(DexLayout layout, {required bool forceNewBox}) {
    var needed = 0;
    for (var index = 0; index < layout.forms.length;) {
      needed++;
      for (
        var position = 0;
        position < 30 && index < layout.forms.length;
        position++
      ) {
        if (forceNewBox && position > 0 && layout.starts.contains(index)) {
          break;
        }
        index++;
      }
    }
    return needed;
  }

  @override
  Future<DexUpdatePreview?> previewDexUpdate(
    int dexId, {
    bool dropRemoved = true,
  }) async {
    await _delay();
    final change = _dexChange(dexId);
    if (change == null || (change.added.isEmpty && change.removed.isEmpty)) {
      return null;
    }
    final dex = _dexes[dexId]!;
    final before = _dexSlots(dexId);
    final boxesBefore = {for (final s in before) s.box.id}.length;

    // Na ordem: onde cada forma iria, e o que muda.
    final layout = _inOrderLayout(change, dropRemoved: dropRemoved);
    final needed = _boxesNeeded(layout, forceNewBox: dex.forceNewBox);
    final available = _boxesForDex(dexId, needed);
    final fits = _boxes.length + available.newNames.length <= maxBoxes;
    final allBoxes = [
      ...available.boxes.map((b) => b.name),
      ...available.newNames,
    ];
    final placed = <String, int>{}; // "box:posição" → forma
    var index = 0;
    for (var b = 0; b < needed; b++) {
      for (var position = 0; position < 30; position++) {
        if (index >= layout.forms.length) break;
        if (dex.forceNewBox && position > 0 && layout.starts.contains(index)) {
          break;
        }
        placed['${allBoxes[b]}:$position'] = layout.forms[index++].id;
      }
    }
    final was = {
      for (final s in before) '${s.box.name}:${s.row * 6 + s.col}': s,
    };
    final changed = <String>{
      for (final MapEntry(:key, :value) in was.entries)
        if (placed[key] != value.formId) key.split(':').first,
      for (final MapEntry(:key, :value) in placed.entries)
        if (was[key]?.formId != value) key.split(':').first,
    };
    final moved = before
        .where(
          (s) =>
              s.specimenId != null &&
              placed['${s.box.name}:${s.row * 6 + s.col}'] != s.formId &&
              !(dropRemoved && change.removed.contains(s.formId)),
        )
        .length;

    // No fim: as formas novas em boxes depois da última do dex.
    final atEnd = _atEndBoxes(dexId, change.added.length);
    final removed = change.removed.toSet();
    return DexUpdatePreview(
      added: [for (final id in change.added) _formRef(_forms[id]!)],
      removed: [for (final id in change.removed) _formRef(_forms[id]!)],
      signature: _signature(change.added, change.removed),
      recipe: change.recipe,
      boxesBefore: boxesBefore,
      boxesAfter: needed,
      changedBoxes: [
        for (final name in allBoxes)
          if (changed.contains(name)) name,
      ],
      movedSpecimens: moved,
      inOrderFits: fits,
      atEndBoxes: atEnd.boxes,
      atEndFits: atEnd.fits,
      removedWithSpecimen: before
          .where((s) => removed.contains(s.formId) && s.specimenId != null)
          .length,
    );
  }

  /// "No fim": as boxes (livres depois do dex, ou novas) que recebem
  /// [count] formas, cada uma com quantas.
  ({List<DexUpdateBox> boxes, bool fits}) _atEndBoxes(int dexId, int count) {
    final needed = (count / 30).ceil();
    final own = {for (final s in _dexSlots(dexId)) s.box.id};
    final available = _boxesForDex(dexId, own.length + needed);
    final free = available.boxes.where((b) => !own.contains(b.id)).toList();
    final names = [
      for (final b in free) (name: b.name, isNew: false),
      for (final n in available.newNames) (name: n, isNew: true),
    ];
    return (
      boxes: [
        for (var i = 0; i < needed; i++)
          DexUpdateBox(
            name: names[i].name,
            forms: i < needed - 1 ? 30 : count - 30 * (needed - 1),
            isNew: names[i].isNew,
          ),
      ],
      fits: _boxes.length + available.newNames.length <= maxBoxes,
    );
  }

  @override
  Future<PersonalDex> applyDexUpdate(
    int dexId, {
    required DexUpdateMode mode,
    required bool dropRemoved,
  }) async {
    await _delay();
    final change = _dexChange(dexId);
    if (change == null || (change.added.isEmpty && change.removed.isEmpty)) {
      return _dexWithCounts(dexId);
    }
    final dex = _dexes[dexId]!;
    final removed = change.removed.toSet();
    final before = _dexSlots(dexId);
    // Cada espécime vai junto com a forma dele.
    final specimenOf = {
      for (final s in before)
        if (s.specimenId != null) s.formId!: s.specimenId,
    };
    List<_SlotRecord> slotsOf(BoxRef box) =>
        _slots.values.where((s) => s.box.id == box.id).toList()
          ..sort(_slotOrder);
    List<BoxRef> take(List<String> newNames) => [
      for (final name in newNames) _boxes[addFreeBox(name)]!,
    ];

    switch (mode) {
      case DexUpdateMode.inOrder:
        final layout = _inOrderLayout(change, dropRemoved: dropRemoved);
        final needed = _boxesNeeded(layout, forceNewBox: dex.forceNewBox);
        final available = _boxesForDex(dexId, needed);
        if (_boxes.length + available.newNames.length > maxBoxes) {
          throw ValidationFailure({
            ValidationFailure.nonFieldKey: [
              Problem.noFreeBoxes(
                needed: needed,
                largest: available.boxes.length,
                max: maxBoxes,
              ),
            ],
          });
        }
        for (final slot in before) {
          slot
            ..dexId = null
            ..formId = null
            ..specimenId = null;
        }
        final boxes = [...available.boxes, ...take(available.newNames)];
        var index = 0;
        for (final box in boxes.take(needed)) {
          for (final (position, slot) in slotsOf(box).indexed) {
            if (index >= layout.forms.length) break;
            if (dex.forceNewBox &&
                position > 0 &&
                layout.starts.contains(index)) {
              break;
            }
            final form = layout.forms[index++].id;
            slot
              ..dexId = dexId
              ..formId = form
              ..specimenId = specimenOf[form];
          }
        }
      case DexUpdateMode.atEnd:
        // As boxes antes de tirar as formas que saíram: como na prévia.
        final atEnd = _atEndBoxes(dexId, change.added.length);
        if (!atEnd.fits) {
          throw ValidationFailure({
            ValidationFailure.nonFieldKey: [
              Problem.noFreeBoxes(
                needed: atEnd.boxes.length,
                largest: 0,
                max: maxBoxes,
              ),
            ],
          });
        }
        if (dropRemoved) {
          for (final slot in before.where((s) => removed.contains(s.formId))) {
            slot
              ..dexId = null
              ..formId = null
              ..specimenId = null;
          }
        }
        final byName = {for (final b in _boxes.values) b.name: b};
        var index = 0;
        for (final target in atEnd.boxes) {
          final box = byName[target.name] ?? take([target.name]).single;
          for (final slot in slotsOf(box)) {
            if (index >= change.added.length) break;
            slot
              ..dexId = dexId
              ..formId = change.added[index++];
          }
        }
    }
    // O que sobra da mudança são as formas que o usuário quis manter: o
    // aviso não volta por elas, só se o padrão mudar de novo.
    final rest = _dexChange(dexId)!;
    _dexes[dexId] = dex.copyWith(
      recipe: change.recipe,
      updateLater: null,
      updateIgnored: rest.added.isEmpty && rest.removed.isEmpty
          ? null
          : _signature(rest.added, rest.removed),
    );
    return _dexWithCounts(dexId);
  }

  @override
  Future<PersonalDex> snoozeDexUpdate(
    int dexId, {
    required String signature,
    required bool ignore,
  }) async {
    await _delay();
    final dex = _dexes[dexId];
    if (dex == null) throw const NotFoundFailure();
    _dexes[dexId] = ignore
        ? dex.copyWith(updateIgnored: signature, updateLater: null)
        : dex.copyWith(updateLater: signature);
    return _dexWithCounts(dexId);
  }

  @override
  Future<PersonalDex> fetchDex(int dexId) async {
    await _delay();
    if (!_dexes.containsKey(dexId)) throw const NotFoundFailure();
    return _dexWithCounts(dexId);
  }

  /// Como a API: slots com forma agrupados pela geração, na ordem da
  /// primeira box. No fake, a geração sai do número da Pokédex nacional.
  @override
  Future<List<GenerationProgress>> fetchGenerations(int dexId) async {
    await _delay();
    final byGeneration = <String, List<_SlotRecord>>{};
    for (final slot in _slots.values) {
      final formId = slot.formId;
      if (slot.dexId != dexId || formId == null) continue;
      final generation = _generationOf(_forms[formId]!);
      byGeneration.putIfAbsent(generation, () => []).add(slot);
    }
    return [
      for (final MapEntry(key: generation, value: slots)
          in byGeneration.entries)
        GenerationProgress(
          generation: generation,
          total: slots.length,
          registered: slots.where(_countsForProgress).length,
          away: slots.where(_isAway).length,
          firstBox: slots.first.box,
        ),
    ];
  }

  @override
  Future<List<BoxSummary>> fetchBoxes(int dexId) async {
    await _delay();
    final byBox = <int, List<_SlotRecord>>{};
    for (final slot in _slots.values.where((s) => s.dexId == dexId)) {
      byBox.putIfAbsent(slot.box.id, () => []).add(slot);
    }
    return [
      for (final MapEntry(key: boxId, value: slots) in byBox.entries)
        BoxSummary(
          id: boxId,
          name: _boxes[boxId]!.name,
          position: _boxes[boxId]!.position,
          total: slots.where((s) => s.formId != null).length,
          registered: slots
              .where((s) => s.formId != null && _countsForProgress(s))
              .length,
          away: slots.where((s) => s.formId != null && _isAway(s)).length,
        ),
    ]..sort((a, b) => a.position.compareTo(b.position));
  }

  @override
  Future<List<Slot>> fetchSlots({
    required int dexId,
    required int boxId,
  }) async {
    await _delay();
    return [
      for (final slot in _slots.values)
        if (slot.dexId == dexId && slot.box.id == boxId) _toSlot(slot),
    ];
  }

  /// Como a API: nome da forma ou número ([_hasNumber]); só slots com forma,
  /// na ordem das boxes.
  @override
  Future<List<Slot>> searchSlots({
    required int dexId,
    required String search,
  }) async {
    await _delay();
    final text = search.trim().toLowerCase();
    final number = int.tryParse(text);
    final slug = slugSearch(text);
    bool matches(FormDetail form) =>
        number == null ? form.name.contains(slug) : _hasNumber(form, number);
    // Por nome, os mais parecidos primeiro: o nome exato, depois os que
    // começam com o texto, depois os que só o contêm ("mew": Mew antes de
    // Mewtwo). Dentro de cada grupo, a ordem das boxes.
    int rank(FormDetail form) => number != null || form.name == slug
        ? 0
        : form.name.startsWith(slug)
        ? 1
        : 2;
    final groups = [<_SlotRecord>[], <_SlotRecord>[], <_SlotRecord>[]];
    for (final slot in _slots.values) {
      if (slot.dexId != dexId || slot.formId == null) continue;
      final form = _forms[slot.formId]!;
      if (matches(form)) groups[rank(form)].add(slot);
    }
    return [for (final slot in groups.expand((g) => g).take(30)) _toSlot(slot)];
  }

  @override
  Future<Slot> fetchSlot(int slotId) async {
    await _delay();
    final slot = _slots[slotId];
    if (slot == null) throw const NotFoundFailure();
    return _toSlot(slot);
  }

  @override
  Future<Slot> deposit({required int slotId, required int specimenId}) async {
    await _delay();
    final slot = _slots[slotId];
    if (slot == null) throw const NotFoundFailure();
    if (slot.formId == null) {
      throw const ValidationFailure({
        ValidationFailure.nonFieldKey: [Problem.slotWithoutForm()],
      });
    }
    final specimen = _specimens[specimenId];
    if (specimen == null) {
      throw const ValidationFailure({
        'specimen_id': [Problem.specimenNotFound()],
      });
    }
    if (specimen.form != slot.formId) {
      throw const ValidationFailure({
        'specimen_id': [Problem.slotFormMismatch()],
      });
    }
    // Slot reservado: o espécime dele está num save e volta para cá.
    final current = _specimens[slot.specimenId];
    if (current != null &&
        current.id != specimenId &&
        current.location != null) {
      throw const ValidationFailure({
        ValidationFailure.nonFieldKey: [Problem.slotReserved()],
      });
    }
    final holder = _slotHolding(specimenId);
    if (holder != null && holder.id != slotId) {
      throw const ValidationFailure({
        'specimen_id': [Problem.alreadyDeposited()],
      });
    }
    slot.specimenId = specimenId;
    return _toSlot(slot);
  }

  @override
  Future<Slot> withdraw(int slotId) async {
    await _delay();
    final slot = _slots[slotId];
    if (slot == null) throw const NotFoundFailure();
    slot.specimenId = null;
    return _toSlot(slot);
  }

  @override
  Future<List<Slot>> fetchSlotsByForms({
    required int dexId,
    required List<int> formIds,
  }) async {
    await _delay();
    return [
      for (final slot in _slots.values)
        if (slot.dexId == dexId && formIds.contains(slot.formId)) _toSlot(slot),
    ];
  }

  /// Como a API (e o comando `link_specimens`): espécimes livres nos slots
  /// vazios com forma, na ordem das boxes, preferindo o brilho do dex; sem
  /// [strict], usa o outro quando não há. Com [dryRun], só a prévia.
  @override
  Future<LinkResult> linkSpecimens(
    int dexId, {
    bool strict = false,
    bool dryRun = false,
  }) async {
    await _delay();
    final dex = _dexes[dexId];
    if (dex == null) throw const NotFoundFailure();
    final taken = {
      for (final slot in _slots.values)
        if (slot.specimenId != null) slot.specimenId,
    };
    final free = [
      for (final specimen in _specimens.values)
        if (!taken.contains(specimen.id)) specimen,
    ]..sort((a, b) => a.id.compareTo(b.id));
    final linked = <(_SlotRecord, int)>[];
    var missing = 0;
    for (final slot in _slots.values) {
      if (slot.dexId != dexId || slot.formId == null) continue;
      if (slot.specimenId != null) continue;
      Specimen? pick({required bool shiny}) => free
          .where((s) => s.form == slot.formId && s.isShiny == shiny)
          .firstOrNull;
      final specimen =
          pick(shiny: dex.isShinyDex) ??
          (strict ? null : pick(shiny: !dex.isShinyDex));
      if (specimen == null) {
        missing++;
        continue;
      }
      free.remove(specimen);
      linked.add((slot, specimen.id));
    }
    final slots = <Slot>[];
    for (final (slot, specimenId) in linked) {
      final previous = slot.specimenId;
      slot.specimenId = specimenId;
      slots.add(_toSlot(slot));
      if (dryRun) slot.specimenId = previous;
    }
    return LinkResult(linked: linked.length, missing: missing, slots: slots);
  }

  /// Como a API: só shiny dex (senão 400); motivos somados (OU), escopo
  /// combinado (E), tipos "qualquer um", shiny impossível fora por padrão,
  /// situação (vazio ou com espécime) só com `registered`;
  /// cada item traz todos os seus motivos. Página fora do intervalo → 404.
  @override
  Future<Paginated<Hunt>> fetchHunts(
    int dexId,
    HuntQuery query, {
    required int page,
    required int pageSize,
  }) async {
    await _delay();
    final hunts = [for (final row in _huntRows(dexId, query)) ?row.hunt];
    final start = (page - 1) * pageSize;
    if (page < 1 || (start >= hunts.length && page > 1)) {
      throw const NotFoundFailure();
    }
    final end = start + pageSize;
    return Paginated(
      count: hunts.length,
      next: end < hunts.length ? 'page=${page + 1}' : null,
      results: hunts.sublist(start, end.clamp(0, hunts.length)),
    );
  }

  @override
  Future<List<HuntBox>> fetchHuntBoxes(int dexId, HuntQuery query) async {
    await _delay();
    final byBox = <BoxRef, List<_HuntRow>>{};
    for (final row in _huntRows(dexId, query)) {
      byBox.putIfAbsent(row.slot.box, () => []).add(row);
    }
    return [
      for (final MapEntry(key: box, value: rows) in byBox.entries)
        if (rows.any((r) => r.hunt != null))
          (
            box: box,
            count: rows.where((r) => r.hunt != null).length,
            cells: [
              for (var index = 0; index < 30; index++)
                switch (rows
                    .where((r) => r.slot.row * 6 + r.slot.col == index)
                    .firstOrNull) {
                  null => HuntCell.empty,
                  _HuntRow(hunt: _?) => HuntCell.listed,
                  _HuntRow(:final missing) when missing => HuntCell.hidden,
                  _ => HuntCell.done,
                },
            ],
          ),
    ];
  }

  /// Os slots do dex na ordem das boxes, cada um com a caçada (quando passa
  /// nos filtros) e se ainda falta, para o mapa da box (#282).
  List<_HuntRow> _huntRows(int dexId, HuntQuery query) {
    final dex = _dexes[dexId];
    if (dex == null) throw const NotFoundFailure();
    if (!dex.isShinyDex) {
      throw const ValidationFailure({
        ValidationFailure.nonFieldKey: [Problem.huntsNeedShinyDex()],
      });
    }
    final search = query.search.trim().toLowerCase();
    final number = int.tryParse(search);
    // Os jogos que ainda chegam ao HOME, mas vão deixar de chegar (#316).
    final today = now();
    final closing = {
      for (final MapEntry(key: version, value: until)
          in (catalog?.homeCutoffs ?? const <String, DateTime>{}).entries)
        if (today.isBefore(until)) version,
    };
    final slots = [
      for (final slot in _slots.values)
        if (slot.dexId == dexId && slot.formId != null) slot,
    ]..sort(_slotOrder);
    return [
      for (final slot in slots)
        () {
          final formId = slot.formId!;
          final form = _forms[formId]!;
          final lock = _lockOf(formId);
          final all = _huntReasons(slot, query.acceptedBalls);
          // O "Sem alfa" só conta ligado (#280): desligado, um shiny que não
          // é alfa já está completo.
          final reasons = [
            for (final r in all)
              if (r != HuntReason.noAlpha || query.reasons.contains(r)) r,
          ];
          final selected = reasons.where(query.reasons.contains).toList();
          final category = _categories[formId] ?? SpeciesCategory.regular;
          // Sem "incluir shiny locks", some o jogo em que a forma é travada.
          bool unlocked(String v) =>
              query.includeLocked || !_lockedVersions(formId).contains(v);
          // Só pelo alfa, onde caçar são os jogos em que ele aparece.
          final versions = [
            for (final v
                in selected.every((r) => r == HuntReason.noAlpha)
                    ? _alphaVersions(formId)
                    : _huntableVersions(formId))
              if (unlocked(v)) v,
          ];
          final matches =
              selected.isNotEmpty &&
              (query.situation.param == null ||
                  query.situation.param == (slot.specimenId != null)) &&
              (query.includeLocked || lock != ShinyLockType.unobtainable) &&
              (query.generations.isEmpty ||
                  query.generations.contains(_generationOf(form))) &&
              (query.types.isEmpty ||
                  form.types.any((t) => query.types.contains(t.type))) &&
              (query.categories.isEmpty ||
                  query.categories.contains(category)) &&
              (query.versions.isEmpty ||
                  query.versions.any(versions.contains)) &&
              switch (query.homeCutoff) {
                HomeCutoffFilter.all => true,
                HomeCutoffFilter.only =>
                  versions.isNotEmpty && versions.every(closing.contains),
                HomeCutoffFilter.also => versions.any(closing.contains),
              } &&
              (search.isEmpty ||
                  (number == null
                      ? form.name.contains(slugSearch(search))
                      : _hasNumber(form, number)));
          return (
            slot: slot,
            missing: reasons.isNotEmpty,
            hunt: matches
                ? Hunt(
                    slot: _toSlot(slot),
                    reasons: reasons,
                    shinyLock: lock,
                    versions: versions,
                  )
                : null,
          );
        }(),
    ];
  }

  /// Versões em que a forma pode ser caçada (do catálogo; nenhuma sem ele),
  /// calculadas uma vez por forma.
  List<String> _huntableVersions(int formId) => switch (catalog) {
    final catalog? => _huntable[formId] ??= catalog.huntableVersions(formId),
    null => const [],
  };

  final _huntable = <int, List<String>>{};

  Set<String> _lockedVersions(int formId) =>
      catalog?.lockedVersions(formId) ?? const <String>{};

  /// Versões em que a forma pode ser alfa (#280); nenhuma sem catálogo.
  List<String> _alphaVersions(int formId) =>
      catalog?.alphaVersions(formId) ?? const [];

  /// Motivos de caçada do slot; `pokeball` só com bolas aceitas, e bola não
  /// informada não conta; `noAlpha` quando a forma pode ser alfa e o slot
  /// não tem um.
  List<HuntReason> _huntReasons(_SlotRecord slot, List<String> acceptedBalls) {
    final id = slot.specimenId;
    final specimen = id == null ? null : _specimens[id];
    final noAlpha = [
      if (_alphaVersions(slot.formId!).isNotEmpty &&
          !(specimen?.isAlpha ?? false))
        HuntReason.noAlpha,
    ];
    if (specimen == null || !specimen.isShiny) {
      return [HuntReason.noShiny, ...noAlpha];
    }
    final ball = specimen.pokeball;
    return [
      ...noAlpha,
      if (specimen.isFromGo) HuntReason.fromGo,
      if (acceptedBalls.isNotEmpty &&
          ball != null &&
          !acceptedBalls.contains(ball))
        HuntReason.pokeball,
    ];
  }

  // ---- SpecimenRepository ----

  @override
  Future<List<Specimen>> fetchAvailable(int formId) async {
    await _delay();
    return [
      for (final specimen in _specimens.values)
        if (specimen.form == formId && _slotHolding(specimen.id) == null)
          specimen,
    ];
  }

  @override
  Future<Specimen> create(SpecimenDraft draft) async {
    await _delay();
    final form = _forms[draft.form];
    if (form == null) {
      throw const ValidationFailure({
        'form': [Problem.invalidForm()],
      });
    }
    _validateAbility(form, draft.ability);
    final hunt = _validHunt(draft);
    final id = _newId(_specimens.keys);
    final specimen = Specimen(
      id: id,
      form: form.id,
      formRef: _formRef(form),
      formName: form.name,
      nickname: draft.nickname,
      ability: draft.ability,
      language: draft.language,
      gender: draft.gender,
      nature: draft.nature,
      isAlpha: draft.isAlpha,
      isShiny: draft.isShiny,
      isFromGo: draft.isFromGo,
      capturedAt: draft.capturedAt,
      pokeball: draft.pokeball,
      pokeballSpriteUrl: _ballSprite(draft.pokeball),
      observation: draft.observation,
      ot: draft.ot,
      hunt: hunt,
    ).withOrigin(_originMarkOf, _otVersion(draft.ot));
    _specimens[id] = specimen;
    return specimen;
  }

  @override
  Future<Specimen> fetchSpecimen(int specimenId) async {
    await _delay();
    final specimen = _specimens[specimenId];
    if (specimen == null) throw const NotFoundFailure();
    return specimen.copyWith(slot: _slotHolding(specimenId)?.id);
  }

  /// Como a API: busca em apelido ou nome da forma; listas por vírgula (OU,
  /// exceto tipos, que exigem todos); ordem por forma e id, ou pela
  /// [SpecimenOrdering]; página fora do intervalo → 404.
  @override
  Future<Paginated<Specimen>> fetchSpecimens(
    SpecimenQuery query, {
    required int page,
    required int pageSize,
  }) async {
    await _delay();
    final matches = [
      for (final s in _specimens.values)
        if (_matches(s, query)) s.copyWith(slot: _slotHolding(s.id)?.id),
    ]..sort(_ordering(query.ordering));
    final start = (page - 1) * pageSize;
    if (page < 1 || (start >= matches.length && page > 1)) {
      throw const NotFoundFailure();
    }
    final end = start + pageSize;
    return Paginated(
      count: matches.length,
      next: end < matches.length ? 'page=${page + 1}' : null,
      results: matches.sublist(start, end.clamp(0, matches.length)),
    );
  }

  @override
  Future<List<int>> fetchSpecimenIds(SpecimenQuery query) async {
    await _delay();
    return [
      for (final s
          in _specimens.values.where((s) => _matches(s, query)).toList()
            ..sort(_ordering(query.ordering)))
        s.id,
    ];
  }

  /// Como a API: tudo ou nada; id inexistente → 400; gênero validado pela
  /// forma (`-male`/`-female`) ou pelo `gender_rate` da espécie.
  @override
  Future<int> bulkUpdate({
    required List<int> ids,
    required SpecimenChanges changes,
  }) async {
    await _delay();
    final unique = ids.toSet();
    if (unique.isEmpty || changes.isEmpty) {
      throw const ValidationFailure({
        ValidationFailure.nonFieldKey: [Problem.nothingToChange()],
      });
    }
    final missing = unique.where((id) => !_specimens.containsKey(id));
    if (missing.isNotEmpty) {
      throw ValidationFailure({
        'ids': [
          Problem.specimensNotFound([...missing]),
        ],
      });
    }
    if (changes.gender case SetTo(value: final String gender)) {
      final conflicts = [
        for (final id in unique.toList()..sort())
          if (!allowedGenders(
            _forms[_specimens[id]!.form]!,
            _genderRates,
          ).contains(gender))
            (id: id, formName: _specimens[id]!.formName!),
      ];
      if (conflicts.isNotEmpty) {
        throw GenderConflictFailure(
          conflicts,
          problem: Problem.impossibleGender(conflicts.length),
        );
      }
    }
    for (final id in unique) {
      _specimens[id] = _applyChanges(_specimens[id]!, changes);
    }
    return unique.length;
  }

  Specimen _applyChanges(Specimen s, SpecimenChanges c) {
    T? pick<T>(FieldEdit<T> edit, T? current) => switch (edit) {
      Keep() => current,
      SetTo(:final value) => value,
    };
    final pokeball = pick(c.pokeball, s.pokeball);
    final changed = s.copyWith(
      pokeball: pokeball,
      pokeballSpriteUrl: _ballSprite(pokeball),
      ot: pick(c.ot, s.ot),
      language: pick(c.language, s.language),
      gender: pick(c.gender, s.gender),
      nature: pick(c.nature, s.nature),
      capturedAt: pick(c.capturedAt, s.capturedAt),
      isShiny: pick(c.isShiny, s.isShiny) ?? s.isShiny,
      // O registro da caçada só existe em shiny.
      hunt: (pick(c.isShiny, s.isShiny) ?? s.isShiny) ? s.hunt : null,
      isAlpha: pick(c.isAlpha, s.isAlpha) ?? s.isAlpha,
      isFromGo: pick(c.isFromGo, s.isFromGo) ?? s.isFromGo,
    );
    return changed.withOrigin(_originMarkOf, switch (c.ot) {
      Keep() => s.originVersion,
      SetTo(:final value) => _otVersion(value),
    });
  }

  @override
  Future<List<FormRef>> searchForms(String search) async {
    await _delay();
    final text = slugSearch(search.trim().toLowerCase());
    // Como a API: um número busca pelo id da forma ou pelo nº nacional.
    final number = int.tryParse(search.trim());
    return [
      for (final form in _forms.values)
        if (number == null
            ? form.name.contains(text)
            : form.pokeapiId == number || form.nationalNumber == number)
          _formRef(form),
    ].take(30).toList();
  }

  @override
  Future<Specimen> update(int specimenId, SpecimenDraft draft) async {
    await _delay();
    final specimen = _specimens[specimenId];
    if (specimen == null) throw const NotFoundFailure();
    if (draft.form != specimen.form) {
      throw const ValidationFailure({
        'form': [Problem.formUnchangeable()],
      });
    }
    _validateAbility(_forms[specimen.form]!, draft.ability);
    final hunt = _validHunt(draft);
    final edited = specimen.copyWith(
      nickname: draft.nickname,
      ability: draft.ability,
      language: draft.language,
      gender: draft.gender,
      nature: draft.nature,
      isAlpha: draft.isAlpha,
      isShiny: draft.isShiny,
      isFromGo: draft.isFromGo,
      capturedAt: draft.capturedAt,
      pokeball: draft.pokeball,
      pokeballSpriteUrl: _ballSprite(draft.pokeball),
      observation: draft.observation,
      ot: draft.ot,
      slot: _slotHolding(specimenId)?.id,
      hunt: hunt,
    );
    // O jogo de origem só muda quando o OT muda (como no backend).
    final updated = draft.ot == specimen.ot
        ? edited.withOrigin(_originMarkOf, specimen.originVersion)
        : edited.withOrigin(_originMarkOf, _otVersion(draft.ot));
    _specimens[specimenId] = updated;
    return updated;
  }

  /// Visita ao Champions (#174): só de quem está no HOME; o Pokémon fica
  /// travado até voltar ([transferCheck], [release]).
  @override
  Future<Specimen> setChampionsVisit(
    int specimenId, {
    required bool visiting,
  }) async {
    await _delay();
    final specimen = _specimens[specimenId];
    if (specimen == null) throw const NotFoundFailure();
    if (visiting && specimen.isAway) {
      throw const ValidationFailure({
        'champions': [Problem.championsHomeOnly()],
      });
    }
    if (visiting == specimen.isVisitingChampions) return specimen;
    final updated = specimen.copyWith(
      championsSince: visiting ? _today() : null,
    );
    _specimens[specimenId] = updated;
    return updated;
  }

  void _checkNotVisiting(Iterable<int> ids) {
    if (ids.any((id) => _specimens[id]?.isVisitingChampions ?? false)) {
      throw const ValidationFailure({
        'champions': [Problem.championsNoRelease()],
      });
    }
  }

  /// Como no backend (`Slot.specimen` com `SET_NULL`): o slot fica faltante.
  @override
  Future<void> release(int specimenId) async {
    await _delay();
    _checkNotVisiting([specimenId]);
    if (_specimens.remove(specimenId) == null) throw const NotFoundFailure();
    _slotHolding(specimenId)?.specimenId = null;
  }

  /// Como `POST /specimens/bulk-release/`: tudo ou nada.
  @override
  Future<int> bulkRelease(List<int> ids) async {
    await _delay();
    final unique = ids.toSet();
    if (unique.isEmpty) {
      throw const ValidationFailure({
        'ids': [Problem.emptyList()],
      });
    }
    final missing = unique.where((id) => !_specimens.containsKey(id));
    if (missing.isNotEmpty) {
      throw ValidationFailure({
        'ids': [
          Problem.specimensNotFound([...missing]),
        ],
      });
    }
    _checkNotVisiting(unique);
    for (final id in unique) {
      _slotHolding(id)?.specimenId = null;
      _specimens.remove(id);
    }
    return unique.length;
  }

  @override
  Future<FormDetail> fetchForm(int formId) async {
    await _delay();
    final form = _forms[formId];
    if (form == null) throw const NotFoundFailure();
    final lock = _lockOf(formId);
    final locked = form.copyWith(
      isShinylocked: lock == ShinyLockType.unobtainable,
      isDistroOnly: lock == ShinyLockType.distroOnly,
    );
    // Com o catálogo, o detalhe já é o real.
    if (catalog != null) return locked;
    return locked.copyWith(
      // Dados da espécie: no fake, valores de exemplo (mas estáveis) e a
      // linha evolutiva montada a partir do `evolvesFrom` do seed.
      stats: [
        for (final (i, stat) in _statNames.indexed)
          FormStat(
            stat: stat,
            baseStat: 40 + (formId * (i + 3) * 7) % 80,
            effort: i == formId % 6 ? 2 : 0,
          ),
      ],
      genderRate: _genderRates[formId] ?? 4,
      captureRate: 45,
      hatchCounter: 20,
      height: 5 + formId % 15,
      weight: 60 + formId * 13 % 900,
      debutVersions: const ['red', 'blue'],
      evolutionChain: _evolutionChain(formId),
    );
  }

  /// Formas que evoluem de alguma das [forms].
  List<int> _evolutionsOf(List<int> forms) => [
    for (final entry in _evolvesFrom.entries)
      if (forms.contains(entry.value)) entry.key,
  ]..sort();

  static const _statNames = [
    'hp',
    'attack',
    'defense',
    'special-attack',
    'special-defense',
    'speed',
  ];

  /// Estágios da linha evolutiva de [formId], como a API: da forma base
  /// até as últimas; vazio se ela não evolui nem vem de outra.
  List<List<FormRef>> _evolutionChain(int formId) {
    var root = formId;
    var from = _evolvesFrom[root];
    while (from != null) {
      root = from;
      from = _evolvesFrom[root];
    }
    final stages = <List<int>>[
      [root],
    ];
    var next = _evolutionsOf(stages.last);
    while (next.isNotEmpty) {
      stages.add(next);
      next = _evolutionsOf(next);
    }
    if (stages.length == 1) return const [];
    return [
      for (final stage in stages)
        [for (final id in stage) _formRef(_forms[id]!)],
    ];
  }

  @override
  Future<SpecimenOptions> fetchOptions() async {
    await _delay();
    return options;
  }

  @override
  Future<List<Trainer>> fetchTrainers() async {
    await _delay();
    return _trainers.values.toList();
  }

  /// Mesmas regras do backend: nome e ID obrigatórios, par (nome, ID) único
  /// e versão existente.
  @override
  Future<List<Save>> fetchSaves() async {
    await _delay();
    return [..._saves.values];
  }

  /// Como `POST /saves/`: só OT de jogo ligado ao HOME (inclusive os só de ida), e uma vez.
  @override
  Future<Save> createSave({required int trainerId, String label = ''}) async {
    await _delay();
    final trainer = _trainers[trainerId];
    Problem? error;
    if (trainer == null) {
      error = const Problem.trainerNotFound();
    } else if (!Save.homeVersions.contains(trainer.version)) {
      error = const Problem.saveNeedsHomeGame();
    } else if (_saves.values.any((s) => s.trainer.id == trainerId)) {
      error = const Problem.trainerAlreadySave();
    }
    if (error != null) {
      throw ValidationFailure({
        'trainer': [error],
      });
    }
    return _saves[addSave(trainerId: trainerId, label: label)]!;
  }

  @override
  Future<Save> updateSave(
    int saveId, {
    String? label,
    bool? hasShinyCharm,
  }) async {
    await _delay();
    final save = _saves[saveId];
    if (save == null) throw const NotFoundFailure();
    if ((hasShinyCharm ?? false) && !save.canHaveShinyCharm) {
      throw const ValidationFailure({
        'shinyCharm': [Problem.noShinyCharm()],
      });
    }
    final updated = save.copyWith(
      label: label ?? save.label,
      hasShinyCharm: hasShinyCharm ?? save.hasShinyCharm,
    );
    _saves[saveId] = updated;
    // Os espécimes guardam uma cópia do save (como a resposta da API).
    for (final s in [..._specimens.values]) {
      if (s.location?.id == saveId) {
        _specimens[s.id] = s.copyWith(location: updated);
      }
    }
    return updated;
  }

  @override
  Future<void> deleteSave(int saveId) async {
    await _delay();
    if (!_saves.containsKey(saveId)) throw const NotFoundFailure();
    if (_specimens.values.any((s) => s.location?.id == saveId)) {
      throw const ValidationFailure({}, detail: Problem.saveHasSpecimens());
    }
    _saves.remove(saveId);
  }

  /// Para a escolha do destino: quem dos [ids] pode ir para o [save] e quem
  /// fica, com o motivo (o Let's Go só recebe quem veio dele,
  /// [Save.accepts]; as restrições do HOME, [transferBlock]), os avisos
  /// ([transferWarning]) e quantos não estão numa pokédex do jogo do save.
  TransferCheck transferCheck(List<int> ids, Save save) {
    final version = save.trainer.version;
    final movable = <int>[];
    final blocked = <TransferIssue>[];
    final warnings = <TransferIssue>[];
    var outside = 0;
    for (final s in [for (final id in ids.toSet()) ?_specimens[id]]) {
      final name = _forms[s.form]?.name ?? '';
      final block = save.isOneWay
          ? const Problem.oneWaySave()
          : s.isVisitingChampions
          ? const Problem.visitingChampions()
          : save.accepts(s.originMark, s.originVersion)
          ? transferBlock(name, s.originMark, version)
          : const Problem.letsGoOnly();
      if (block != null) {
        blocked.add((id: s.id, name: s.displayName, problem: block));
        continue;
      }
      movable.add(s.id);
      final category = _categories[s.form] ?? SpeciesCategory.regular;
      final warning = transferWarning(name, s.originMark, category);
      if (warning != null) {
        warnings.add((id: s.id, name: s.displayName, problem: warning));
      }
      if (!(catalog?.inGame(s.form, version) ?? true)) outside++;
    }
    return TransferCheck(
      movable: movable,
      blocked: blocked,
      warnings: warnings,
      outside: outside,
    );
  }

  /// Como `POST /specimens/transfer/`: para um save, vão só os que podem
  /// ([transferCheck]); se nenhum puder, nada muda. Quem já está no destino
  /// não muda (nem a data).
  @override
  Future<int> transfer(List<int> ids, {required int? saveId}) async {
    await _delay();
    final unique = ids.toSet();
    final missing = unique.where((id) => !_specimens.containsKey(id));
    if (unique.isEmpty || missing.isNotEmpty) {
      throw ValidationFailure({
        'ids': [
          Problem.specimensNotFound([...missing]),
        ],
      });
    }
    if (saveId != null && !_saves.containsKey(saveId)) {
      throw const ValidationFailure({
        'save': [Problem.saveNotFound()],
      });
    }
    var going = unique;
    if (saveId == null) {
      // De volta ao HOME: quem está num save cujo jogo não chega mais ao
      // HOME fica (#222); se ninguém puder voltar, nada muda.
      final stuck = {
        for (final id in unique)
          if (_specimens[id]!.location case final save? when _cutOff(save)) id,
      };
      if (stuck.length == unique.length) {
        final game = _specimens[stuck.first]!.location!.game;
        throw ValidationFailure({
          'save': [Problem.gameCutOff(game)],
        });
      }
      going = unique.difference(stuck);
    } else {
      final check = transferCheck([...unique], _saves[saveId]!);
      if (!check.allowed) {
        throw ValidationFailure({
          'save': [check.blocked.first.problem],
        });
      }
      going = check.movable.toSet();
    }
    final moving = going.where((id) => _specimens[id]!.location?.id != saveId);
    final count = moving.length;
    for (final id in [...moving]) {
      moveTo(id, saveId);
    }
    return count;
  }

  /// Como `POST /specimens/{id}/evolve/`: só evolução (direta ou não); a
  /// habilidade vai para a do mesmo slot e o espécime sai do slot.
  @override
  Future<Specimen> evolve(int specimenId, {required int formId}) async {
    await _delay();
    final specimen = _specimens[specimenId];
    if (specimen == null) throw const NotFoundFailure();
    var current = _evolvesFrom[formId];
    while (current != null && current != specimen.form) {
      current = _evolvesFrom[current];
    }
    if (current == null || !_forms.containsKey(formId)) {
      throw const ValidationFailure({
        'form': [Problem.notAnEvolution()],
      });
    }
    final old = _forms[specimen.form]!.abilities
        .where((a) => a.ability == specimen.ability)
        .firstOrNull;
    final form = _forms[formId]!;
    final ability = old == null
        ? null
        : form.abilities
              .where((a) => a.slot == old.slot && a.isHidden == old.isHidden)
              .firstOrNull
              ?.ability;
    _slotHolding(specimenId)?.specimenId = null;
    final evolved = specimen.copyWith(
      form: formId,
      formRef: _formRef(form),
      formName: form.name,
      ability: ability,
      slot: null,
    );
    _specimens[specimenId] = evolved;
    return evolved;
  }

  @override
  Future<Trainer> createTrainer({
    required String name,
    required String trainerId,
    String? version,
  }) async {
    await _delay();
    const blank = [Problem.blank()];
    final errors = <String, List<Problem>>{
      if (name.trim().isEmpty) 'name': blank,
      if (trainerId.trim().isEmpty) 'trainer_id': blank,
      if (version != null && !versions.any((v) => v.name == version))
        'version': [Problem.unknownVersion(version)],
    };
    if (errors.isNotEmpty) throw ValidationFailure(errors);
    if (_trainers.values.any(
      (t) => t.name == name && t.trainerId == trainerId,
    )) {
      throw const ValidationFailure({
        ValidationFailure.nonFieldKey: [Problem.trainerTaken()],
      });
    }
    final id = addTrainer(name: name, trainerId: trainerId, version: version);
    return _trainers[id]!;
  }

  @override
  Future<List<GameVersion>> fetchVersions() async {
    await _delay();
    return versions;
  }

  // ---- Internos ----

  /// Versão do OT (`null` sem OT ou OT sem versão): o jogo de origem de um
  /// espécime novo ou que trocou de OT, como no backend.
  String? _otVersion(int? ot) => _trainers[ot]?.version;

  Future<void> _delay() async {
    onAccess?.call();
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  PersonalDex _dexWithCounts(int dexId) {
    final slots = _slots.values.where(
      (s) => s.dexId == dexId && s.formId != null,
    );
    return _dexes[dexId]!.copyWith(
      total: slots.length,
      registered: slots.where(_countsForProgress).length,
      away: slots.where(_isAway).length,
    );
  }

  /// Conta no progresso, mas o espécime está num save.
  bool _isAway(_SlotRecord slot) =>
      _countsForProgress(slot) && _specimens[slot.specimenId]!.isAway;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Como `counts_for_progress` da API: slot com espécime e, num shiny dex,
  /// só se ele for shiny (o não shiny fica no slot, mas não completa o dex).
  bool _countsForProgress(_SlotRecord slot) {
    final specimen = _specimens[slot.specimenId];
    if (specimen == null) return false;
    return !_dexes[slot.dexId]!.isShinyDex || specimen.isShiny;
  }

  /// Como `search_forms` da API: nº nacional da espécie ou `pokeapiId`.
  bool _hasNumber(FormDetail form, int number) =>
      form.nationalNumber == number || form.pokeapiId == number;

  bool _matches(Specimen s, SpecimenQuery query) {
    final search = query.search.trim().toLowerCase();
    final number = int.tryParse(search);
    final ability = slugSearch(query.ability.trim().toLowerCase());
    final available = query.status.availableParam;
    final form = _forms[s.form]!;
    final formTypes = {for (final t in form.types) t.type};
    final captured = s.capturedAt;
    bool inList<T>(List<T> values, T? value) =>
        values.isEmpty || values.contains(value);
    return (search.isEmpty ||
            (number == null
                // O apelido é texto livre; o nome da forma, um slug.
                ? (s.nickname ?? '').toLowerCase().contains(search) ||
                      (s.formName ?? '').toLowerCase().contains(
                        slugSearch(search),
                      )
                : _hasNumber(form, number))) &&
        (available == null || (_slotHolding(s.id) == null) == available) &&
        (query.ids.isEmpty || query.ids.contains(s.id)) &&
        (!query.shinyOnly || s.isShiny) &&
        (!query.alphaOnly || s.isAlpha) &&
        (!query.hasPokeballFilter ||
            query.pokeballs.contains(s.pokeball) ||
            (query.withoutPokeball && s.pokeball == null)) &&
        (!query.hasOtFilter ||
            query.ots.contains(s.ot) ||
            (query.withoutOt && s.ot == null)) &&
        query.types.every(formTypes.contains) &&
        inList(query.generations, _generationOf(form)) &&
        inList(
          query.categories,
          _categories[s.form] ?? SpeciesCategory.regular,
        ) &&
        inList(query.originMarks, s.originMark ?? SpecimenQuery.noneParam) &&
        inList(query.genders, s.gender) &&
        inList(query.natures, s.nature) &&
        inList(query.languages, s.language) &&
        switch (query.location) {
          '' => true,
          SpecimenQuery.locationHome => !s.isAway,
          SpecimenQuery.locationAway => s.isAway,
          final save => '${s.location?.id}' == save,
        } &&
        (ability.isEmpty || (s.ability ?? '').contains(ability)) &&
        (query.otVersions.isEmpty ||
            query.otVersions.contains(_trainers[s.ot]?.version)) &&
        (query.fitVersions.isEmpty ||
            query.fitVersions.any((version) => _canGoTo(s, version))) &&
        (query.capturedAfter == null ||
            (captured != null && !captured.isBefore(query.capturedAfter!))) &&
        (query.capturedBefore == null ||
            (captured != null && !captured.isAfter(query.capturedBefore!)));
  }

  /// O espécime pode ir para um save do jogo [version] (#201): as mesmas
  /// regras do [transferCheck] (sem visita ao Champions, aceito pelo jogo e
  /// sem bloqueio do HOME) e a forma numa pokédex do jogo.
  bool _canGoTo(Specimen s, String version) =>
      !s.isVisitingChampions &&
      Save.acceptsIn(version, s.originMark, s.originVersion) &&
      transferBlock(_forms[s.form]?.name ?? '', s.originMark, version) ==
          null &&
      (catalog?.inGame(s.form, version) ?? true);

  /// Mesmas ordens da API; o id faz as vezes do `created_at` e desempata, e
  /// o id da forma, do `form__order`.
  Comparator<Specimen> _ordering(SpecimenOrdering ordering) =>
      switch (ordering) {
        SpecimenOrdering.box => _byKey(_boxKey),
        SpecimenOrdering.national => _byKey(
          (s) => _forms[s.form]!.nationalNumber,
        ),
        SpecimenOrdering.capturedAsc => (a, b) => _byCapture(
          a,
          b,
          descending: false,
        ),
        SpecimenOrdering.capturedDesc => (a, b) => _byCapture(
          a,
          b,
          descending: true,
        ),
        SpecimenOrdering.createdDesc => (a, b) => b.id - a.id,
      };

  /// Pela chave (`null` no fim), depois forma e id.
  static Comparator<Specimen> _byKey(int? Function(Specimen) key) => (a, b) {
    final (x, y) = (key(a), key(b));
    if (x != y) {
      if (x == null) return 1;
      if (y == null) return -1;
      return x - y;
    }
    return a.form != b.form ? a.form - b.form : a.id - b.id;
  };

  /// Como `box_order` da API: o slot do espécime, se depositado; senão o 1º
  /// slot (menor box) com a forma dele; `null` fora das boxes.
  int? _boxKey(Specimen specimen) {
    int key(_SlotRecord s) => s.box.position * 30 + s.row * 6 + s.col;
    final own = _slotHolding(specimen.id);
    if (own != null) return key(own);
    final keys = [
      for (final s in _slots.values)
        if (s.formId == specimen.form) key(s),
    ];
    return keys.isEmpty ? null : keys.reduce((a, b) => a < b ? a : b);
  }

  /// Pela data de captura; sem data sempre no fim, nas duas direções.
  static int _byCapture(Specimen a, Specimen b, {required bool descending}) {
    final tieBreak = descending ? b.id - a.id : a.id - b.id;
    final (x, y) = (a.capturedAt, b.capturedAt);
    if (x == null && y == null) return tieBreak;
    if (x == null) return 1;
    if (y == null) return -1;
    final byDate = descending ? y.compareTo(x) : x.compareTo(y);
    return byDate != 0 ? byDate : tieBreak;
  }

  /// Último número da Pokédex nacional de cada geração.
  static const _generationEnds = [151, 251, 386, 493, 649, 721, 809, 905];
  static const _romans = ['i', 'ii', 'iii', 'iv', 'v', 'vi', 'vii', 'viii'];

  /// A geração pelo número nacional: o `pokeapiId` das formas alternativas
  /// passa de 10000 e cairia sempre na geração 9 (#324).
  static String _generationOf(FormDetail form) {
    final dexNumber = form.nationalNumber ?? form.pokeapiId;
    for (final (i, end) in _generationEnds.indexed) {
      if (dexNumber <= end) return 'generation-${_romans[i]}';
    }
    return 'generation-ix';
  }

  /// O registro da caçada do [draft], validado: fora de shiny, ou em branco
  /// ([HuntRecord.isBlank]), não guarda nada.
  HuntRecord? _validHunt(SpecimenDraft draft) {
    final hunt = draft.hunt;
    if (hunt == null || !draft.isShiny || hunt.isBlank) return null;
    final errors = <String, List<Problem>>{};
    final methods = catalog?.shinyMethods ?? const <ShinyMethod>[];
    final method = methods.where((m) => m.id == hunt.method).firstOrNull;
    if (hunt.method != null && methods.isNotEmpty && method == null) {
      errors['huntMethod'] = [const Problem.unknownHuntMethod()];
    }
    if (hunt.count case final count? when count <= 0) {
      errors['huntCount'] = [const Problem.huntCountNotPositive()];
    }
    if (hunt.unit case final unit?
        when method != null && !method.units.contains(unit)) {
      errors['huntUnit'] = [const Problem.huntUnitNotOfMethod()];
    }
    final (start, end) = (hunt.startedAt, draft.capturedAt);
    if (start != null && end != null && start.isAfter(end)) {
      errors['huntStartedAt'] = [const Problem.huntStartAfterCapture()];
    }
    final url = hunt.postUrl;
    if (url != null && url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri == null || !{'http', 'https'}.contains(uri.scheme)) {
        errors['huntPostUrl'] = [const Problem.invalidLink()];
      }
    }
    if (errors.isNotEmpty) throw ValidationFailure(errors);
    return hunt.copyWith(postUrl: url == null || url.isEmpty ? null : url);
  }

  void _validateAbility(FormDetail form, String? ability) {
    if (ability != null &&
        ability.isNotEmpty &&
        !form.abilities.any((a) => a.ability == ability)) {
      throw const ValidationFailure({
        'ability': [Problem.invalidAbility()],
      });
    }
  }

  _SlotRecord? _slotHolding(int specimenId) {
    for (final slot in _slots.values) {
      if (slot.specimenId == specimenId) return slot;
    }
    return null;
  }

  Slot _toSlot(_SlotRecord record) {
    final formId = record.formId;
    final specimenId = record.specimenId;
    final specimen = specimenId == null ? null : _specimens[specimenId];
    final isShinyDex = _dexes[record.dexId]?.isShinyDex ?? false;
    return Slot(
      id: record.id,
      box: record.box,
      row: record.row,
      col: record.col,
      personalDex: record.dexId,
      form: formId == null ? null : _formRef(_forms[formId]!),
      specimen: specimen == null
          ? null
          : SpecimenSummary(
              id: specimen.id,
              nickname: specimen.nickname,
              formName: specimen.formName,
              ability: specimen.ability,
              isShiny: specimen.isShiny,
              isAlpha: specimen.isAlpha,
              isFromGo: specimen.isFromGo,
              gender: specimen.gender,
              pokeball: specimen.pokeball,
              pokeballSpriteUrl: specimen.pokeballSpriteUrl,
              location: specimen.location,
              locationSince: specimen.locationSince,
              championsSince: specimen.championsSince,
            ),
      isShinyDisplay: specimen == null
          ? formId != null && isShinyDex
          : specimen.isShiny,
    );
  }

  // ---- ShinyHuntRepository ----

  @override
  Future<List<ShinyHunt>> fetchShinyHunts() async {
    await _delay();
    return [..._hunts.values]..sort((a, b) => a.id.compareTo(b.id));
  }

  /// Valida a forma, o save e a contagem; só um cronômetro rodando.
  @override
  Future<ShinyHunt> saveShinyHunt(ShinyHunt hunt) async {
    await _delay();
    final form = _forms[hunt.form];
    if (form == null) {
      throw const ValidationFailure({
        'form': [Problem.invalidForm()],
      });
    }
    if (hunt.id != 0 && !_hunts.containsKey(hunt.id)) {
      throw const NotFoundFailure();
    }
    if (hunt.save != null && !_saves.containsKey(hunt.save)) {
      throw const ValidationFailure({
        'save': [Problem.saveNotFound()],
      });
    }
    if (hunt.count < 0) {
      throw const ValidationFailure({
        'count': [Problem.negativeCount()],
      });
    }
    if (hunt.chain < 0 || hunt.bestChain < hunt.chain) {
      throw const ValidationFailure({
        'chain': [Problem.invalidChain()],
      });
    }
    if (hunt.running &&
        _hunts.values.any((h) => h.running && h.id != hunt.id)) {
      throw const ValidationFailure({
        'runningSince': [Problem.timerRunning()],
      });
    }
    final id = hunt.id == 0 ? _newId(_hunts.keys) : hunt.id;
    final saved = hunt.copyWith(id: id, formRef: _formRef(form));
    _hunts[id] = saved;
    return saved;
  }

  @override
  Future<void> deleteShinyHunt(int huntId) async {
    await _delay();
    if (_hunts.remove(huntId) == null) throw const NotFoundFailure();
  }

  // ---- ShinyLockRepository ----

  @override
  Future<List<ShinyLock>> fetchShinyLocks() async {
    await _delay();
    return _shinyLocks.values.toList()..sort(
      (a, b) => a.caption.toLowerCase().compareTo(b.caption.toLowerCase()),
    );
  }

  @override
  Future<ShinyLock> createShinyLock(ShinyLockDraft draft) async {
    await _delay();
    _validateShinyLock(draft);
    final id = addShinyLock(
      caption: draft.caption.trim(),
      description: _blankToNull(draft.description),
      lockType: draft.lockType,
      active: draft.active,
      formIds: [for (final form in draft.forms) form.id],
    );
    return _shinyLocks[id]!;
  }

  @override
  Future<ShinyLock> updateShinyLock(int id, ShinyLockDraft draft) async {
    await _delay();
    final current = _shinyLocks[id];
    if (current == null) throw const NotFoundFailure();
    _validateShinyLock(draft, exceptId: id);
    return _shinyLocks[id] = current.copyWith(
      caption: draft.caption.trim(),
      description: _blankToNull(draft.description),
      lockType: draft.lockType,
      active: draft.active,
      forms: _lockForms([for (final form in draft.forms) form.id]),
    );
  }

  @override
  Future<void> deleteShinyLock(int id) async {
    await _delay();
    if (_shinyLocks.remove(id) == null) throw const NotFoundFailure();
  }

  /// As validações da API: nome obrigatório e único, ao menos uma forma
  /// existente.
  void _validateShinyLock(ShinyLockDraft draft, {int? exceptId}) {
    final caption = draft.caption.trim();
    final errors = <String, List<Problem>>{
      if (caption.isEmpty)
        'caption': [const Problem.blank()]
      else if (_shinyLocks.values.any(
        (l) => l.id != exceptId && l.caption == caption,
      ))
        'caption': [const Problem.shinyLockNameTaken()],
      if (draft.forms.isEmpty)
        'forms': [const Problem.emptyList()]
      else if (draft.forms.any((f) => !_forms.containsKey(f.id)))
        'forms': [const Problem.invalidForm()],
    };
    if (errors.isNotEmpty) throw ValidationFailure(errors);
  }

  String? _blankToNull(String value) =>
      value.trim().isEmpty ? null : value.trim();

  FormRef _formRef(FormDetail form) => FormRef(
    id: form.id,
    name: form.name,
    formName: form.formName,
    pokeapiId: form.pokeapiId,
    nationalNumber: form.nationalNumber,
    spriteUrl: form.spriteUrl,
    shinySpriteUrl: form.shinySpriteUrl,
  );

  String? _ballSprite(String? ball) => ball == null
      ? null
      : catalog?.itemSprite(ball) ?? '$_spriteBase/items/$ball.png';

  /// Marca de origem do jogo: a do catálogo, ou a tabela do seed.
  String? _originMarkOf(String? version) => catalog != null
      ? catalog!.originMarkOf(version)
      : _originMarkByVersionGroup[versionGroups[version]];
}

/// Gêneros possíveis para a forma (mesma regra do backend,
/// `home.services.allowed_genders`).
Set<String> allowedGenders(FormDetail form, Map<int, int> genderRates) {
  if (form.name.endsWith('-female')) return {'female'};
  if (form.name.endsWith('-male')) return {'male'};
  return switch (genderRates[form.id] ?? 4) {
    -1 => {'genderless'},
    0 => {'male'},
    8 => {'female'},
    _ => {'male', 'female'},
  };
}

/// Marca de origem por grupo de versão (espelho de `home/origin_marks.py`).
const _originMarkByVersionGroup = {
  'red-green-japan': 'game-boy',
  'blue-japan': 'game-boy',
  'red-blue': 'game-boy',
  'yellow': 'game-boy',
  'gold-silver': 'game-boy',
  'crystal': 'game-boy',
  'firered-leafgreen': 'gba',
  'x-y': 'kalos',
  'omega-ruby-alpha-sapphire': 'kalos',
  'sun-moon': 'alola',
  'ultra-sun-ultra-moon': 'alola',
  'lets-go-pikachu-lets-go-eevee': 'lets-go',
  'sword-shield': 'galar',
  'the-isle-of-armor': 'galar',
  'the-crown-tundra': 'galar',
  'brilliant-diamond-shining-pearl': 'bdsp',
  'legends-arceus': 'hisui',
  'scarlet-violet': 'paldea',
  'the-teal-mask': 'paldea',
  'the-indigo-disk': 'paldea',
  'legends-za': 'lumiose',
  'mega-dimension': 'lumiose',
};

extension on Specimen {
  /// Com o jogo de origem [version] e a marca calculada como no backend:
  /// GO tem prioridade; senão, a marca do grupo da versão; senão nenhuma.
  Specimen withOrigin(String? Function(String?) markOf, String? version) =>
      copyWith(
        originVersion: version,
        originMark: isFromGo ? 'go' : markOf(version),
      );
}
