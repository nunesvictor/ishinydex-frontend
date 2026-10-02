import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
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

  test('slugSearch: como o slugify do Django', () {
    expect(slugSearch('Iron  Hands'), 'iron-hands');
    expect(slugSearch('Mr. Mime'), 'mr-mime');
    expect(slugSearch("Farfetch'd"), 'farfetchd');
    expect(slugSearch('Flabébé'), 'flabebe');
    expect(slugSearch('-iron hands-'), 'iron-hands');
    // Só pontuação: o texto como veio.
    expect(slugSearch('.'), '.');
  });

  test('progresso: num shiny dex, só shiny conta; num normal, todos', () async {
    final fake = FakeBackend()
      ..addForm(id: 1, name: 'bulbasaur')
      ..addForm(id: 2, name: 'ivysaur');
    final shinyDex = fake.addDex(name: 'Shiny', isShinyDex: true);
    final living = fake.addDex(name: 'Living');
    fake
      ..addBox(dexId: shinyDex, name: 'HOME 1', formIds: [1, 2])
      ..addBox(dexId: living, name: 'HOME 2', formIds: [1, 2]);
    Future<void> put(int dexId, int index, {required bool shiny}) async {
      final box = (await fake.fetchBoxes(dexId)).single;
      final slot = (await fake.fetchSlots(dexId: dexId, boxId: box.id))[index];
      final specimen = fake.addSpecimen(formId: slot.form!.id, isShiny: shiny);
      await fake.deposit(slotId: slot.id, specimenId: specimen);
    }

    await put(shinyDex, 0, shiny: true);
    await put(shinyDex, 1, shiny: false);
    await put(living, 0, shiny: true);
    await put(living, 1, shiny: false);

    expect((await fake.fetchDex(shinyDex)).registered, 1);
    expect((await fake.fetchBoxes(shinyDex)).single.registered, 1);
    expect((await fake.fetchGenerations(shinyDex)).single.registered, 1);
    expect((await fake.fetchDex(living)).registered, 2);
    expect((await fake.fetchBoxes(living)).single.registered, 2);
    expect((await fake.fetchGenerations(living)).single.registered, 2);
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

  test('bulkRelease: tudo ou nada; depositado deixa o slot faltante', () async {
    final slot = (await backend.fetchSlots(
      dexId: 1,
      boxId: 1,
    )).firstWhere((s) => s.isRegistered);
    final loose = (await backend.fetchAvailable(3)).single;
    final ids = [slot.specimen!.id, loose.id];

    expect(backend.bulkRelease(const []), _validation('ids'));
    expect(backend.bulkRelease([...ids, 9999]), _validation('ids'));
    expect((await backend.fetchSlot(slot.id)).isRegistered, true);

    expect(await backend.bulkRelease([...ids, loose.id]), 2);
    expect((await backend.fetchSlot(slot.id)).isMissing, true);
    expect(backend.fetchSpecimen(loose.id), throwsA(isA<NotFoundFailure>()));
  });

  group('saves e localização', () {
    test('criar: só OT de jogo que recebe do HOME, uma vez', () async {
      // Seed: OT 1 (Scarlet) e 4 (Z-A) já são saves; 2 sem versão; 3 PLA.
      expect((await backend.fetchSaves()).map((s) => s.title), [
        'Scarlet · Switch',
        'Legends Za · Ash (222222)',
      ]);
      expect(backend.createSave(trainerId: 99), _validation('trainer'));
      expect(backend.createSave(trainerId: 2), _validation('trainer'));
      expect(backend.createSave(trainerId: 1), _validation('trainer'));
      final save = await backend.createSave(trainerId: 3, label: 'Lite');
      expect(save.title, 'Legends Arceus · Lite');
    });

    test('renomear leva o apelido aos espécimes; apagar', () async {
      final away = (await backend.fetchSlot(62)).specimen!;
      expect(away.location!.title, 'Scarlet · Switch');
      await backend.updateSave(1, label: 'OLED');
      expect(
        (await backend.fetchSpecimen(away.id)).location!.title,
        'Scarlet · OLED',
      );
      expect(
        backend.updateSave(99, label: 'x'),
        throwsA(isA<NotFoundFailure>()),
      );
      // Com espécime: recusa. Sem: apaga.
      expect(backend.deleteSave(1), throwsA(isA<ValidationFailure>()));
      await backend.deleteSave(2);
      expect(backend.deleteSave(2), throwsA(isA<NotFoundFailure>()));
    });

    test('transferir: tudo ou nada, data e contadores', () async {
      final slot = (await backend.fetchSlots(dexId: 1, boxId: 1)).first;
      final id = slot.specimen!.id;
      expect(backend.transfer(const [], saveId: 1), _validation('ids'));
      expect(backend.transfer([id, 9999], saveId: 1), _validation('ids'));
      expect(backend.transfer([id], saveId: 99), _validation('save'));

      expect(await backend.transfer([id, id], saveId: 1), 1);
      expect(await backend.transfer([id], saveId: 1), 0); // já estava
      final sent = await backend.fetchSpecimen(id);
      expect(sent.isAway, true);
      expect(daysSince(sent.locationSince!), 0);
      expect((await backend.fetchDex(1)).away, 1);
      expect((await backend.fetchBoxes(1)).first.away, 1);
      expect((await backend.fetchGenerations(1)).single.away, 1);
      // Continua contando no progresso.
      expect((await backend.fetchDex(1)).registered, 39);

      Future<int> count(String location) async => (await backend.fetchSpecimens(
        SpecimenQuery(location: location),
        page: 1,
        pageSize: 500,
      )).count;
      expect(await count(SpecimenQuery.locationAway), 2);
      expect(await count('1'), 2);
      expect(await count('2'), 0);
      final all = await count('');
      expect(await count(SpecimenQuery.locationHome), all - 2);

      expect(await backend.transfer([id], saveId: null), 1);
      expect((await backend.fetchSpecimen(id)).location, isNull);
    });

    test('slot reservado recusa outro espécime', () async {
      // Seed: o Ivysaur do slot 62 está fora do HOME.
      final other = backend.addSpecimen(formId: 2);
      expect(
        backend.deposit(slotId: 62, specimenId: other),
        _validation(ValidationFailure.nonFieldKey),
      );
      final away = (await backend.fetchSlot(62)).specimen!.id;
      expect(
        (await backend.deposit(slotId: 62, specimenId: away)).isRegistered,
        true,
      );
    });

    test('evoluir: só evolução; habilidade pelo slot; sai do slot', () async {
      final slot = await backend.fetchSlot(1); // Bulbasaur do shiny dex
      final id = slot.specimen!.id;
      await backend.update(
        id,
        SpecimenDraft.fromSpecimen(await backend.fetchSpecimen(id))
            .copyWith(ability: 'keen-eye'),
      );
      expect(backend.evolve(id, formId: 4), _validation('form')); // Charmander
      expect(backend.evolve(id, formId: 1), _validation('form')); // ele mesmo
      expect(backend.evolve(9999, formId: 2), throwsA(isA<NotFoundFailure>()));

      final evolved = await backend.evolve(id, formId: 3); // dois estágios
      expect((evolved.form, evolved.formName), (3, 'venusaur'));
      expect(evolved.ability, 'keen-eye');
      expect((await backend.fetchSlot(1)).isMissing, true);

      // Sem habilidade conhecida: fica sem.
      final plain = backend.addSpecimen(formId: 4);
      expect((await backend.evolve(plain, formId: 5)).ability, isNull);
    });
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
      // Número: nº nacional da espécie (como search_forms da API).
      final ivysaur = await all(
        emptySpecimenQuery.copyWith(
          search: '2',
          status: SpecimenStatus.all,
          shinyOnly: false,
        ),
      );
      expect(ivysaur.map((s) => s.formName).toSet(), {'ivysaur'});
      expect(ivysaur.first.formRef!.nationalNumber, 2);
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

      // OT: seed com o treinador 1 nas formas múltiplas de 4 (e os
      // treinadores 3 e 4 em algumas outras, para variar a origem).
      final byAsh = await all(const SpecimenQuery(ots: [1]));
      expect(byAsh, isNotEmpty);
      expect(byAsh.every((s) => s.ot == 1), true);
      final noOt = await all(const SpecimenQuery(withoutOt: true));
      final others = await all(const SpecimenQuery(ots: [2, 3, 4]));
      expect(others, isNotEmpty);
      expect(byAsh.length + noOt.length + others.length, everything.length);

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
      // Gênero: o seed também tem fêmeas; o filtro traz exatamente elas.
      expect(await ids(const SpecimenQuery(genders: ['female'])), {
        for (final s in everything)
          if (s.gender == 'female') s.id,
      });
      expect(everything.firstWhere((s) => s.id == jolly.id).gender, 'female');
      expect(await ids(const SpecimenQuery(natures: ['jolly'])), {jolly.id});
      expect(await ids(const SpecimenQuery(languages: ['ja'])), {jolly.id});
      expect(await ids(const SpecimenQuery(ability: ' KEEN ')), {jolly.id});
      expect(await ids(const SpecimenQuery(ability: 'keen eye')), {jolly.id});
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
      final boxOrder = await all(
        emptySpecimenQuery.copyWith(ordering: SpecimenOrdering.box),
      );
      expect(boxOrder.map((s) => s.id), everything.map((s) => s.id));
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

    test('marca de origem: derivada do OT e filtro como na API', () async {
      final everything = await all(emptySpecimenQuery);
      Future<Set<String?>> marks(List<String> filter) async => {
        for (final s in await all(SpecimenQuery(originMarks: filter)))
          s.originMark,
      };
      // Seed: OT 1 (scarlet), 3 (legends-arceus), 4 (legends-za).
      for (final s in everything) {
        final expected = s.isFromGo
            ? 'go'
            : switch (s.ot) {
                1 => 'paldea',
                3 => 'hisui',
                4 => 'lumiose',
                _ => null,
              };
        expect(s.originMark, expected, reason: 'specimen ${s.id}');
      }
      expect(await marks(['paldea']), {'paldea'});
      expect(await marks(['hisui', 'go']), {'hisui', 'go'});
      expect(await marks([SpecimenQuery.noneParam]), {null});
      final byMark = [
        for (final m in ['paldea', 'hisui', 'lumiose', 'go', 'none'])
          ...await all(SpecimenQuery(originMarks: [m])),
      ];
      expect(byMark.length, everything.length);
      expect(await all(const SpecimenQuery(originMarks: ['kalos'])), isEmpty);
    });

    test('jogo de origem: criar, trocar OT, editar e lote', () async {
      final za = backend.addTrainer(
        name: 'Ash',
        trainerId: '9',
        version: 'lets-go-pikachu',
      );
      final emerald = backend.addTrainer(
        name: 'Brendan',
        trainerId: '3',
        version: 'emerald',
      );
      final created = await backend.create(
        SpecimenDraft(form: 1, ability: 'run-away', ot: za),
      );
      expect(
        (created.originVersion, created.originMark),
        ('lets-go-pikachu', 'lets-go'),
      );

      // Editar sem trocar o OT mantém o jogo; trocar deriva de novo.
      final kept = await backend.update(
        created.id,
        SpecimenDraft.fromSpecimen(created).copyWith(nickname: 'Pika'),
      );
      expect(kept.originMark, 'lets-go');
      final gen3 = await backend.update(
        created.id,
        SpecimenDraft.fromSpecimen(created).copyWith(ot: emerald),
      );
      expect((gen3.originVersion, gen3.originMark), ('emerald', null));

      // Lote: trocar o OT deriva; outras mudanças mantêm; GO tem prioridade.
      await backend.bulkUpdate(
        ids: [created.id],
        changes: const SpecimenChanges(ot: SetTo(1)),
      );
      expect((await backend.fetchSpecimen(created.id)).originMark, 'paldea');
      await backend.bulkUpdate(
        ids: [created.id],
        changes: const SpecimenChanges(isFromGo: SetTo(true)),
      );
      final go = await backend.fetchSpecimen(created.id);
      expect((go.originVersion, go.originMark), ('scarlet', 'go'));
      await backend.bulkUpdate(
        ids: [created.id],
        changes: const SpecimenChanges(ot: SetTo(null), isFromGo: SetTo(false)),
      );
      final none = await backend.fetchSpecimen(created.id);
      expect((none.originVersion, none.originMark), (null, null));
    });

    test('filtro ids ("só selecionados")', () async {
      final some = (await all(emptySpecimenQuery)).take(3).toList();
      final ids = [some[2].id, some[0].id];
      final picked = await all(SpecimenQuery(ids: ids));
      expect(picked.map((s) => s.id).toSet(), ids.toSet());
      // Combina com os outros filtros.
      expect(await all(SpecimenQuery(ids: ids, search: 'zzz')), isEmpty);
    });

    test('ids do filtro, na ordem da lista', () async {
      const query = SpecimenQuery(
        withoutPokeball: true,
        ordering: SpecimenOrdering.createdDesc,
      );
      expect(await backend.fetchSpecimenIds(query), [
        for (final s in await all(query)) s.id,
      ]);
    });

    group('edição em lote', () {
      test('aplica só o que muda, em todos os ids', () async {
        final ids = [
          for (final s in (await all(emptySpecimenQuery)).take(3)) s.id,
        ];
        final updated = await backend.bulkUpdate(
          ids: [...ids, ids.first],
          changes: SpecimenChanges(
            pokeball: const SetTo('beast-ball'),
            ot: const SetTo(2),
            nature: const SetTo('timid'),
            language: const SetTo('ja'),
            capturedAt: SetTo(DateTime(2026, 5, 5)),
            isShiny: const SetTo(false),
            isAlpha: const SetTo(true),
            isFromGo: const SetTo(true),
          ),
        );
        expect(updated, 3);
        for (final id in ids) {
          final s = await backend.fetchSpecimen(id);
          expect(s.pokeball, 'beast-ball');
          expect(s.pokeballSpriteUrl, endsWith('beast-ball.png'));
          expect(s.ot, 2);
          expect(s.nature, 'timid');
          expect(s.language, 'ja');
          expect(s.capturedAt, DateTime(2026, 5, 5));
          expect((s.isShiny, s.isAlpha, s.isFromGo), (false, true, true));
        }
        // Remover (SetTo(null)) e manter (Keep).
        await backend.bulkUpdate(
          ids: [ids.first],
          changes: const SpecimenChanges(
            pokeball: SetTo(null),
            capturedAt: SetTo(null),
          ),
        );
        final first = await backend.fetchSpecimen(ids.first);
        expect(first.pokeball, isNull);
        expect(first.capturedAt, isNull);
        expect(first.nature, 'timid');
      });

      test('pedido inválido não altera nada', () async {
        const changes = SpecimenChanges(isAlpha: SetTo(true));
        await expectLater(
          backend.bulkUpdate(ids: const [], changes: changes),
          throwsA(isA<ValidationFailure>()),
        );
        await expectLater(
          backend.bulkUpdate(ids: const [1], changes: const SpecimenChanges()),
          throwsA(isA<ValidationFailure>()),
        );
        await expectLater(
          backend.bulkUpdate(ids: const [1, 9999], changes: changes),
          throwsA(
            isA<ValidationFailure>().having(
              (f) => f.errorFor('ids'),
              'ids',
              contains('9999'),
            ),
          ),
        );
        expect((await backend.fetchSpecimen(1)).isAlpha, true); // seed: forma 1
      });

      test('gênero validado pela espécie, tudo ou nada', () async {
        // Seed: Nidoran♀ (29) só fêmea; forma 1 macho ou fêmea.
        final nidoranF = (await all(
          emptySpecimenQuery.copyWith(search: 'nidoran-f'),
        )).first;
        final bulba = (await all(emptySpecimenQuery)).first;
        await expectLater(
          backend.bulkUpdate(
            ids: [bulba.id, nidoranF.id],
            changes: const SpecimenChanges(gender: SetTo('male')),
          ),
          throwsA(
            isA<GenderConflictFailure>().having((f) => f.conflicts, 'c', [
              (id: nidoranF.id, formName: 'nidoran-f'),
            ]),
          ),
        );
        expect((await backend.fetchSpecimen(bulba.id)).gender, bulba.gender);
        expect(
          await backend.bulkUpdate(
            ids: [bulba.id, nidoranF.id],
            changes: const SpecimenChanges(gender: SetTo('female')),
          ),
          2,
        );
      });
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

    test('ordem das boxes e nº nacional', () async {
      // Eevee (133) na 2ª box, Glaceon (471) na 1ª; Mew (151) fora das
      // boxes; um Eevee depositado numa 3ª box.
      final fake = FakeBackend()
        ..addForm(id: 133, name: 'eevee')
        ..addForm(id: 151, name: 'mew')
        ..addForm(id: 471, name: 'glaceon')
        ..addBox(dexId: 1, name: 'HOME 1', formIds: const [471])
        ..addBox(dexId: 1, name: 'HOME 2', formIds: const [133])
        ..addBox(dexId: 2, name: 'HOME 3', formIds: const [133]);
      final eevee = fake.addSpecimen(formId: 133);
      final mew = fake.addSpecimen(formId: 151);
      final glaceon = fake.addSpecimen(formId: 471);
      final deposited = fake.addSpecimen(formId: 133);
      final slot = (await fake.fetchSlots(dexId: 2, boxId: 3)).first;
      await fake.deposit(slotId: slot.id, specimenId: deposited);

      Future<List<int>> ids(SpecimenOrdering ordering) async => [
        for (final s in (await fake.fetchSpecimens(
          SpecimenQuery(ordering: ordering),
          page: 1,
          pageSize: 10,
        )).results)
          s.id,
      ];
      expect(await ids(SpecimenOrdering.box), [glaceon, eevee, deposited, mew]);
      expect(await ids(SpecimenOrdering.national), [
        eevee,
        deposited,
        mew,
        glaceon,
      ]);
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
      // Nome como se escreve: vira slug.
      final humanized = await backend.searchSlots(
        dexId: 1,
        search: 'Nidoran F',
      );
      expect(humanized.single.form!.name, 'nidoran-f');
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
      // Sobrou 1 box livre (HOME 6), a última: o próximo dex a completa
      // com uma box nova no fim.
      final extending = await backend.previewNewDex(forceNewBox: false);
      expect(extending.enoughSpace, true);
      expect(extending.boxesToCreate, 1);
      expect(extending.firstBox!.name, 'HOME 6');
      final other = await backend.createDex(
        name: 'Outra',
        isShinyDex: false,
        forceNewBox: false,
      );
      expect((await backend.fetchBoxes(other.id)).map((b) => b.name), [
        'HOME 6',
        'HOME 7',
      ]);

      // Sem nenhuma livre: tudo em boxes novas, até o limite.
      final allNew = await backend.previewNewDex(forceNewBox: false);
      expect(allNew.boxesToCreate, 2);
      expect(allNew.firstBox, isNull);
      backend.maxBoxes = 8;
      final full = await backend.previewNewDex(forceNewBox: false);
      expect(full.enoughSpace, false);
      expect(full.boxesToCreate, 0);
      expect(full.firstBox, isNull);
      expect(
        backend.createDex(name: 'Mais', isShinyDex: false, forceNewBox: false),
        _validation(ValidationFailure.nonFieldKey),
      );
    });

    test('novo dex sem boxes: cria "HOME n" pulando nomes usados', () async {
      final empty = FakeBackend()..addForm(id: 1, name: 'bulbasaur');
      final first = await empty.createDex(
        name: 'Primeiro',
        isShinyDex: false,
        forceNewBox: false,
      );
      expect((await empty.fetchBoxes(first.id)).map((b) => b.name), ['HOME 1']);
      empty.addFreeBox('HOME 3');
      // HOME 3 está livre e é a última: cabe nela.
      final second = await empty.createDex(
        name: 'Segundo',
        isShinyDex: false,
        forceNewBox: false,
      );
      expect((await empty.fetchBoxes(second.id)).map((b) => b.name), [
        'HOME 3',
      ]);
      // A próxima seria a 3ª box, mas "HOME 3" já existe.
      final third = await empty.createDex(
        name: 'Terceiro',
        isShinyDex: false,
        forceNewBox: false,
      );
      expect((await empty.fetchBoxes(third.id)).map((b) => b.name), ['HOME 4']);
    });

    test('editar e apagar dex', () async {
      final updated = await backend.updateDex(
        1,
        name: 'Minha Dex',
        isShinyDex: false,
      );
      expect(updated.name, 'Minha Dex');
      expect(updated.isShinyDex, false);
      expect(updated.total, 58);
      expect(
        backend.updateDex(1, name: ' ', isShinyDex: false),
        _validation('name'),
      );
      expect(
        backend.updateDex(1, name: 'Living Dex', isShinyDex: false),
        _validation('name'),
      );
      expect(
        backend.updateDex(99, name: 'X', isShinyDex: false),
        throwsA(isA<NotFoundFailure>()),
      );

      final deposited = (await backend.fetchSpecimens(
        const SpecimenQuery(status: SpecimenStatus.deposited),
        page: 1,
        pageSize: 500,
      )).count;
      await backend.deleteDex(1);
      expect((await backend.fetchDexes()).map((d) => d.name), ['Living Dex']);
      // Os slots ficam livres e os espécimes continuam, disponíveis.
      final stillDeposited = (await backend.fetchSpecimens(
        const SpecimenQuery(status: SpecimenStatus.deposited),
        page: 1,
        pageSize: 500,
      )).count;
      expect(stillDeposited, lessThan(deposited));
      expect(
        (await backend.previewNewDex(forceNewBox: false)).firstBox!.name,
        'HOME 1',
      );
      expect(backend.deleteDex(1), throwsA(isA<NotFoundFailure>()));
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
      expect((await backend.searchForms('nidoran m')).single.name, 'nidoran-m');
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
    expect(await backend.fetchTrainers(), hasLength(4));
    expect(
      (await backend.fetchOptions()).originMark.map((c) => c.value),
      containsAllInOrder(['paldea', 'go', 'none']),
    );
  });

  test('allowedGenders: forma por gênero e gender_rate', () {
    FormDetail form(int id, String name) => FormDetail(
      id: id,
      name: name,
      pokeapiId: id,
      spriteUrl: '',
      shinySpriteUrl: '',
    );
    const rates = {1: -1, 2: 0, 3: 8, 4: 4, 5: 0};
    expect(allowedGenders(form(1, 'magnemite'), rates), {'genderless'});
    expect(allowedGenders(form(2, 'tauros'), rates), {'male'});
    expect(allowedGenders(form(3, 'chansey'), rates), {'female'});
    expect(allowedGenders(form(4, 'pikachu'), rates), {'male', 'female'});
    expect(allowedGenders(form(9, 'sem-taxa'), rates), {'male', 'female'});
    expect(allowedGenders(form(5, 'oinkologne-female'), rates), {'female'});
    expect(allowedGenders(form(4, 'meowstic-male'), rates), {'male'});
  });

  group('caçadas', () {
    Future<List<String>> names(
      HuntQuery query, {
      FakeBackend? on,
      int dexId = 1,
    }) async => [
      for (final hunt in (await (on ?? backend).fetchHunts(
        dexId,
        query,
        page: 1,
        pageSize: 100,
      )).results)
        hunt.slot.form!.name,
    ];

    test('padrão: slots sem shiny, na ordem das boxes', () async {
      final page = await backend.fetchHunts(
        1,
        const HuntQuery(),
        page: 1,
        pageSize: 100,
      );
      // Formas múltiplas de 3 ficaram sem espécime no shiny dex.
      expect(page.count, 19);
      expect(page.results.first.slot.form!.name, 'venusaur');
      expect(page.results.first.reasons, [HuntReason.noShiny]);
    });

    test('espécime não shiny também é caçada', () async {
      final fake = FakeBackend()..addForm(id: 1, name: 'bulbasaur');
      final dex = fake.addDex(name: 'Shiny', isShinyDex: true);
      fake.addBox(dexId: dex, name: 'HOME 1', formIds: [1]);
      await fake.deposit(slotId: 1, specimenId: fake.addSpecimen(formId: 1));
      final hunt = (await fake.fetchHunts(
        dex,
        const HuntQuery(),
        page: 1,
        pageSize: 10,
      )).results.single;
      expect(hunt.reasons, [HuntReason.noShiny]);
      expect(hunt.slot.specimen, isNotNull);
    });

    test(
      'motivos: GO, pokébola (bola nula não conta) e todos os motivos',
      () async {
        final go = await backend.fetchHunts(
          1,
          const HuntQuery(reasons: [HuntReason.fromGo]),
          page: 1,
          pageSize: 100,
        );
        expect(go.count, 6);
        expect(
          go.results.every((h) => h.reasons.contains(HuntReason.fromGo)),
          true,
        );

        const balls = HuntQuery(
          reasons: [HuntReason.pokeball],
          acceptedBalls: ['poke-ball'],
        );
        final wrongBall = await backend.fetchHunts(
          1,
          balls,
          page: 1,
          pageSize: 100,
        );
        expect(wrongBall.count, 20); // shinies em Dream Ball
        // O item traz todos os motivos: Dream Ball e do GO (forma 14).
        final both = wrongBall.results.firstWhere((h) => h.slot.form!.id == 14);
        expect(both.reasons, [HuntReason.fromGo, HuntReason.pokeball]);

        // Sem bolas aceitas, o motivo "pokébola" não lista nada.
        expect(
          await names(const HuntQuery(reasons: [HuntReason.pokeball])),
          isEmpty,
        );

        // Bola não informada não conta como bola errada.
        final fake = FakeBackend()..addForm(id: 1, name: 'bulbasaur');
        final dex = fake.addDex(name: 'Shiny', isShinyDex: true);
        fake.addBox(dexId: dex, name: 'HOME 1', formIds: [1]);
        await fake.deposit(
          slotId: 1,
          specimenId: fake.addSpecimen(formId: 1, isShiny: true),
        );
        expect(await names(balls, on: fake, dexId: dex), isEmpty);
      },
    );

    test('escopo: geração, tipo (qualquer um), categoria e busca', () async {
      final fake = FakeBackend()
        ..addForm(id: 1, name: 'bulbasaur', types: ['grass'])
        ..addForm(
          id: 150,
          name: 'mewtwo',
          types: ['psychic'],
          category: HuntCategory.legendary,
        )
        ..addForm(
          id: 793,
          name: 'nihilego',
          types: ['rock', 'poison'],
          category: HuntCategory.ultraBeast,
        );
      final dex = fake.addDex(name: 'Shiny', isShinyDex: true);
      fake.addBox(dexId: dex, name: 'HOME 1', formIds: [1, 150, 793]);
      Future<List<String>> run(HuntQuery q) => names(q, on: fake, dexId: dex);

      expect(await run(const HuntQuery(generations: ['generation-vii'])), [
        'nihilego',
      ]);
      expect(await run(const HuntQuery(types: ['grass', 'poison'])), [
        'bulbasaur',
        'nihilego',
      ]);
      expect(
        await run(
          const HuntQuery(
            categories: [HuntCategory.legendary, HuntCategory.ultraBeast],
          ),
        ),
        ['mewtwo', 'nihilego'],
      );
      expect(await run(const HuntQuery(categories: [HuntCategory.regular])), [
        'bulbasaur',
      ]);
      expect(await run(const HuntQuery(search: ' MEW')), ['mewtwo']);
      expect(await run(const HuntQuery(search: '793')), ['nihilego']);
      // Nome como se escreve: vira slug.
      final iron = FakeBackend()..addForm(id: 992, name: 'iron-hands');
      final ironDex = iron.addDex(name: 'Shiny', isShinyDex: true);
      iron.addBox(dexId: ironDex, name: 'HOME 1', formIds: [992]);
      expect(
        await names(
          const HuntQuery(search: 'Iron Hands'),
          on: iron,
          dexId: ironDex,
        ),
        ['iron-hands'],
      );
    });

    test('shiny lock: impossível só com includeLocked', () async {
      final fake = FakeBackend()
        ..addForm(id: 1, name: 'victini', shinyLock: ShinyLock.unobtainable)
        ..addForm(id: 2, name: 'keldeo', shinyLock: ShinyLock.distroOnly);
      final dex = fake.addDex(name: 'Shiny', isShinyDex: true);
      fake.addBox(dexId: dex, name: 'HOME 1', formIds: [1, 2]);
      final page = await fake.fetchHunts(
        dex,
        const HuntQuery(),
        page: 1,
        pageSize: 10,
      );
      expect([for (final h in page.results) h.slot.form!.name], ['keldeo']);
      expect(page.results.single.shinyLock, ShinyLock.distroOnly);
      final all = await fake.fetchHunts(
        dex,
        const HuntQuery(includeLocked: true),
        page: 1,
        pageSize: 10,
      );
      expect(all.results.first.shinyLock, ShinyLock.unobtainable);
      expect((await fake.fetchForm(1)).isShinylocked, true);
    });

    test('paginação, dex normal e inexistente', () async {
      final first = await backend.fetchHunts(
        1,
        const HuntQuery(),
        page: 1,
        pageSize: 10,
      );
      expect(first.results, hasLength(10));
      expect(first.hasNext, true);
      final last = await backend.fetchHunts(
        1,
        const HuntQuery(),
        page: 2,
        pageSize: 10,
      );
      expect(last.results, hasLength(9));
      expect(last.hasNext, false);
      expect(
        backend.fetchHunts(1, const HuntQuery(), page: 3, pageSize: 10),
        throwsA(isA<NotFoundFailure>()),
      );
      expect(
        backend.fetchHunts(2, const HuntQuery(), page: 1, pageSize: 10),
        throwsA(isA<ValidationFailure>()),
      );
      expect(
        backend.fetchHunts(9, const HuntQuery(), page: 1, pageSize: 10),
        throwsA(isA<NotFoundFailure>()),
      );
    });
  });
}
