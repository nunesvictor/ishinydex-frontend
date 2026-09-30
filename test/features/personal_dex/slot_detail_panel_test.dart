import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/slot_detail_panel.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

import '../../helpers/helpers.dart';

void main() {
  late FakeBackend backend;

  setUp(() {
    backend = FakeBackend()
      ..addForm(id: 1, name: 'bulbasaur')
      ..addForm(id: 2, name: 'nidoran-f', genderRate: 8)
      ..addForm(id: 3, name: 'magnemite', genderRate: -1);
  });

  /// Slot registrado com o resumo do specimen [specimenId], como vem da API.
  Slot slotWith(int specimenId, {int formId = 1}) => Slot(
    id: 1,
    box: const BoxRef(id: 1, name: 'HOME 1', position: 1),
    row: 0,
    col: 0,
    form: FormRef(
      id: formId,
      name: 'forma-$formId',
      pokeapiId: formId,
      spriteUrl: 'http://x/$formId.png',
      shinySpriteUrl: 'http://x/shiny/$formId.png',
    ),
    specimen: SpecimenSummary(id: specimenId, nickname: 'Bulba'),
  );

  Future<void> pump(
    WidgetTester tester,
    Slot slot, {
    Size size = compactSize,
  }) async {
    await pumpWidgetApp(
      tester,
      Scaffold(
        body: SlotDetailPanel(
          slot: slot,
          onDeposit: () {},
          onEdit: () {},
          onRelease: () {},
        ),
      ),
      size: size,
      overrides: [specimenRepositoryProvider.overrideWithValue(backend)],
    );
    await tester.pumpAndSettle();
  }

  for (final size in [compactSize, expandedSize]) {
    testWidgets('gênero ao lado do nome, natureza e marca do GO '
        '(${size.width.toInt()}px)', (tester) async {
      final id = backend.addSpecimen(
        formId: 1,
        gender: 'male',
        nature: 'adamant',
        isFromGo: true,
      );
      await pump(tester, slotWith(id), size: size);

      expect(find.bySemanticsLabel('Macho'), findsOneWidget);
      expect(find.byIcon(Icons.male), findsOneWidget);
      // Label vindo de /specimens/options/, com o tooltip explicando o chip.
      expect(find.text('Adamant'), findsOneWidget);
      expect(find.byTooltip('Natureza'), findsOneWidget);
      // Marca de origem do GO (ícone + nome), no lugar do antigo 📱.
      expect(find.text('Pokémon GO'), findsOneWidget);
      expect(find.byTooltip('Marca de origem'), findsOneWidget);
      expect(find.bySemanticsLabel('Pokémon GO'), findsOneWidget);
      expect(find.text(goEmoji), findsNothing);
      // O ícone fica na mesma linha do nome.
      expect(
        tester.getCenter(find.byIcon(Icons.male)).dy,
        moreOrLessEquals(tester.getCenter(find.text('Bulba')).dy, epsilon: 2),
      );
    });

    testWidgets('fêmea e natureza fora das opções '
        '(${size.width.toInt()}px)', (tester) async {
      final id = backend.addSpecimen(
        formId: 2,
        gender: 'female',
        nature: 'jolly',
      );
      await pump(tester, slotWith(id, formId: 2), size: size);

      expect(find.bySemanticsLabel('Fêmea'), findsOneWidget);
      expect(find.byIcon(Icons.female), findsOneWidget);
      expect(find.text('Jolly'), findsOneWidget);
      expect(find.text('Pokémon GO'), findsNothing);
      // Sem OT: sem jogo de origem, sem marca.
      expect(find.byTooltip('Marca de origem'), findsNothing);
    });

    testWidgets('marca de origem derivada do OT '
        '(${size.width.toInt()}px)', (tester) async {
      final ot = backend.addTrainer(
        name: 'Ash',
        trainerId: '1',
        version: 'violet',
      );
      final id = backend.addSpecimen(formId: 1, ot: ot);
      await pump(tester, slotWith(id), size: size);

      expect(find.text('Scarlet e Violet'), findsOneWidget);
      expect(find.byTooltip('Marca de origem'), findsOneWidget);
    });
  }

  testWidgets('sem gênero nem natureza: nada extra', (tester) async {
    final id = backend.addSpecimen(formId: 3, gender: 'genderless');
    await pump(tester, slotWith(id, formId: 3));

    expect(find.text('Registrado'), findsOneWidget);
    expect(find.byIcon(Icons.male), findsNothing);
    expect(find.byIcon(Icons.female), findsNothing);
    expect(find.byTooltip('Natureza'), findsNothing);
  });

  testWidgets('falha ao carregar o specimen: resumo e ações continuam', (
    tester,
  ) async {
    // Specimen inexistente no fake: GET /specimens/{id}/ dá 404.
    await pump(tester, slotWith(999));

    expect(find.text('Registrado'), findsOneWidget);
    expect(find.text('Bulba'), findsOneWidget);
    expect(find.text('Editar espécime'), findsOneWidget);
    expect(find.byTooltip('Natureza'), findsNothing);
  });
}
