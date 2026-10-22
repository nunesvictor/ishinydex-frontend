import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/shiny_hunts/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/domain/shiny_odds.dart';
import 'package:ishinydex/features/shiny_hunts/presentation/hunt_lists.dart';
import 'package:ishinydex/features/shiny_hunts/shiny_hunt_providers.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/hunt_record_card.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

import '../../helpers/helpers.dart';

final _now = DateTime(2026, 10, 9, 12);

const _methods = [
  ShinyMethod(
    id: 'random',
    label: 'Encontro aleatório',
    units: ['encounters', 'hours'],
    versions: {},
  ),
  ShinyMethod(id: 'sr', label: 'Soft reset', units: ['resets'], versions: {}),
  ShinyMethod(id: 'sos', label: 'SOS', units: ['encounters'], versions: {}),
  ShinyMethod(id: 'raid', label: 'Reide', units: ['raids'], versions: {}),
  ShinyMethod(
    id: 'dexnav',
    label: 'DexNav',
    units: ['encounters'],
    versions: {},
  ),
];

OddsModifier _choice(String id, List<String> labels) => OddsModifier(
  id: id,
  label: id,
  options: [
    for (final (i, l) in labels.indexed)
      (label: l, labels: const <String, String>{}, rolls: i),
  ],
);

final _rules = {
  'random': OddsRule(
    method: 'random',
    versions: const {},
    kind: OddsKind.rolls,
    charm: 2,
    modifiers: [
      _choice('sparkling', ['Sem', 'Nv. 1', 'Nv. 2', 'Nv. 3']),
      _choice('battled', ['0', '1', '2', '3', '4', '5']),
    ],
  ),
  // O Charm não vale para o Bulbasaur (form 1).
  'sr': const OddsRule(
    method: 'sr',
    versions: {},
    kind: OddsKind.rolls,
    charm: 2,
    charmExceptForms: {1},
  ),
  'sos': const OddsRule(
    method: 'sos',
    versions: {},
    kind: OddsKind.rolls,
    charm: 2,
    steps: [ChainStep(0, rolls: 0), ChainStep(31, rolls: 12)],
  ),
  'raid': const OddsRule(method: 'raid', versions: {}, kind: OddsKind.rolls),
  // Sem nenhuma chance: "não pode ser shiny".
  'never': const OddsRule(
    method: 'never',
    versions: {},
    kind: OddsKind.rolls,
    rolls: 0,
  ),
  'dexnav': const OddsRule(
    method: 'dexnav',
    versions: {},
    kind: OddsKind.dexnav,
    charm: 2,
    modifiers: [
      OddsModifier(
        id: 'searchLevel',
        label: 'Search Level',
        min: 0,
        max: 999,
        followsCount: true,
      ),
    ],
  ),
};

