import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/mark_icons.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/slot_detail_panel.dart';
import 'package:ishinydex/features/shiny_hunts/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/shiny_hunt_providers.dart';
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
    VoidCallback? onShowHunts,
  }) async {
    await pumpWidgetApp(
      tester,
      Scaffold(
        body: SlotDetailPanel(
          slot: slot,
          onDeposit: () {},
          onEdit: () {},
          onRelease: () {},
          onWithdraw: () {},
          onShowHunts: onShowHunts,
        ),
      ),
      size: size,
      hunts: backend,
      overrides: [
        specimenRepositoryProvider.overrideWithValue(backend),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 9, 12)),
      ],
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
      expect(find.text(maleEmoji), findsOneWidget);
      // Label vindo de /specimens/options/, no cartão de status (o chip
      // solto da natureza saiu).
      expect(find.textContaining('Natureza Adamant'), findsOneWidget);
      expect(find.byTooltip('Natureza'), findsNothing);
      // Marca de origem do GO (ícone + nome), no lugar do antigo 📱.
      expect(find.text('GO'), findsOneWidget);
      expect(find.byTooltip('Marca de origem: Pokémon GO'), findsOneWidget);
      expect(find.byType(GoIcon), findsNothing);
      // O ícone fica na mesma linha do nome.
      expect(
        tester.getCenter(find.text(maleEmoji)).dy,
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
      expect(find.text(femaleEmoji), findsOneWidget);
      // Fora das opções não se sabe o que a natureza muda: não aparece.
      expect(find.textContaining('Jolly'), findsNothing);
      expect(find.text('GO'), findsNothing);
      // Sem OT: sem jogo de origem, sem marca.
      expect(find.byTooltip(RegExp('^Marca de origem')), findsNothing);
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

      expect(find.text('SV'), findsOneWidget);
      expect(
        find.byTooltip('Marca de origem: Scarlet e Violet'),
        findsOneWidget,
      );
    });
  }

  testWidgets('sem gênero nem natureza: nada extra', (tester) async {
    final id = backend.addSpecimen(formId: 3, gender: 'genderless');
    await pump(tester, slotWith(id, formId: 3));

    expect(find.text('Registrado'), findsOneWidget);
    expect(find.text(maleEmoji), findsNothing);
    expect(find.text(femaleEmoji), findsNothing);
    expect(find.textContaining('Natureza'), findsNothing);
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

  group('caçada ativa da forma', () {
    Slot missing() => const Slot(
      id: 2,
      box: BoxRef(id: 1, name: 'HOME 1', position: 1),
      row: 0,
      col: 1,
      form: FormRef(
        id: 1,
        name: 'bulbasaur',
        pokeapiId: 1,
        spriteUrl: 'http://x/1.png',
        shinySpriteUrl: 'http://x/shiny/1.png',
      ),
    );

    testWidgets('no cronômetro: a linha com o tempo; tocar abre', (
      tester,
    ) async {
      await backend.saveShinyHunt(
        ShinyHunt(
          id: 0,
          form: 1,
          unit: 'hours',
          runningSince: DateTime(2026, 10, 9, 10, 30),
        ),
      );
      var opened = 0;
      await pump(tester, missing(), onShowHunts: () => opened++);
      expect(find.byKey(const ValueKey('hunt-badge')), findsOne);
      expect(find.text('1 h 30 min'), findsOne);
      await tester.ensureVisible(find.text('Caçada em andamento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Caçada em andamento'));
      expect(opened, 1);
    });

    testWidgets('pausada, fora de um shiny dex ou já shiny: sem a linha', (
      tester,
    ) async {
      await backend.saveShinyHunt(const ShinyHunt(id: 0, form: 1));
      await pump(tester, missing());
      expect(find.text('Caçada em andamento'), findsNothing);

      final shiny = missing().copyWith(
        specimen: const SpecimenSummary(id: 99, isShiny: true),
      );
      await pump(tester, shiny, onShowHunts: () {});
      expect(find.text('Caçada em andamento'), findsNothing);
    });
  });
}
