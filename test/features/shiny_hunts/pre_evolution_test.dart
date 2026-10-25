import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/shiny_hunts/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/presentation/completed_hunts.dart';
import 'package:ishinydex/features/shiny_hunts/presentation/hunt_card.dart';
import 'package:ishinydex/features/shiny_hunts/presentation/hunt_lists.dart';
import 'package:ishinydex/features/shiny_hunts/presentation/start_hunt_sheet.dart';
import 'package:ishinydex/features/shiny_hunts/shiny_hunt_providers.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/hunt_record_card.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/hunt_record_section.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/hunt_share_card.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

import '../../helpers/helpers.dart';

// Caçar pela pré-evolução (#315). No backend de exemplo: Charmander (4) →
// Charmeleon (5) → Charizard (6).

final _now = DateTime(2026, 10, 22, 20);

const _methods = [
  ShinyMethod(id: 'masuda', label: 'Masuda', units: ['eggs'], versions: {}),
];

void main() {
  late FakeBackend backend;

  setUp(() async {
    backend = FakeBackend.seeded();
    final ot = backend.addTrainer(
      name: 'Ash',
      trainerId: '1',
      version: 'scarlet',
    );
    await backend.createSave(trainerId: ot);
  });

  group('FakeBackend', () {
    test('as pré-evoluções, da mais básica à anterior', () {
      expect(
        [for (final f in backend.preEvolutionsOf(6)) f.name],
        ['charmander', 'charmeleon'],
      );
      expect(backend.preEvolutionsOf(4), isEmpty);
      expect(backend.formRefOf(6)?.name, 'charizard');
      expect(backend.formRefOf(99999), isNull);
    });

    test('a caçada guarda o objetivo, que tem de ser uma evolução', () async {
      final hunt = await backend.saveShinyHunt(
        const ShinyHunt(id: 0, form: 4, goal: 6),
      );
      expect(hunt.goalRef?.name, 'charizard');
      expect(hunt.aims(6), isTrue);
      expect(hunt.aims(4), isTrue);
      expect(hunt.aims(5), isFalse);
      // Igual à forma: sem objetivo.
      final same = await backend.saveShinyHunt(
        const ShinyHunt(id: 0, form: 4, goal: 4),
      );
      expect(same.goal, isNull);
      await expectLater(
        backend.saveShinyHunt(const ShinyHunt(id: 0, form: 6, goal: 4)),
        throwsA(isA<ValidationFailure>()),
      );

      // Ida e volta no arquivo de dados.
      final copy = FakeBackend.seeded()..replaceRecords(backend.records);
      final read = (await copy.fetchShinyHunts()).firstWhere(
        (h) => h.id == hunt.id,
      );
      expect(read.goal, 6);
      expect(read.goalRef?.name, 'charizard');
    });

    test('o registro guarda a forma caçada, uma pré-evolução', () async {
      final specimen = await backend.create(
        const SpecimenDraft(
          form: 6,
          isShiny: true,
          hunt: HuntRecord(method: 'masuda', huntedForm: 4),
        ),
      );
      expect(specimen.hunt?.huntedForm, 4);
      // A própria forma: nada.
      final own = await backend.create(
        const SpecimenDraft(
          form: 6,
          isShiny: true,
          hunt: HuntRecord(method: 'masuda', huntedForm: 6),
        ),
      );
      expect(own.hunt?.huntedForm, isNull);
      await expectLater(
        backend.create(
          const SpecimenDraft(
            form: 4,
            isShiny: true,
            hunt: HuntRecord(method: 'masuda', huntedForm: 6),
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
      final copy = FakeBackend.seeded()..replaceRecords(backend.records);
      expect((await copy.fetchSpecimen(specimen.id)).hunt?.huntedForm, 4);
    });
  });

  Future<void> pump(WidgetTester tester, Widget child) => pumpWidgetApp(
    tester,
    child,
    size: const Size(420, 2400),
    hunts: backend,
    overrides: [
      pngCapturerProvider.overrideWithValue(
        (_, _) async => Uint8List.fromList([1]),
      ),
      fakeBackendProvider.overrideWithValue(backend),
      clockProvider.overrideWithValue(() => _now),
      shinyMethodsProvider.overrideWithValue(
        (_, {fromGo = false, formId}) => _methods,
      ),
      huntableInProvider.overrideWithValue((_, _) => true),
    ],
  );

  testWidgets('Caçar: escolher a pré-evolução guarda o objetivo', (
    tester,
  ) async {
    ShinyHunt? started;
    await pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => started = await showHuntSheet(
              context,
              form: backend.formRefOf(6),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Caçar'), findsOne);
    for (final id in [4, 5, 6]) {
      expect(find.byKey(ValueKey('hunt-target-$id')), findsOne);
    }
    // A própria forma vem marcada, sem a dica.
    expect(find.textContaining('para ter'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('hunt-target-4')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Caçando Charmander para ter Charizard: os jogos e os métodos são '
        'os de Charmander.',
      ),
      findsOne,
    );
    await tester.ensureVisible(find.text('Começar').last);
    await tester.tap(find.text('Começar').last);
    await tester.pumpAndSettle();
    expect(started?.form, 4);
    expect(started?.goal, 6);
  });

  testWidgets('o cartão diz o objetivo; Encontrei! pergunta a forma', (
    tester,
  ) async {
    final hunt = await backend.saveShinyHunt(
      const ShinyHunt(id: 0, form: 4, goal: 6, method: 'masuda', unit: 'eggs'),
    );
    await pump(tester, const Scaffold(body: HuntCards(paused: false)));
    await tester.pumpAndSettle();
    expect(find.text('para Charizard'), findsOne);
    expect(find.byIcon(Icons.subdirectory_arrow_right), findsOne);

    Future<void> found() async {
      await tester.tap(find.byTooltip('Mais ações'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Encontrei!'));
      await tester.pumpAndSettle();
    }

    // Cancelar a pergunta não abre o cadastro.
    await found();
    expect(find.text('Em que forma ele está agora?'), findsOne);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byType(HuntCard), findsOne);

    // Charmeleon: o cadastro abre nele, caçado como Charmander.
    await found();
    await tester.tap(find.byKey(const ValueKey('current-form-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Forma caçada'), findsOne);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('field-hunted-form-4')))
          .selected,
      isTrue,
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    // A folha do card: "caçado como Charmander".
    expect(find.textContaining('caçado como Charmander'), findsWidgets);
    final saved = (await backend.fetchSpecimens(
      const SpecimenQuery(huntsOnly: true),
      page: 1,
      pageSize: 10,
    )).results.single;
    expect(saved.form, 5);
    expect(saved.hunt?.huntedForm, 4);
    expect(await backend.fetchShinyHunts(), isNot(contains(hunt)));
  });

  testWidgets('o registro e o card dizem caçado como', (tester) async {
    final specimen = await backend.create(
      const SpecimenDraft(
        form: 6,
        isShiny: true,
        hunt: HuntRecord(method: 'masuda', huntedForm: 4),
      ),
    );
    await pump(
      tester,
      Scaffold(
        body: HuntRecordCard(hunt: specimen.hunt!, specimen: specimen),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('hunted-as')), findsOne);
    expect(find.text('caçado como Charmander'), findsOne);
    expect(
      HuntShareData.of(specimen, huntedAs: 'Charmander')?.huntedAs,
      'Charmander',
    );
  });

  testWidgets('Concluídas: o item diz caçado como', (tester) async {
    final specimen = await backend.create(
      const SpecimenDraft(
        form: 6,
        isShiny: true,
        hunt: HuntRecord(method: 'masuda', huntedForm: 4),
      ),
    );
    await pump(tester, Scaffold(body: CompletedHuntTile(specimen: specimen)));
    await tester.pumpAndSettle();
    expect(find.textContaining('caçado como Charmander'), findsOne);
  });

  testWidgets('Forma caçada no registro direto: só com pré-evolução', (
    tester,
  ) async {
    HuntRecord? value = const HuntRecord(method: 'masuda');
    final forms = [backend.formRefOf(4)!, backend.formRefOf(6)!];
    await pump(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setState) => HuntRecordSection(
              value: value,
              methods: _methods,
              allMethods: _methods,
              forms: forms,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Forma caçada'), findsOne);
    await tester.tap(find.byKey(const ValueKey('field-hunted-form-4')));
    await tester.pumpAndSettle();
    expect(value?.huntedForm, 4);
    // De volta à própria forma: nada guardado.
    await tester.tap(find.byKey(const ValueKey('field-hunted-form-6')));
    await tester.pumpAndSettle();
    expect(value?.huntedForm, isNull);
  });
}
