import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';

import '../helpers/helpers.dart';

Matcher _validation(String field) => throwsA(
  isA<ValidationFailure>().having((f) => f.errorFor(field), field, isNotNull),
);

void main() {
  late FakeBackend backend;

  setUp(() => backend = FakeBackend.seeded());

  test('provider padrão é semeado', () {
    expect(
      createContainer().read(fakeBackendProvider).latency,
      isNot(Duration.zero),
    );
  });

  test('latência configurada é respeitada', () async {
    final slow = FakeBackend(latency: const Duration(milliseconds: 1));
    expect(await slow.fetchDexes(), isEmpty);
  });

  test('login', () async {
    expect(
      await backend.login(username: 'ash', password: 'x'),
      'fake-token-ash',
    );
    expect(
      backend.login(username: '', password: ''),
      _validation(ValidationFailure.nonFieldKey),
    );
  });

  test('dexes, boxes e slots com contagens', () async {
    final dexes = await backend.fetchDexes();
    expect(dexes.map((d) => d.name), ['Shiny Living Dex', 'Living Dex']);
    final shiny = await backend.fetchDex(1);
    expect(shiny.total, 58);
    expect(shiny.registered, 39);
    expect(backend.fetchDex(99), throwsA(isA<NotFoundFailure>()));

    final boxes = await backend.fetchBoxes(1);
    expect(boxes.map((b) => b.name), ['HOME 1', 'HOME 2']);
    expect(boxes[1].total, 28);

    // Os 2 slots livres do fim da HOME 2 não pertencem ao dex.
    final slots = await backend.fetchSlots(dexId: 1, boxId: 2);
    expect(slots, hasLength(28));
    expect(slots.any((s) => s.isFree), false);
    expect(slots.first.isShinyDisplay, true);
  });

  group('deposit', () {
    test('regras de validação', () async {
      // Slot 3 → forma 3 (faltante); slot 59 → livre.
      expect(
        backend.deposit(slotId: 999, specimenId: 1),
        throwsA(isA<NotFoundFailure>()),
      );
      expect(
        backend.deposit(slotId: 59, specimenId: 1),
        _validation(ValidationFailure.nonFieldKey),
      );
      expect(
        backend.deposit(slotId: 3, specimenId: 999),
        _validation('specimen_id'),
      );
      // Specimen 1 é da forma 1.
      expect(
        backend.deposit(slotId: 3, specimenId: 1),
        _validation('specimen_id'),
      );
    });

    test('specimen já depositado em outro slot', () async {
      // Slot 61 (dex normal, forma 1) tenta usar o specimen do slot 1.
      final slot1 = (await backend.fetchSlots(dexId: 1, boxId: 1)).first;
      expect(
        backend.deposit(slotId: 61, specimenId: slot1.specimen!.id),
        _validation('specimen_id'),
      );
      // Redepositar no mesmo slot é permitido.
      final same = await backend.deposit(
        slotId: 1,
        specimenId: slot1.specimen!.id,
      );
      expect(same.isRegistered, true);
    });

    test('depositar e trocar', () async {
      // Forma 3 só tem o "Saur" (não shiny) disponível.
      final saur = (await backend.fetchAvailable(3)).single;
      expect(saur.nickname, 'Saur');
      final deposited = await backend.deposit(slotId: 3, specimenId: saur.id);
      expect(deposited.isRegistered, true);
      expect(deposited.isShinyDisplay, false);

      // Troca: o anterior volta a ficar disponível.
      final other = await backend.create(const SpecimenDraft(form: 3));
      await backend.deposit(slotId: 3, specimenId: other.id);
      expect((await backend.fetchAvailable(3)).single.id, saur.id);
    });
  });

  group('editar e libertar', () {
    test('fetchSpecimen informa o slot', () async {
      // Specimen 1 está no slot 1 (forma 1).
      expect((await backend.fetchSpecimen(1)).slot, 1);
      expect(backend.fetchSpecimen(999), throwsA(isA<NotFoundFailure>()));
    });

    test('update edita, mas não troca a forma', () async {
      final specimen = await backend.fetchSpecimen(1);
      final draft = SpecimenDraft.fromSpecimen(specimen);
      final updated = await backend.update(
        1,
        draft.copyWith(nickname: 'Bulba', pokeball: 'beast-ball'),
      );
      expect(updated.nickname, 'Bulba');
      expect(updated.pokeballSpriteUrl, contains('beast-ball'));
      expect(updated.slot, 1);
      final slot = (await backend.fetchSlots(dexId: 1, boxId: 1)).first;
      expect(slot.specimen!.nickname, 'Bulba');

      expect(backend.update(1, draft.copyWith(form: 2)), _validation('form'));
      expect(
        backend.update(1, draft.copyWith(ability: 'x')),
        _validation('ability'),
      );
      expect(backend.update(999, draft), throwsA(isA<NotFoundFailure>()));
    });

    test('release apaga o specimen e o slot fica faltante', () async {
      await backend.release(1);
      final slot = (await backend.fetchSlots(dexId: 1, boxId: 1)).first;
      expect(slot.isMissing, true);
      expect(slot.isShinyDisplay, true);
      expect(backend.fetchSpecimen(1), throwsA(isA<NotFoundFailure>()));
      expect(backend.release(1), throwsA(isA<NotFoundFailure>()));
      // Specimen disponível (fora de slot) também pode ser libertado.
      final saur = (await backend.fetchAvailable(3)).single;
      await backend.release(saur.id);
      expect(await backend.fetchAvailable(3), isEmpty);
    });
  });

  test('create valida forma e ability', () async {
    expect(backend.create(const SpecimenDraft(form: 999)), _validation('form'));
    expect(
      backend.create(const SpecimenDraft(form: 1, ability: 'x')),
      _validation('ability'),
    );
    final created = await backend.create(
      const SpecimenDraft(form: 1, ability: 'run-away', pokeball: 'beast-ball'),
    );
    expect(created.pokeballSpriteUrl, contains('beast-ball'));
    expect(created.formRef!.id, 1);
    expect(
      (await backend.create(const SpecimenDraft(form: 1, ability: ''))).ability,
      '',
    );
  });

  test('form, opções e treinadores', () async {
    expect((await backend.fetchForm(1)).name, 'bulbasaur');
    expect(backend.fetchForm(999), throwsA(isA<NotFoundFailure>()));
    expect((await backend.fetchOptions()).pokeball, isNotEmpty);
    expect(await backend.fetchTrainers(), hasLength(2));
  });
}
