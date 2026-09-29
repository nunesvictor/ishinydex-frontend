import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/settings/data/date_format_storage.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/bulk_edit_sheet.dart';

import '../../helpers/helpers.dart';

List<Override> get _fakeOverrides => [
  envProvider.overrideWithValue(fakeEnv),
  fakeBackendProvider.overrideWithValue(FakeBackend.seeded()),
];

/// Monta um botão que abre a folha e guarda o que voltou.
Future<List<SpecimenChanges?>> pumpSheet(
  WidgetTester tester, {
  int count = 3,
  Size size = compactSize,
}) async {
  final results = <SpecimenChanges?>[];
  await pumpWidgetApp(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async =>
              results.add(await showBulkEditSheet(context, count)),
          child: const Text('abrir'),
        ),
      ),
    ),
    size: size,
    overrides: _fakeOverrides,
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return results;
}

/// Toca num item da folha, rolando até ele (nas duas direções).
Future<void> tapInSheet(WidgetTester tester, Finder finder) async {
  final list = find.byType(Scrollable).first;
  if (finder.hitTestable().evaluate().isEmpty) {
    // Volta ao topo (sem arrastar: arrastar para baixo fecharia a folha) e
    // desce até o item.
    tester.state<ScrollableState>(list).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(finder, 200, scrollable: list);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder flag(String label, String option) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
  matching: find.text(option),
);

void main() {
  group('compacto', () {
    testWidgets('monta as alterações de todos os campos', (tester) async {
      final results = await pumpSheet(tester);
      expect(find.text('Editar 3 espécimes'), findsOneWidget);
      expect(find.text('Nada alterado'), findsOneWidget);

      await tapInSheet(tester, find.text('Pokébola'));
      await tester.tap(find.text('Dream Ball'));
      await tester.pumpAndSettle();
      expect(find.text('Dream Ball'), findsOneWidget);

      await tapInSheet(tester, find.text('Treinador original (OT)'));
      await tester.tap(find.text(removeLabel));
      await tester.pumpAndSettle();

      await tapInSheet(tester, find.text('Natureza'));
      // Campos obrigatórios não têm "Remover".
      expect(find.text(removeLabel), findsNothing);
      await tester.tap(find.text('Timid'));
      await tester.pumpAndSettle();

      await tapInSheet(tester, find.text('Idioma'));
      await tester.tap(find.text('Japonês'));
      await tester.pumpAndSettle();

      await tapInSheet(tester, find.text('Data de captura'));
      await tester.tap(find.text('Escolher data…'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.edit_outlined), findsNothing); // sem digitação
      await tester.tap(find.text('15'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tapInSheet(tester, find.widgetWithText(ChoiceChip, 'Fêmea'));
      await tapInSheet(tester, flag('$shinyEmoji Shiny', 'Não'));
      await tapInSheet(tester, flag('$alphaEmoji Alfa', 'Sim'));
      await tapInSheet(tester, flag('$goEmoji GO', 'Sim'));
      await tapInSheet(tester, flag('$goEmoji GO', keepLabel));

      expect(find.text('Revisar 8 alterações'), findsOneWidget);
      await tester.tap(find.text('Revisar 8 alterações'));
      await tester.pumpAndSettle();
      final changes = results.single!;
      final now = DateTime.now();
      expect(
        changes,
        SpecimenChanges(
          pokeball: const SetTo('dream-ball'),
          ot: const SetTo(null),
          nature: const SetTo('timid'),
          language: const SetTo('ja'),
          capturedAt: SetTo(DateTime(now.year, now.month, 15)),
          gender: const SetTo('female'),
          isShiny: const SetTo(false),
          isAlpha: const SetTo(true),
        ),
      );
    });

    testWidgets('manter, busca, OT, limpar e fechar sem aplicar', (
      tester,
    ) async {
      final results = await pumpSheet(tester, count: 1);
      expect(find.text('Editar 1 espécime'), findsOneWidget);

      await tapInSheet(tester, find.text('Treinador original (OT)'));
      await tester.tap(find.text('Ash (123456) · Scarlet'));
      await tester.pumpAndSettle();
      expect(find.text('Ash (123456) · Scarlet'), findsOneWidget);
      // Voltar a "Manter".
      await tapInSheet(tester, find.text('Treinador original (OT)'));
      await tester.tap(find.text(keepLabel).last);
      await tester.pumpAndSettle();

      await tapInSheet(tester, find.text('Data de captura'));
      await tester.tap(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text(removeLabel),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(removeLabel), findsOneWidget);
      await tapInSheet(tester, find.text('Data de captura'));
      await tester.tap(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text(keepLabel),
        ),
      );
      await tester.pumpAndSettle();
      // Escolher data e cancelar o calendário não muda nada.
      await tapInSheet(tester, find.text('Data de captura'));
      await tester.tap(find.text('Escolher data…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      // Fechar o diálogo de data sem escolher.
      await tapInSheet(tester, find.text('Data de captura'));
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Nada alterado'), findsOneWidget);

      // Fechar o seletor sem escolher não muda nada.
      await tapInSheet(tester, find.text('Pokébola'));
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Nada alterado'), findsOneWidget);

      await tapInSheet(tester, find.widgetWithText(ChoiceChip, 'Macho'));
      await tapInSheet(tester, find.widgetWithText(ChoiceChip, keepLabel));
      await tapInSheet(tester, find.widgetWithText(ChoiceChip, 'Macho'));
      expect(find.text('Revisar 1 alteração'), findsOneWidget);
      await tester.tap(find.text('Limpar'));
      await tester.pumpAndSettle();
      expect(find.text('Nada alterado'), findsOneWidget);

      await tester.drag(find.text('Editar 1 espécime'), const Offset(0, 800));
      await tester.pumpAndSettle();
      expect(results, [null]);
    });
  });

  testWidgets('expandido: abre como diálogo', (tester) async {
    final results = await pumpSheet(tester, size: expandedSize);
    expect(find.byType(Dialog), findsOneWidget);
    await tapInSheet(tester, flag('$shinyEmoji Shiny', 'Sim'));
    await tester.tap(find.text('Revisar 1 alteração'));
    await tester.pumpAndSettle();
    expect(results.single, const SpecimenChanges(isShiny: SetTo(true)));
  });

  testWidgets('seletor com muitas opções tem busca', (tester) async {
    final results = <FieldEdit<String>?>[];
    await pumpWidgetApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => results.add(
            await showEditPicker(
              context,
              title: 'Natureza',
              current: const SetTo('n1'),
              choices: [
                for (var i = 0; i < 7; i++) Choice(value: 'n$i', label: 'N$i'),
                const Choice(
                  value: 'poke-ball',
                  label: 'Poké Ball',
                  spriteUrl: 'http://x/poke-ball.png',
                ),
              ],
            ),
          ),
          child: const Text('abrir'),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ListTile>(find.widgetWithText(ListTile, 'N1')).selected,
      true,
    );
    await tester.enterText(find.widgetWithText(TextField, 'Buscar'), 'poke');
    await tester.pump();
    // Buscando, "Manter" some e só sobram as opções que batem.
    expect(find.text(keepLabel), findsNothing);
    expect(find.byType(ListTile), findsOneWidget);
    await tester.tap(find.text('Poké Ball'));
    await tester.pumpAndSettle();
    expect(results.single, const SetTo('poke-ball'));
  });

  group('confirmação', () {
    Future<List<bool>> pumpConfirm(WidgetTester tester, int count) async {
      final results = <bool>[];
      await pumpWidgetApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await confirmBulkEdit(
                context,
                count: count,
                summary: const ['Pokébola → Dive Ball'],
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      return results;
    }

    testWidgets('aplicar, cancelar e fechar', (tester) async {
      final results = await pumpConfirm(tester, 54);
      expect(find.text('Alterar 54 espécimes?'), findsOneWidget);
      expect(find.text('• Pokébola → Dive Ball'), findsOneWidget);
      expect(find.text('Não é possível desfazer.'), findsOneWidget);
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(results, [true, false, false]);
    });

    testWidgets('singular', (tester) async {
      await pumpConfirm(tester, 1);
      expect(find.text('Alterar 1 espécime?'), findsOneWidget);
    });
  });

  testWidgets('BulkLabels: resumo de todos os campos', (tester) async {
    late List<String> summary;
    await pumpWidgetApp(
      tester,
      Consumer(
        builder: (context, ref, _) {
          final labels = BulkLabels(
            context,
            ref,
            FakeBackend.seeded().options,
            const [Trainer(id: 1, name: 'Ash', trainerId: '123456')],
          );
          summary = [
            ...labels.summary(
              SpecimenChanges(
                pokeball: const SetTo(null),
                ot: const SetTo(1),
                nature: const SetTo('timid'),
                language: const SetTo('xx-yy'),
                capturedAt: SetTo(DateTime(2026, 3, 4)),
                gender: const SetTo('genderless'),
                isShiny: const SetTo(true),
                isAlpha: const SetTo(false),
                isFromGo: const SetTo(true),
              ),
            ),
            labels.ot(const SetTo(99)),
            labels.ot(const Keep()),
            labels.capturedAt(const Keep()),
            labels.pokeball(const Keep()),
          ];
          return const SizedBox();
        },
      ),
      dateFormat: InMemoryDateFormatStorage(CaptureDateFormat.home),
    );
    await tester.pumpAndSettle();
    expect(summary, [
      'Pokébola → $removeLabel',
      'OT → Ash (123456)',
      'Natureza → Timid',
      'Idioma → Xx Yy',
      'Data de captura → 03/04/2026',
      'Gênero → Sem gênero',
      'Shiny → Sim',
      'Alfa → Não',
      'GO → Sim',
      '#99',
      keepLabel,
      keepLabel,
      keepLabel,
    ]);
  });
}
