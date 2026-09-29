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

  group('inventário', () {
    Future<List<Specimen>> all(SpecimenQuery query) async =>
        (await backend.fetchSpecimens(query, page: 1, pageSize: 500)).results;

    test('filtros, ordem e slot informado', () async {
      final everything = await all(emptySpecimenQuery);
      // Ordem da API: forma, depois id.
      expect(everything.first.form, 1);
      expect(everything.first.slot, 1);
      final deposited = await all(
        emptySpecimenQuery.copyWith(
          search: '',
          status: SpecimenStatus.deposited,
          shinyOnly: false,
        ),
      );
      final available = await all(
        emptySpecimenQuery.copyWith(
          search: '',
          status: SpecimenStatus.available,
          shinyOnly: false,
        ),
      );
      expect(deposited.length + available.length, everything.length);
      expect(deposited.every((s) => s.slot != null), true);
      expect(available.every((s) => s.slot == null), true);
      final shiny = await all(
        emptySpecimenQuery.copyWith(
          search: '',
          status: SpecimenStatus.all,
          shinyOnly: true,
        ),
      );
      expect(shiny.every((s) => s.isShiny), true);
      // Busca em apelido ou nome da forma, sem diferenciar maiúsculas.
      final saur = await all(
        emptySpecimenQuery.copyWith(
          search: ' SAUR ',
          status: SpecimenStatus.all,
          shinyOnly: false,
        ),
      );
      expect(saur.map((s) => s.formName).toSet(), {
        'bulbasaur',
        'ivysaur',
        'venusaur',
      });
      expect(saur.any((s) => s.nickname == 'Saur'), true);
    });

    test('filtros de alfa e GO', () async {
      final alpha = await all(emptySpecimenQuery.copyWith(alphaOnly: true));
      final go = await all(emptySpecimenQuery.copyWith(fromGoOnly: true));
      expect(alpha, isNotEmpty);
      expect(alpha.every((s) => s.isAlpha), true);
      expect(go, isNotEmpty);
      expect(go.every((s) => s.isFromGo), true);
    });

    test('filtros avançados como na API', () async {
      Future<Set<int>> ids(SpecimenQuery query) async => {
        for (final s in await all(query)) s.id,
      };
      final jolly = await backend.create(
        SpecimenDraft(
          form: 7,
          gender: 'female',
          nature: 'jolly',
          language: 'ja',
          ability: 'keen-eye',
          capturedAt: DateTime(2025, 6, 15),
        ),
      );
      final everything = await all(emptySpecimenQuery);

      // Pokébola: OU entre as escolhidas; "sem" soma os sem pokébola.
      final dream = await all(const SpecimenQuery(pokeballs: ['dream-ball']));
      expect(dream, isNotEmpty);
      expect(dream.every((s) => s.pokeball == 'dream-ball'), true);
      final noBall = await all(const SpecimenQuery(withoutPokeball: true));
      expect(noBall.every((s) => s.pokeball == null), true);
      expect(
        await ids(
          const SpecimenQuery(pokeballs: ['dream-ball'], withoutPokeball: true),
        ),
        {...dream.map((s) => s.id), ...noBall.map((s) => s.id)},
      );

      // OT: seed com o treinador 1 nas formas múltiplas de 4.
      final byAsh = await all(const SpecimenQuery(ots: [1]));
      expect(byAsh, isNotEmpty);
      expect(byAsh.every((s) => s.ot == 1), true);
      final noOt = await all(const SpecimenQuery(withoutOt: true));
      expect(byAsh.length + noOt.length, everything.length);

      // Tipo: com dois, a forma precisa ter os dois (charizard: fogo/voador).
      final flying = await all(const SpecimenQuery(types: ['flying']));
      expect(
        flying.map((s) => s.formName).toSet(),
        containsAll(['charizard', 'pidgey']),
      );
      final fireFlying = await all(
        const SpecimenQuery(types: ['fire', 'flying']),
      );
      expect(fireFlying.map((s) => s.formName).toSet(), {'charizard'});

      expect(
        (await all(const SpecimenQuery(generations: ['generation-i']))).length,
        everything.length,
      );
      expect(
        await all(const SpecimenQuery(generations: ['generation-ii'])),
        isEmpty,
      );
      expect(await ids(const SpecimenQuery(genders: ['female'])), {jolly.id});
      expect(await ids(const SpecimenQuery(natures: ['jolly'])), {jolly.id});
      expect(await ids(const SpecimenQuery(languages: ['ja'])), {jolly.id});
      expect(await ids(const SpecimenQuery(ability: ' KEEN ')), {jolly.id});
    });

    test('intervalo de captura e ordenação', () async {
      // Seed: formas pares capturadas em 2026-01-<forma>; ímpares sem data.
      final january = await all(
        SpecimenQuery(
          capturedAfter: DateTime(2026, 1, 10),
          capturedBefore: DateTime(2026, 1, 14),
        ),
      );
      // 12 é múltiplo de 3: no seed, faltante (sem specimen com data).
      expect(january.map((s) => s.capturedAt!.day).toSet(), {10, 14});
      expect(
        (await all(SpecimenQuery(capturedBefore: DateTime(2026, 1, 2))))
            .map((s) => s.form)
            .toSet(),
        {2},
      );

      final everything = await all(emptySpecimenQuery);
      final dated = everything.where((s) => s.capturedAt != null).length;
      final recent = await all(
        const SpecimenQuery(ordering: SpecimenOrdering.capturedDesc),
      );
      final oldest = await all(
        const SpecimenQuery(ordering: SpecimenOrdering.capturedAsc),
      );
      final created = await all(
        const SpecimenQuery(ordering: SpecimenOrdering.createdDesc),
      );
      final dexOrder = await all(
        emptySpecimenQuery.copyWith(ordering: SpecimenOrdering.dex),
      );
      expect(dexOrder.map((s) => s.id), everything.map((s) => s.id));
      // Sem data vão para o fim nas duas direções.
      for (final list in [recent, oldest]) {
        expect(list.take(dated).every((s) => s.capturedAt != null), true);
        expect(list.skip(dated).every((s) => s.capturedAt == null), true);
      }
      expect(
        recent.first.capturedAt!.isAfter(recent[dated - 1].capturedAt!),
        true,
      );
      expect(
        oldest.first.capturedAt!.isBefore(oldest[dated - 1].capturedAt!),
        true,
      );
      // Mesma data (ou sem data): desempata pelo id, na direção da ordem.
      final undatedRecent = [for (final s in recent.skip(dated)) s.id];
      final undatedOldest = [for (final s in oldest.skip(dated)) s.id];
      expect(undatedRecent, [...undatedOldest.reversed]);
      expect(created.map((s) => s.id), [
        ...everything.map((s) => s.id).toList()..sort((a, b) => b - a),
      ]);
    });

    test('mesma data de captura: desempate pelo id', () async {
      final a = await backend.create(
        SpecimenDraft(form: 1, capturedAt: DateTime(2030)),
      );
      final b = await backend.create(
        SpecimenDraft(form: 2, capturedAt: DateTime(2030)),
      );
      final recent = await all(
        const SpecimenQuery(ordering: SpecimenOrdering.capturedDesc),
      );
      final oldest = await all(
        const SpecimenQuery(ordering: SpecimenOrdering.capturedAsc),
      );
      expect(recent.take(2).map((s) => s.id), [b.id, a.id]);
      expect(
        oldest.reversed
            .where((s) => s.capturedAt != null)
            .take(2)
            .map((s) => s.id),
        [b.id, a.id],
      );
    });

    test('paginação e página inválida', () async {
      final first = await backend.fetchSpecimens(
        emptySpecimenQuery,
        page: 1,
        pageSize: 20,
      );
      expect(first.results, hasLength(20));
      expect(first.hasNext, true);
      final pages = (first.count / 20).ceil();
      final last = await backend.fetchSpecimens(
        emptySpecimenQuery,
        page: pages,
        pageSize: 20,
      );
      expect(last.hasNext, false);
      expect(
        backend.fetchSpecimens(
          emptySpecimenQuery,
          page: pages + 1,
          pageSize: 20,
        ),
        throwsA(isA<NotFoundFailure>()),
      );
      expect(
        backend.fetchSpecimens(emptySpecimenQuery, page: 0, pageSize: 20),
        throwsA(isA<NotFoundFailure>()),
      );
      // Sem resultados, a página 1 existe (vazia).
      final none = await backend.fetchSpecimens(
        emptySpecimenQuery.copyWith(
          search: 'zzz',
          status: SpecimenStatus.all,
          shinyOnly: false,
        ),
        page: 1,
        pageSize: 20,
      );
      expect(none.count, 0);
    });

    test('searchSlots: nome ou número, só do dex e com forma', () async {
      final byName = await backend.searchSlots(dexId: 1, search: 'PIDGE');
      expect(byName.map((s) => s.form!.name), [
        'pidgey',
        'pidgeotto',
        'pidgeot',
      ]);
      expect(byName.every((s) => s.personalDex == 1), true);
      final byNumber = await backend.searchSlots(dexId: 2, search: '16');
      expect(byNumber.single.form!.name, 'pidgey');
      expect(byNumber.single.personalDex, 2);
      // Forma 40 não está no dex 2 (só 1–30).
      expect(await backend.searchSlots(dexId: 2, search: '40'), isEmpty);
    });

    test('fetchGenerations: agrupa pela geração do número', () async {
      final gens = await backend.fetchGenerations(1);
      expect(gens.single.generation, 'generation-i');
      expect(gens.single.total, 58);
      expect(gens.single.registered, 39);
      expect(gens.single.firstBox.name, 'HOME 1');

      // Um número em cada faixa, inclusive depois da última (IX).
      const numbers = [1, 152, 252, 387, 494, 650, 722, 810, 906];
      final many = FakeBackend();
      for (final n in numbers) {
        many.addForm(id: n, name: 'f$n');
      }
      final dex = many.addDex(name: 'Todas');
      many.addBox(dexId: dex, name: 'B', formIds: numbers);
      expect((await many.fetchGenerations(dex)).map((g) => g.label), [
        'Geração I',
        'Geração II',
        'Geração III',
        'Geração IV',
        'Geração V',
        'Geração VI',
        'Geração VII',
        'Geração VIII',
        'Geração IX',
      ]);
    });

    test('novo dex: simulação, criação e erros', () async {
      final preview = await backend.previewNewDex(forceNewBox: false);
      // 58 formas em 2 boxes; livres: HOME 4–6.
      expect(preview.forms, 58);
      expect(preview.boxesNeeded, 2);
      expect(preview.largestFreeRun, 3);
      expect(preview.firstBox!.name, 'HOME 4');

      final dex = await backend.createDex(
        name: 'Nova',
        isShinyDex: true,
        forceNewBox: false,
      );
      expect(dex.total, 58);
      expect(dex.registered, 0);
      expect(dex.isShinyDex, true);
      expect((await backend.fetchBoxes(dex.id)).map((b) => b.name), [
        'HOME 4',
        'HOME 5',
      ]);

      expect(
        backend.createDex(name: 'Nova', isShinyDex: false, forceNewBox: false),
        _validation('name'),
      );
      expect(
        backend.createDex(name: ' ', isShinyDex: false, forceNewBox: false),
        _validation('name'),
      );
      // Sobrou 1 box livre (HOME 6): não cabe outro.
      final full = await backend.previewNewDex(forceNewBox: false);
      expect(full.enoughSpace, false);
      expect(full.firstBox, isNull);
      expect(
        backend.createDex(name: 'Outra', isShinyDex: false, forceNewBox: false),
        _validation(ValidationFailure.nonFieldKey),
      );
    });

    test('nova box a cada geração começa a geração no 1º slot', () async {
      final gens = FakeBackend()
        ..addForm(id: 1, name: 'bulbasaur')
        ..addForm(id: 2, name: 'ivysaur')
        ..addForm(id: 152, name: 'chikorita')
        ..addFreeBox('A')
        ..addFreeBox('B');
      expect((await gens.previewNewDex(forceNewBox: false)).boxesNeeded, 1);
      expect((await gens.previewNewDex(forceNewBox: true)).boxesNeeded, 2);
      final dex = await gens.createDex(
        name: 'Por geração',
        isShinyDex: false,
        forceNewBox: true,
      );
      expect(dex.forceNewBox, true);
      final second = await gens.fetchSlots(dexId: dex.id, boxId: 2);
      expect(second.single.form!.name, 'chikorita');
      expect(second.single.row, 0);
    });

    test('searchForms e fetchSlot', () async {
      expect((await backend.searchForms('PIDGE')).map((f) => f.name), [
        'pidgey',
        'pidgeotto',
        'pidgeot',
      ]);
      expect((await backend.fetchSlot(1)).isRegistered, true);
      expect(backend.fetchSlot(999), throwsA(isA<NotFoundFailure>()));
    });
  });

  test('createTrainer segue as regras do backend e fetchVersions', () async {
    expect((await backend.fetchVersions()).first.name, 'red');
    expect(
      backend.createTrainer(name: ' ', trainerId: ''),
      throwsA(
        isA<ValidationFailure>()
            .having((f) => f.errorFor('name'), 'name', isNotNull)
            .having((f) => f.errorFor('trainer_id'), 'trainer_id', isNotNull),
      ),
    );
    expect(
      backend.createTrainer(name: 'Red', trainerId: '1', version: 'nope'),
      _validation('version'),
    );
    final red = await backend.createTrainer(
      name: 'Red',
      trainerId: '1996',
      version: 'red',
    );
    expect((await backend.fetchTrainers()).last, red);
    // Par (nome, ID) repetido.
    expect(
      backend.createTrainer(name: 'Red', trainerId: '1996'),
      _validation(ValidationFailure.nonFieldKey),
    );
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
