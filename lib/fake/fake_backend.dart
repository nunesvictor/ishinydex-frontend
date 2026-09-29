import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/network/app_failure.dart';
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

  @override
  Future<Slot> withdraw(int slotId) async {
    await _delay();
    final slot = _slots[slotId];
    if (slot == null) throw const NotFoundFailure();
    slot.specimenId = null;
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
    final ability = draft.ability;
    if (ability != null &&
        ability.isNotEmpty &&
        !form.abilities.any((a) => a.ability == ability)) {
      throw ValidationFailure({
        'ability': ['Habilidade inválida para esta forma.'],
      });
    }
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
