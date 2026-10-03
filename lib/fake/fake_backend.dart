import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/network/paginated.dart';
import 'package:ishinydex/features/auth/data/auth_repository.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/domain/personal_dex_repository.dart';
import 'package:ishinydex/features/shiny_locks/domain/models.dart';
import 'package:ishinydex/features/shiny_locks/domain/shiny_lock_repository.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/domain/specimen_repository.dart';

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

const _reservedSlotMessage =
    'este slot está reservado para um espécime que está fora do HOME; '
    'traga-o de volta ou retire-o antes.';

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

/// Backend em memória que segue as regras da API real.
class FakeBackend
    implements
        AuthRepository,
        PersonalDexRepository,
        SpecimenRepository,
        ShinyLockRepository {
  FakeBackend({this.latency = Duration.zero});

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
      ..addTrainer(name: 'Ash', trainerId: '123456', version: 'scarlet')
      ..addTrainer(name: 'Ash', trainerId: '654321')
      // Outras origens, para a demonstração mostrar várias marcas.
      ..addTrainer(name: 'Rei', trainerId: '111111', version: 'legends-arceus')
      ..addTrainer(name: 'Ash', trainerId: '222222', version: 'legends-za');
    final shinyDex = backend.addDex(name: 'Shiny Living Dex', isShinyDex: true);
    final livingDex = backend.addDex(name: 'Living Dex');
    final forms = [for (var id = 1; id <= _speciesNames.length; id++) id];
    backend
      ..addBox(dexId: shinyDex, name: 'HOME 1', formIds: forms.sublist(0, 30))
      ..addBox(dexId: shinyDex, name: 'HOME 2', formIds: forms.sublist(30))
      ..addBox(dexId: livingDex, name: 'HOME 3', formIds: forms.sublist(0, 30));
    for (final slot in backend._slots.values) {
      final formId = slot.formId;
      if (formId == null) continue;
      final shiny = slot.dexId == shinyDex;
      if (formId % 3 == 0) {
        // Faltante: deixa um specimen disponível em alguns casos.
        if (shiny && formId.isEven) {
          backend.addSpecimen(formId: formId, isShiny: true);
        }
        continue;
      }
      final specimen = backend.addSpecimen(
        formId: formId,
        isShiny: shiny,
        isAlpha: formId % 5 == 1,
        isFromGo: formId % 7 == 0,
        gender: _seedGender(backend._forms[formId]!, backend._genderRates),
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
    backend.addSpecimen(formId: 3, nickname: 'Saur');
    // Saves: o Scarlet (com um Pokémon do Living Dex fora do HOME) e o Z-A.
    final scarlet = backend.addSave(trainerId: 1, label: 'Switch');
    backend.addSave(trainerId: 4);
    final away = backend._slots.values.firstWhere(
      (s) => s.dexId == livingDex && s.formId == 2,
    );
    backend
      ..moveTo(away.specimenId!, scarlet, since: DateTime(2026, 3, 12))
      // Um shiny lock de exemplo (só por distribuição), para a tela de
      // cadastro e o aviso nas caçadas.
      ..addShinyLock(
        caption: 'Pikachu de evento',
        lockType: ShinyLockType.distroOnly,
        formIds: const [25],
      );
    // Boxes livres: dá para criar um dex novo na demonstração.
    for (var i = 4; i <= 6; i++) {
      backend.addFreeBox('HOME $i');
    }
    return backend;
  }

  final Duration latency;

  final _forms = <int, FormDetail>{};
  final _dexes = <int, PersonalDex>{};
  final _boxes = <int, BoxRef>{};
  final _slots = <int, _SlotRecord>{};
  final _specimens = <int, Specimen>{};
  final _trainers = <int, Trainer>{};
  final _saves = <int, Save>{};

  /// Shiny locks cadastrados. Como na API, são eles que dão o
  /// `isShinylocked`/`isDistroOnly` das formas e o `shiny_lock` das caçadas.
  final _shinyLocks = <int, ShinyLock>{};
  var _nextShinyLockId = 1;

  /// Forma → forma da qual evolui (no backend, `evolves_from_species`).
  final _evolvesFrom = <int, int>{};

  /// `gender_rate` da espécie de cada forma (a API não expõe; a regra do
  /// lote usa).
  final _genderRates = <int, int>{};

  /// Categoria da espécie de cada forma (no backend, vem dos campos da
  /// espécie e da habilidade Beast Boost).
  final _categories = <int, SpeciesCategory>{};

  int _nextSlotId = 1;
  int _nextSpecimenId = 1;

  /// Grupo de versão de cada versão (a marca de origem depende dele).
  static final Map<String, String> versionGroups = {
    for (final v in gameVersions) v.name: v.versionGroup,
  };

  List<GameVersion> get versions => gameVersions;

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

  final options = const SpecimenOptions(
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
      Choice(value: 'adamant', label: 'Adamant'),
      Choice(value: 'modest', label: 'Modest'),
      Choice(value: 'timid', label: 'Timid'),
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
    final id = _nextShinyLockId++;
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
    final id = _trainers.length + 1;
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
    final id = _saves.length + 1;
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
    final id = _dexes.length + 1;
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
    final id = _boxes.length + 1;
    final box = BoxRef(id: id, name: name, position: id);
    _boxes[id] = box;
    for (var index = 0; index < 30; index++) {
      final slotId = _nextSlotId++;
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
  }) {
    final id = _nextSpecimenId++;
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
    ).withOrigin(_otVersion(ot));
    return id;
  }

  // ---- AuthRepository ----

  @override
  Future<String> login({
    required String username,
    required String password,
  }) async {
    await _delay();
    if (username.isEmpty || password.isEmpty) {
      throw ValidationFailure({
        ValidationFailure.nonFieldKey: [
          'Impossível fazer login com as credenciais fornecidas.',
        ],
      });
    }
    return 'fake-token-$username';
  }

  // ---- PersonalDexRepository ----

  @override
  Future<List<PersonalDex>> fetchDexes() async {
    await _delay();
    return [for (final id in _dexes.keys) _dexWithCounts(id)];
  }

  /// No fake, o "conjunto padrão" são todas as formas cadastradas.
  List<FormDetail> get _defaultForms =>
      _forms.values.toList()..sort((a, b) => a.id.compareTo(b.id));

  /// Limite de boxes (o do HOME); os testes podem baixar.
  int maxBoxes = homeMaxBoxes;

  /// Mesmas regras do backend (`home/services.py`): simula o esquema e acha a
  /// 1ª sequência de boxes livres que comporte todas as formas; se nenhuma
  /// comportar, completa a sequência livre do fim com boxes novas, até
  /// [maxBoxes].
  ({int needed, int largest, List<BoxRef>? boxes, int toCreate}) _planDex(
    bool forceNewBox,
  ) {
    final forms = _defaultForms;
    var needed = 0;
    for (var index = 0; index < forms.length;) {
      needed++;
      for (
        var position = 0;
        position < 30 && index < forms.length;
        position++
      ) {
        if (forceNewBox && position > 0 && _startsGeneration(forms[index])) {
          break;
        }
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

  static bool _startsGeneration(FormDetail form) => const [
    'chikorita', 'treecko', 'turtwig', 'victini', //
    'chespin', 'rowlet', 'grookey', 'sprigatito',
  ].contains(form.name);

  @override
  Future<DexPreview> previewNewDex({required bool forceNewBox}) async {
    await _delay();
    final plan = _planDex(forceNewBox);
    return DexPreview(
      forms: _defaultForms.length,
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
  }) async {
    await _delay();
    if (name.trim().isEmpty) {
      throw ValidationFailure({
        'name': ['Este campo não pode ser em branco.'],
      });
    }
    if (_dexes.values.any((d) => d.name == name)) {
      throw ValidationFailure({
        'name': ['personal dex com este name já existe.'],
      });
    }
    final plan = _planDex(forceNewBox);
    final boxes = plan.boxes;
    if (boxes == null) {
      final message =
          'Não há boxes livres seguidas suficientes para este PersonalDex: '
          'ele precisa de ${plan.needed}, a maior sequência livre tem '
          '${plan.largest}, e criar as boxes que faltam passaria das '
          '$maxBoxes boxes do Pokémon HOME.';
      throw ValidationFailure({
        ValidationFailure.nonFieldKey: [message],
      });
    }
    final id = addDex(name: name, isShinyDex: isShinyDex);
    _dexes[id] = _dexes[id]!.copyWith(forceNewBox: forceNewBox);
    final forms = _defaultForms;
    final newBoxes = [
      for (var i = 0; i < plan.toCreate; i++)
        _boxes[addFreeBox(_nextBoxName())]!,
    ];
    var index = 0;
    for (final box in [...boxes, ...newBoxes]) {
      final slots = _slots.values.where((s) => s.box.id == box.id).toList();
      for (final (position, slot) in slots.indexed) {
        if (index >= forms.length) break;
        if (forceNewBox && position > 0 && _startsGeneration(forms[index])) {
          break;
        }
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
      throw ValidationFailure({
        'name': ['Este campo não pode ser em branco.'],
      });
    }
    if (_dexes.values.any((d) => d.id != dexId && d.name == name)) {
      throw ValidationFailure({
        'name': ['personal dex com este name já existe.'],
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

  @override
  Future<PersonalDex> fetchDex(int dexId) async {
    await _delay();
    if (!_dexes.containsKey(dexId)) throw const NotFoundFailure();
    return _dexWithCounts(dexId);
  }

  /// Como a API: slots com forma agrupados pela geração, na ordem da
  /// primeira box. No fake, a geração sai do número da Pokédex (pokeapiId).
  @override
  Future<List<GenerationProgress>> fetchGenerations(int dexId) async {
    await _delay();
    final byGeneration = <String, List<_SlotRecord>>{};
    for (final slot in _slots.values) {
      final formId = slot.formId;
      if (slot.dexId != dexId || formId == null) continue;
      final generation = _generationOf(_forms[formId]!.pokeapiId);
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
    return [
      for (final slot in _slots.values)
        if (slot.dexId == dexId &&
            slot.formId != null &&
            matches(_forms[slot.formId]!))
          _toSlot(slot),
    ].take(30).toList();
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
      throw ValidationFailure({
        ValidationFailure.nonFieldKey: ['Este slot não possui forma definida.'],
      });
    }
    final specimen = _specimens[specimenId];
    if (specimen == null) {
      throw ValidationFailure({
        'specimen_id': ['Specimen inexistente.'],
      });
    }
    if (specimen.form != slot.formId) {
      throw ValidationFailure({
        'specimen_id': ["specimen form doesn't match with slot form."],
      });
    }
    // Slot reservado: o espécime dele está num save e volta para cá.
    final current = _specimens[slot.specimenId];
    if (current != null &&
        current.id != specimenId &&
        current.location != null) {
      throw ValidationFailure({
        ValidationFailure.nonFieldKey: [_reservedSlotMessage],
      });
    }
    final holder = _slotHolding(specimenId);
    if (holder != null && holder.id != slotId) {
      throw ValidationFailure({
        'specimen_id': ['Este specimen já está depositado em outro slot.'],
      });
    }
    slot.specimenId = specimenId;
    return _toSlot(slot);
  }

  /// Como a API: só shiny dex (senão 400); motivos somados (OU), escopo
  /// combinado (E), tipos "qualquer um", shiny impossível fora por padrão;
  /// cada item traz todos os seus motivos. Página fora do intervalo → 404.
  @override
  Future<Paginated<Hunt>> fetchHunts(
    int dexId,
    HuntQuery query, {
    required int page,
    required int pageSize,
  }) async {
    await _delay();
    final dex = _dexes[dexId];
    if (dex == null) throw const NotFoundFailure();
    if (!dex.isShinyDex) {
      throw ValidationFailure({
        ValidationFailure.nonFieldKey: [
          'A lista de caçadas só existe para shiny dex.',
        ],
      });
    }
    final search = query.search.trim().toLowerCase();
    final number = int.tryParse(search);
    final hunts = <Hunt>[];
    for (final slot in _slots.values) {
      final formId = slot.formId;
      if (slot.dexId != dexId || formId == null) continue;
      final form = _forms[formId]!;
      final lock = _lockOf(formId);
      final reasons = _huntReasons(slot, query.acceptedBalls);
      final category = _categories[formId] ?? SpeciesCategory.regular;
      final matches =
          reasons.any(query.reasons.contains) &&
          (query.includeLocked || lock != ShinyLockType.unobtainable) &&
          (query.generations.isEmpty ||
              query.generations.contains(_generationOf(form.pokeapiId))) &&
          (query.types.isEmpty ||
              form.types.any((t) => query.types.contains(t.type))) &&
          (query.categories.isEmpty || query.categories.contains(category)) &&
          (search.isEmpty ||
              (number == null
                  ? form.name.contains(slugSearch(search))
                  : _hasNumber(form, number)));
      if (matches) {
        hunts.add(Hunt(slot: _toSlot(slot), reasons: reasons, shinyLock: lock));
      }
    }
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

  /// Motivos de caçada do slot; `pokeball` só com bolas aceitas, e bola não
  /// informada não conta.
  List<HuntReason> _huntReasons(_SlotRecord slot, List<String> acceptedBalls) {
    final id = slot.specimenId;
    final specimen = id == null ? null : _specimens[id];
    if (specimen == null || !specimen.isShiny) return [HuntReason.noShiny];
    final ball = specimen.pokeball;
    return [
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
      throw ValidationFailure({
        'form': ['Forma inválida.'],
      });
    }
    _validateAbility(form, draft.ability);
    final id = _nextSpecimenId++;
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
    ).withOrigin(_otVersion(draft.ot));
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
      throw ValidationFailure({
        ValidationFailure.nonFieldKey: ['Nada para alterar.'],
      });
    }
    final missing = unique.where((id) => !_specimens.containsKey(id));
    if (missing.isNotEmpty) {
      throw ValidationFailure({
        'ids': ['espécimes não encontrados: ${missing.join(', ')}'],
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
          message:
              'este gênero não é possível para ${conflicts.length} espécime(s).',
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
      isAlpha: pick(c.isAlpha, s.isAlpha) ?? s.isAlpha,
      isFromGo: pick(c.isFromGo, s.isFromGo) ?? s.isFromGo,
    );
    return changed.withOrigin(switch (c.ot) {
      Keep() => s.originVersion,
      SetTo(:final value) => _otVersion(value),
    });
  }

  @override
  Future<List<FormRef>> searchForms(String search) async {
    await _delay();
    final text = slugSearch(search.trim().toLowerCase());
    return [
      for (final form in _forms.values)
        if (form.name.contains(text)) _formRef(form),
    ].take(30).toList();
  }

  @override
  Future<Specimen> update(int specimenId, SpecimenDraft draft) async {
    await _delay();
    final specimen = _specimens[specimenId];
    if (specimen == null) throw const NotFoundFailure();
    if (draft.form != specimen.form) {
      throw ValidationFailure({
        'form': ['a forma de um espécime não pode ser alterada.'],
      });
    }
    _validateAbility(_forms[specimen.form]!, draft.ability);
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
    );
    // O jogo de origem só muda quando o OT muda (como no backend).
    final updated = draft.ot == specimen.ot
        ? edited.withOrigin(specimen.originVersion)
        : edited.withOrigin(_otVersion(draft.ot));
    _specimens[specimenId] = updated;
    return updated;
  }

  /// Como no backend (`Slot.specimen` com `SET_NULL`): o slot fica faltante.
  @override
  Future<void> release(int specimenId) async {
    await _delay();
    if (_specimens.remove(specimenId) == null) throw const NotFoundFailure();
    _slotHolding(specimenId)?.specimenId = null;
  }

  /// Como `POST /specimens/bulk-release/`: tudo ou nada.
  @override
  Future<int> bulkRelease(List<int> ids) async {
    await _delay();
    final unique = ids.toSet();
    if (unique.isEmpty) {
      throw ValidationFailure({
        'ids': ['Esta lista não pode estar vazia.'],
      });
    }
    final missing = unique.where((id) => !_specimens.containsKey(id));
    if (missing.isNotEmpty) {
      throw ValidationFailure({
        'ids': ['espécimes não encontrados: ${missing.join(', ')}'],
      });
    }
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
    return form.copyWith(
      isShinylocked: lock == ShinyLockType.unobtainable,
      isDistroOnly: lock == ShinyLockType.distroOnly,
    );
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

  /// Como `POST /saves/`: só OT de jogo que recebe do HOME, e uma vez.
  @override
  Future<Save> createSave({required int trainerId, String label = ''}) async {
    await _delay();
    final trainer = _trainers[trainerId];
    String? error;
    if (trainer == null) {
      error = 'Treinador inexistente.';
    } else if (!Save.transferVersions.contains(trainer.version)) {
      error =
          'só treinadores de jogos que recebem Pokémon do HOME podem ser '
          'saves.';
    } else if (_saves.values.any((s) => s.trainer.id == trainerId)) {
      error = 'este treinador já é um save.';
    }
    if (error != null) {
      throw ValidationFailure({
        'trainer': [error],
      });
    }
    return _saves[addSave(trainerId: trainerId, label: label)]!;
  }

  @override
  Future<Save> updateSave(int saveId, {required String label}) async {
    await _delay();
    final save = _saves[saveId];
    if (save == null) throw const NotFoundFailure();
    final updated = save.copyWith(label: label);
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
      throw ValidationFailure(
        const {},
        detail:
            'este save ainda tem espécimes; traga-os de volta ao HOME antes.',
      );
    }
    _saves.remove(saveId);
  }

  /// Como `POST /specimens/transfer/`: tudo ou nada; quem já está no
  /// destino não muda (nem a data).
  @override
  Future<int> transfer(List<int> ids, {required int? saveId}) async {
    await _delay();
    final unique = ids.toSet();
    final missing = unique.where((id) => !_specimens.containsKey(id));
    if (unique.isEmpty || missing.isNotEmpty) {
      throw ValidationFailure({
        'ids': ['espécimes não encontrados: ${missing.join(', ')}'],
      });
    }
    if (saveId != null && !_saves.containsKey(saveId)) {
      throw ValidationFailure({
        'save': ['Save inexistente.'],
      });
    }
    final moving = unique.where((id) => _specimens[id]!.location?.id != saveId);
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
      throw ValidationFailure({
        'form': ['esta forma não é uma evolução do espécime.'],
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
    const blank = ['Este campo não pode ser em branco.'];
    final errors = <String, List<String>>{
      if (name.trim().isEmpty) 'name': blank,
      if (trainerId.trim().isEmpty) 'trainer_id': blank,
      if (version != null && !versions.any((v) => v.name == version))
        'version': ['Objeto com name=$version não existe.'],
    };
    if (errors.isNotEmpty) throw ValidationFailure(errors);
    if (_trainers.values.any(
      (t) => t.name == name && t.trainerId == trainerId,
    )) {
      throw ValidationFailure({
        ValidationFailure.nonFieldKey: [
          'Os campos name, trainer_id devem criar um set único.',
        ],
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
        (!query.fromGoOnly || s.isFromGo) &&
        (!query.hasPokeballFilter ||
            query.pokeballs.contains(s.pokeball) ||
            (query.withoutPokeball && s.pokeball == null)) &&
        (!query.hasOtFilter ||
            query.ots.contains(s.ot) ||
            (query.withoutOt && s.ot == null)) &&
        query.types.every(formTypes.contains) &&
        inList(query.generations, _generationOf(form.pokeapiId)) &&
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
        (query.capturedAfter == null ||
            (captured != null && !captured.isBefore(query.capturedAfter!))) &&
        (query.capturedBefore == null ||
            (captured != null && !captured.isAfter(query.capturedBefore!)));
  }

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

  static String _generationOf(int dexNumber) {
    for (final (i, end) in _generationEnds.indexed) {
      if (dexNumber <= end) return 'generation-${_romans[i]}';
    }
    return 'generation-ix';
  }

  void _validateAbility(FormDetail form, String? ability) {
    if (ability != null &&
        ability.isNotEmpty &&
        !form.abilities.any((a) => a.ability == ability)) {
      throw ValidationFailure({
        'ability': ['Habilidade inválida para esta forma.'],
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
            ),
      isShinyDisplay: specimen == null
          ? formId != null && isShinyDex
          : specimen.isShiny,
    );
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
    final errors = <String, List<String>>{
      if (caption.isEmpty)
        'caption': ['Este campo não pode ser em branco.']
      else if (_shinyLocks.values.any(
        (l) => l.id != exceptId && l.caption == caption,
      ))
        'caption': ['Já existe um shiny lock com este nome.'],
      if (draft.forms.isEmpty)
        'forms': ['Esta lista não pode estar vazia.']
      else if (draft.forms.any((f) => !_forms.containsKey(f.id)))
        'forms': ['Forma inválida.'],
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

  String? _ballSprite(String? ball) =>
      ball == null ? null : '$_spriteBase/items/$ball.png';
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
  Specimen withOrigin(String? version) {
    final group = FakeBackend.versionGroups[version];
    return copyWith(
      originVersion: version,
      originMark: isFromGo ? 'go' : _originMarkByVersionGroup[group],
    );
  }
}