void main() {
  late FakeBackend backend;
  late int scarlet;
  late int sword;
  late int frlg;

  setUp(() async {
    backend = FakeBackend.seeded();
    Future<int> save(String version, String id) async {
      final ot = backend.addTrainer(
        name: 'Ash',
        trainerId: id,
        version: version,
      );
      return (await backend.createSave(trainerId: ot)).id;
    }

    scarlet = await save('scarlet', '1');
    await backend.updateSave(scarlet, hasShinyCharm: true);
    sword = await save('sword', '2');
    frlg = await save('firered', '3');
  });

  Future<ShinyHunt> add(ShinyHunt hunt) => backend.saveShinyHunt(hunt);

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Locale locale = portuguese,
  }) => pumpWidgetApp(
    tester,
    child,
    locale: locale,
    size: const Size(420, 2400),
    hunts: backend,
    overrides: [
      // A folha do card (#243) abre depois do "Encontrei!": sem a captura
      // de verdade, que trava sem `runAsync`.
      pngCapturerProvider.overrideWithValue(
        (_, _) async => Uint8List.fromList([1]),
      ),
      fakeBackendProvider.overrideWithValue(backend),
      clockProvider.overrideWithValue(() => _now),
      shinyMethodsProvider.overrideWithValue(
        (_, {fromGo = false, formId}) => _methods,
      ),
      huntableInProvider.overrideWithValue((_, _) => true),
      oddsRuleProvider.overrideWithValue(
        // FRLG: sem regra para o Encontro aleatório.
        (method, save) =>
            save?.trainer.version == 'firered' && method == 'random'
            ? null
            : _rules[method],
      ),
    ],
  );

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder.first);
    await tester.tap(finder.first);
    await tester.pumpAndSettle();
  }

  Finder inCard(int id, Finder finder) => find.descendant(
    of: find.byKey(ValueKey('hunt-card-$id')),
    matching: finder,
  );

  /// Digita a contagem no próprio número do cartão (#281) e confirma.
  Future<void> typeCount(WidgetTester tester, int id, String text) async {
    final field = inCard(id, find.byKey(const ValueKey('hunt-count')));
    await tap(tester, field);
    await tester.enterText(field, text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  Future<ShinyHunt> hunt(int id) async =>
      (await backend.fetchShinyHunts()).firstWhere((h) => h.id == id);

  testWidgets('cartão em inglês: cadeia, Charm e o múltiplo com ponto', (
    tester,
  ) async {
    await add(
      ShinyHunt(
        id: 0,
        form: 4,
        save: sword,
        method: 'sos',
        count: 30,
        chain: 30,
        bestChain: 40,
      ),
    );
    await add(ShinyHunt(id: 0, form: 5, save: scarlet, method: 'never'));
    await pump(
      tester,
      const Scaffold(body: HuntCards(paused: false)),
      locale: english,
    );
    await tester.pumpAndSettle();
    expect(find.text("can't be shiny"), findsOne);
    expect(find.textContaining(RegExp('^chain 30')), findsOne);
    expect(find.textContaining('Current chain'), findsOne);
    expect(find.textContaining('longest chain: 40'), findsOne);
    expect(find.text('Broke'), findsOne);
    expect(find.textContaining('of hunts would have ended by now'), findsOne);
    expect(find.textContaining(RegExp(r'\d\.\d× the odds')), findsOne);
  });

  testWidgets('cartão: odds, Charm, barra, cadeia e horas', (tester) async {
    final random = await add(
      ShinyHunt(id: 0, form: 2, save: scarlet, method: 'random', count: 1366),
    );
    final regi = await add(
      ShinyHunt(id: 0, form: 1, save: scarlet, method: 'sr'),
    );
    final raid = await add(
      ShinyHunt(id: 0, form: 3, save: scarlet, method: 'raid'),
    );
    final chain = await add(
      ShinyHunt(
        id: 0,
        form: 4,
        save: sword,
        method: 'sos',
        count: 30,
        chain: 30,
        bestChain: 30,
      ),
    );
    final dexnav = await add(
      ShinyHunt(
        id: 0,
        form: 5,
        save: sword,
        method: 'dexnav',
        modifiers: const {'searchLevel': 7},
      ),
    );
    final timed = await add(
      ShinyHunt(id: 0, form: 6, save: scarlet, method: 'random', unit: 'hours'),
    );
    final none = await add(
      ShinyHunt(id: 0, form: 7, save: frlg, method: 'random', count: 5),
    );
    await pump(tester, const Scaffold(body: HuntCards(paused: false)));
    await tester.pumpAndSettle();

    String odds(int id) => tester
        .widget<Text>(inCard(id, find.byKey(const ValueKey('hunt-odds'))))
        .data!;
    expect(odds(random.id), '1/1366');
    expect(inCard(random.id, find.text('Shiny Charm (do save)')), findsOne);
    expect(
      inCard(
        random.id,
        find.text('63% das caçadas já teriam terminado · 1,0× as odds'),
      ),
      findsOne,
    );
    // O +1 passa a guardar a chance acumulada.
    await tap(
      tester,
      inCard(random.id, find.widgetWithText(FilledButton, '1')),
    );
    expect((await hunt(random.id)).miss, isNotNull);

    expect(odds(regi.id), '1/4096');
    expect(
      inCard(regi.id, find.text('O Charm não vale para este encontro')),
      findsOne,
    );
    expect(
      inCard(raid.id, find.text('O Charm não vale neste método')),
      findsOne,
    );
    // Sem contagem, sem barra.
    expect(
      inCard(raid.id, find.byKey(const ValueKey('hunt-odds-progress'))),
      findsNothing,
    );

    // Cadeia: o +1 soma na cadeia; "Quebrou" zera; digitar vira estimativa.
    expect(inCard(chain.id, find.text('Cadeia atual ')), findsNothing);
    expect(inCard(chain.id, find.textContaining('Cadeia atual')), findsOne);
    expect(odds(chain.id), '1/4096');
    await tap(tester, inCard(chain.id, find.widgetWithText(FilledButton, '1')));
    expect(odds(chain.id), '1/316');
    expect((await hunt(chain.id)).chain, 31);
    await tap(tester, inCard(chain.id, find.text('Quebrou')));
    expect((await hunt(chain.id)).chain, 0);
    expect((await hunt(chain.id)).bestChain, 31);
    // Com a cadeia em 0, o "Quebrou" fica desabilitado.
    expect(
      tester
          .widget<OutlinedButton>(
            inCard(chain.id, find.widgetWithText(OutlinedButton, 'Quebrou')),
          )
          .onPressed,
      isNull,
    );
    await typeCount(tester, chain.id, '50');
    expect(
      inCard(chain.id, find.textContaining('(estimativa: contagem digitada)')),
      findsOne,
    );

    expect(inCard(dexnav.id, find.textContaining('Search Level 7')), findsOne);
    await tap(
      tester,
      inCard(dexnav.id, find.widgetWithText(FilledButton, '1')),
    );
    expect((await hunt(dexnav.id)).modifiers['searchLevel'], 8);

    expect(
      inCard(timed.id, find.textContaining('em horas: só as odds')),
      findsOne,
    );
    // Sem regra (FRLG aqui): sem odds, o +1 como antes.
    expect(
      inCard(none.id, find.byKey(const ValueKey('hunt-odds'))),
      findsNothing,
    );
    await tap(tester, inCard(none.id, find.widgetWithText(FilledButton, '1')));
    expect((await hunt(none.id)).count, 6);
    await typeCount(tester, none.id, '9');
    expect((await hunt(none.id)).count, 9);

    // Encontrei!: o registro leva as odds do fim.
    await tap(tester, inCard(random.id, find.byTooltip('Mais ações')));
    await tap(tester, find.text('Encontrei!'));
    await tap(tester, find.text('Salvar'));
    // A folha do card (#243): "Agora não" fecha.
    expect(find.text('Shiny registrado!'), findsOne);
    await tap(tester, find.text('Agora não'));
    final specimens = await backend.fetchSpecimens(
      const SpecimenQuery(),
      page: 1,
      pageSize: 500,
    );
    final record = specimens.results
        .map((s) => s.hunt)
        .whereType<HuntRecord>()
        .single;
    expect(record.odds, closeTo(1365.67, 0.01));
    expect(record.multiple, isNotNull);
  });

  testWidgets('folha: modificadores, Charm e prévia das odds', (tester) async {
    final editing = await add(
      ShinyHunt(id: 0, form: 2, save: scarlet, method: 'random'),
    );
    await pump(tester, const Scaffold(body: HuntCards(paused: false)));
    await tester.pumpAndSettle();
    await tap(tester, find.byTooltip('Mais ações'));
    await tap(tester, find.text('Editar'));

    String preview() => tester
        .widget<Text>(find.byKey(const ValueKey('hunt-odds-preview')))
        .data!;
    expect(find.text('Shiny Charm: sim (do save)'), findsOne);
    expect(preview(), '1/1366');
    // Até 4 opções: segmentos.
    await tap(tester, find.text('Nv. 3'));
    expect(preview(), '1/683');
    // Mais de 4: lista.
    await tap(tester, find.byKey(const ValueKey('field-hunt-mod-battled')));
    await tap(tester, find.text('5').last);
    expect(preview(), '1/373');
    await tap(tester, find.text('Salvar'));
    expect((await hunt(editing.id)).modifiers, {'sparkling': 3, 'battled': 5});

    // Trocar o método zera os modificadores; o numérico é um campo.
    await tap(tester, find.byTooltip('Mais ações'));
    await tap(tester, find.text('Editar'));
    await tap(tester, find.byKey(const ValueKey('field-hunt-method')));
    await tap(tester, find.text('DexNav').last);
    expect(find.text('Sobe junto com o +1.'), findsOne);
    await tester.enterText(
      find.byKey(const ValueKey('field-hunt-mod-searchLevel')),
      '200',
    );
    await tester.pumpAndSettle();
    expect(preview(), '1/307');
    // Soft reset do Bulbasaur? Aqui é o Ivysaur: o Charm vale.
    await tap(tester, find.byKey(const ValueKey('field-hunt-method')));
    await tap(tester, find.text('Soft reset').last);
    expect(find.text('Shiny Charm: sim (do save)'), findsOne);
    await tap(tester, find.byKey(const ValueKey('field-hunt-method')));
    await tap(tester, find.text('Reide').last);
    expect(find.text('Shiny Charm: não vale neste método'), findsOne);
    await tap(tester, find.byKey(const ValueKey('field-hunt-method')));
    await tap(tester, find.text('Encontro aleatório').last);
    // Save sem o Charm; jogo sem o Charm (FRLG não tem regra: sem prévia).
    await tap(tester, find.byKey(const ValueKey('field-hunt-save')));
    await tap(tester, find.textContaining('Sword').last);
    expect(find.text('Shiny Charm: não (marque no save)'), findsOne);
    await tap(tester, find.byKey(const ValueKey('field-hunt-save')));
    await tap(tester, find.textContaining('FireRed').last);
    expect(find.byKey(const ValueKey('hunt-odds-preview')), findsNothing);
    await tap(tester, find.byKey(const ValueKey('field-hunt-method')));
    await tap(tester, find.text('Soft reset').last);
    expect(find.text('Sem Shiny Charm neste jogo'), findsOne);
  });

  testWidgets('folha: Charm que não vale para a forma e jogo sem Charm', (
    tester,
  ) async {
    await add(ShinyHunt(id: 0, form: 1, save: scarlet, method: 'sr'));
    await pump(tester, const Scaffold(body: HuntCards(paused: false)));
    await tester.pumpAndSettle();
    await tap(tester, find.byTooltip('Mais ações'));
    await tap(tester, find.text('Editar'));
    expect(find.text('Shiny Charm: não vale para este encontro'), findsOne);
  });

  testWidgets('registro: odds no fim, múltiplo e maior cadeia', (tester) async {
    await pump(
      tester,
      const Scaffold(
        body: HuntRecordCard(
          hunt: HuntRecord(
            method: 'sos',
            count: 312,
            unit: 'encounters',
            odds: 273.53,
            multiple: 0.62,
            bestChain: 38,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SOS · 312 encontros · maior cadeia 38'), findsOne);
    expect(find.text('Odds no fim: 1/274 · achado em 0,6× as odds'), findsOne);
    await pump(
      tester,
      const Scaffold(body: HuntRecordCard(hunt: HuntRecord(odds: 5.26))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Odds no fim: 1/5,3'), findsOne);
  });
}
