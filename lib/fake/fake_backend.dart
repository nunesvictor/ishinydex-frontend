import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/network/paginated.dart';
import 'package:ishinydex/features/auth/data/auth_repository.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/domain/personal_dex_repository.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/domain/specimen_repository.dart';

final fakeBackendProvider = Provider<FakeBackend>(
  (ref) => FakeBackend.seeded(latency: const Duration(milliseconds: 250)),
);

const _spriteBase =
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites';

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
  final int? dexId;
  final int? formId;
  int? specimenId;
}

/// Backend em memória que segue as regras da API real.
class FakeBackend
    implements AuthRepository, PersonalDexRepository, SpecimenRepository {
  FakeBackend({this.latency = Duration.zero});

  /// Dados de demonstração: um dex shiny (2 boxes) e um dex normal (1 box).
  factory FakeBackend.seeded({Duration latency = Duration.zero}) {
    final backend = FakeBackend(latency: latency);
    for (final (index, name) in _speciesNames.indexed) {
      backend.addForm(id: index + 1, name: name);
    }
    backend
      ..addTrainer(name: 'Ash', trainerId: '123456', version: 'scarlet')
      ..addTrainer(name: 'Ash', trainerId: '654321');
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
        pokeball: formId.isEven ? 'dream-ball' : 'poke-ball',
      );
      slot.specimenId = specimen;
    }
    backend.addSpecimen(formId: 3, nickname: 'Saur');
    return backend;
  }

  final Duration latency;

  final _forms = <int, FormDetail>{};
  final _dexes = <int, PersonalDex>{};
  final _boxes = <int, BoxRef>{};
  final _slots = <int, _SlotRecord>{};
  final _specimens = <int, Specimen>{};
  final _trainers = <int, Trainer>{};

  int _nextSlotId = 1;
  int _nextSpecimenId = 1;

  final versions = const [
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
      name: 'sword',
      versionGroup: 'sword-shield',
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

  void addForm({required int id, required String name}) {
    _forms[id] = FormDetail(
      id: id,
      name: name,
      pokeapiId: id,
      spriteUrl: '$_spriteBase/pokemon/other/home/$id.png',
      shinySpriteUrl: '$_spriteBase/pokemon/other/home/shiny/$id.png',
      types: const [FormType(slot: 1, type: 'normal')],
      abilities: const [
        FormAbility(slot: 1, ability: 'run-away'),
        FormAbility(slot: 3, ability: 'keen-eye', isHidden: true),
      ],
    );
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

  int addSpecimen({
    required int formId,
    bool isShiny = false,
    bool isAlpha = false,
    String? nickname,
    String? pokeball,
  }) {
    final id = _nextSpecimenId++;
    final form = _forms[formId]!;
    _specimens[id] = Specimen(
      id: id,
      form: formId,
      formRef: _formRef(form),
      formName: form.name,
      nickname: nickname,
      isShiny: isShiny,
      isAlpha: isAlpha,
      pokeball: pokeball,
      pokeballSpriteUrl: _ballSprite(pokeball),
    );
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

  @override
  Future<PersonalDex> fetchDex(int dexId) async {
    await _delay();
    if (!_dexes.containsKey(dexId)) throw const NotFoundFailure();
    return _dexWithCounts(dexId);
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
              .where((s) => s.formId != null && s.specimenId != null)
              .length,
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

  /// Como a API: nome da forma ou número (no fake, o número da Pokédex é o
  /// próprio `pokeapiId`); só slots com forma, na ordem das boxes.
  @override
  Future<List<Slot>> searchSlots({
    required int dexId,
    required String search,
  }) async {
    await _delay();
    final text = search.trim().toLowerCase();
    final number = int.tryParse(text);
    bool matches(FormDetail form) =>
        number == null ? form.name.contains(text) : form.pokeapiId == number;
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
    final holder = _slotHolding(specimenId);
    if (holder != null && holder.id != slotId) {
      throw ValidationFailure({
        'specimen_id': ['Este specimen já está depositado em outro slot.'],
      });
    }
    slot.specimenId = specimenId;
    return _toSlot(slot);
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
    );
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

  /// Como a API: busca em apelido ou nome da forma; ordem por forma e id;
  /// página fora do intervalo → 404.
  @override
  Future<Paginated<Specimen>> fetchSpecimens(
    SpecimenQuery query, {
    required int page,
    required int pageSize,
  }) async {
    await _delay();
    final search = query.search.trim().toLowerCase();
    final available = query.status.availableParam;
    final matches = [
      for (final s in _specimens.values)
        if ((search.isEmpty ||
                (s.nickname ?? '').toLowerCase().contains(search) ||
                (s.formName ?? '').toLowerCase().contains(search)) &&
            (available == null || (_slotHolding(s.id) == null) == available) &&
            (!query.shinyOnly || s.isShiny))
          s.copyWith(slot: _slotHolding(s.id)?.id),
    ]..sort((a, b) => a.form != b.form ? a.form - b.form : a.id - b.id);
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
  Future<List<FormRef>> searchForms(String search) async {
    await _delay();
    final text = search.trim().toLowerCase();
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
    final updated = specimen.copyWith(
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

  @override
  Future<FormDetail> fetchForm(int formId) async {
    await _delay();
    final form = _forms[formId];
    if (form == null) throw const NotFoundFailure();
    return form;
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

  Future<void> _delay() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  PersonalDex _dexWithCounts(int dexId) {
    final slots = _slots.values.where(
      (s) => s.dexId == dexId && s.formId != null,
    );
    return _dexes[dexId]!.copyWith(
      total: slots.length,
      registered: slots.where((s) => s.specimenId != null).length,
    );
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
              isShiny: specimen.isShiny,
              isAlpha: specimen.isAlpha,
              pokeball: specimen.pokeball,
              pokeballSpriteUrl: specimen.pokeballSpriteUrl,
            ),
      isShinyDisplay: specimen == null
          ? formId != null && isShinyDex
          : specimen.isShiny,
    );
  }

  FormRef _formRef(FormDetail form) => FormRef(
    id: form.id,
    name: form.name,
    formName: form.formName,
    pokeapiId: form.pokeapiId,
    spriteUrl: form.spriteUrl,
    shinySpriteUrl: form.shinySpriteUrl,
  );

  String? _ballSprite(String? ball) =>
      ball == null ? null : '$_spriteBase/items/$ball.png';
}
