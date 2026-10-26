import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/fake/fake_backend.dart';
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
  Locale locale = portuguese,
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
    locale: locale,
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
  of: find.ancestor(of: find.text(label), matching: find.byType(Wrap)).first,
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
      await tester.tap(find.text(ptText.removeAction));
      await tester.pumpAndSettle();

      await tapInSheet(tester, find.text('Natureza'));
      // Campos obrigatórios não têm "Remover".
      expect(find.text(ptText.removeAction), findsNothing);
      await tester.tap(find.text('Timid'));
      await tester.pumpAndSettle();

      await tapInSheet(tester, find.text('Idioma'));
      await tester.tap(find.text('Japonês'));
      await tester.pumpAndSettle();

      await tapInSheet(tester, find.text('Data de captura'));
      await tester.tap(find.text('Escolher data…'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.edit_outlined), findsNothing); // sem digitação
      // Dia 1 do mês atual: nunca está no futuro (o calendário vai até
      // hoje). Um dia fixo como 15 ficava desabilitado do dia 1 ao 14.
      await tester.tap(find.text('1').hitTestable().first);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tapInSheet(tester, find.widgetWithText(ChoiceChip, 'Fêmea'));
      await tapInSheet(tester, flag('Shiny', 'Não'));
      await tapInSheet(tester, flag('Alfa', 'Sim'));
      // A marca de origem escolhida (#360).
      await tapInSheet(tester, find.text('Marca de origem'));
      await tester.tap(find.text('PLA'));
      await tester.pumpAndSettle();

      expect(find.text('Revisar 9 alterações'), findsOneWidget);
      await tester.tap(find.text('Revisar 9 alterações'));
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
          capturedAt: SetTo(DateTime(now.year, now.month)),
          gender: const SetTo('female'),
          isShiny: const SetTo(false),
          isAlpha: const SetTo(true),
          markChoice: const SetTo('hisui'),
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
      await tester.tap(find.text(ptText.keepAction).last);
      await tester.pumpAndSettle();

      await tapInSheet(tester, find.text('Data de captura'));
      await tester.tap(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text(ptText.removeAction),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(ptText.removeAction), findsOneWidget);
      await tapInSheet(tester, find.text('Data de captura'));
      await tester.tap(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text(ptText.keepAction),
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
      await tapInSheet(
        tester,
        find.widgetWithText(ChoiceChip, ptText.keepAction),
      );
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
    await tapInSheet(tester, flag('Shiny', 'Sim'));
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
    expect(find.text(ptText.keepAction), findsNothing);
    expect(find.byType(ListTile), findsOneWidget);
    await tester.tap(find.text('Poké Ball'));
    await tester.pumpAndSettle();
    expect(results.single, const SetTo('poke-ball'));
  });

  group('confirmação', () {
    Future<List<bool>> pumpConfirm(
      WidgetTester tester,
      int count, {
      List<String> summary = const ['Pokébola → Dive Ball'],
      int alphaBlocked = 0,
      bool onlyAlpha = false,
      Size size = compactSize,
      Locale locale = portuguese,
    }) async {
      final results = <bool>[];
      await pumpWidgetApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await confirmBulkEdit(
                context,
                count: count,
                summary: summary,
                alphaBlocked: alphaBlocked,
                onlyAlpha: onlyAlpha,
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
        size: size,
        locale: locale,
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

    FilledButton apply(WidgetTester tester) => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Aplicar'),
    );

    testWidgets('alguns não podem ser alfa (#366)', (tester) async {
      await pumpConfirm(tester, 12, alphaBlocked: 3, onlyAlpha: true);
      expect(
        find.text(
          '3 dos 12 não podem ser alfa (marca de origem ou forma) e ficam '
          'como estão.',
        ),
        findsOneWidget,
      );
      expect(apply(tester).onPressed, isNotNull);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      await pumpConfirm(tester, 12, alphaBlocked: 1);
      expect(
        find.text(
          '1 dos 12 não pode ser alfa (marca de origem ou forma) e fica como '
          'está.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('nenhum pode: só o alfa desabilita "Aplicar"', (tester) async {
      await pumpConfirm(tester, 41, alphaBlocked: 41, onlyAlpha: true);
      expect(
        find.text(
          'Nenhum dos 41 pode ser alfa (marca de origem ou forma): nada vai '
          'mudar.',
        ),
        findsOneWidget,
      );
      expect(apply(tester).onPressed, isNull);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      await pumpConfirm(tester, 1, alphaBlocked: 1, onlyAlpha: true);
      expect(
        find.text(
          'O espécime não pode ser alfa (marca de origem ou forma): nada vai '
          'mudar.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('nenhum pode, com outras mudanças: elas valem', (tester) async {
      final results = await pumpConfirm(tester, 41, alphaBlocked: 41);
      expect(
        find.text(
          'Nenhum dos 41 pode ser alfa (marca de origem ou forma): as outras '
          'mudanças valem.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(results, [true]);

      await pumpConfirm(tester, 1, alphaBlocked: 1);
      expect(
        find.text(
          'O espécime não pode ser alfa (marca de origem ou forma): as outras '
          'mudanças valem.',
        ),
        findsOneWidget,
      );
    });

    // O pior caso real: o backup inteiro, seis mudanças, ~810 sem alfa.
    for (final size in [compactSize, expandedSize]) {
      testWidgets('pior caso (${size.width.toInt()}px)', (tester) async {
        final results = await pumpConfirm(
          tester,
          1161,
          size: size,
          alphaBlocked: 810,
          summary: const [
            'Pokébola → Strange Ball',
            'Natureza → Hardy',
            'Idioma → Inglês',
            'Data de captura → 24/10/2023',
            'Gênero → Fêmea',
            'Alfa → Sim',
          ],
        );
        expect(
          find.textContaining('810 dos 1161 não podem ser alfa'),
          findsOneWidget,
        );
        await tester.tap(find.text('Aplicar'));
        await tester.pumpAndSettle();
        expect(results, [true]);
      });
    }

    testWidgets('em inglês', (tester) async {
      await pumpConfirm(tester, 12, alphaBlocked: 3, locale: english);
      expect(
        find.text(
          "3 of the 12 can't be alpha (origin mark or form) and stay as they "
          'are.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await pumpConfirm(tester, 41, alphaBlocked: 41, locale: english);
      expect(
        find.text(
          'None of the 41 can be alpha (origin mark or form): the other '
          'changes still apply.',
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('em inglês: a folha e o resumo', (tester) async {
    await pumpSheet(tester, count: 2, locale: english);
    expect(find.text('Edit 2 specimens'), findsOneWidget);
    expect(find.text('Original trainer (OT)'), findsOneWidget);
    expect(find.text('Keep'), findsWidgets);
    expect(find.text('Yes'), findsWidgets);
    expect(find.text('Nothing changed'), findsOneWidget);
    await tapInSheet(tester, find.text('Yes').first);
    expect(find.text('Review 1 change'), findsOneWidget);
  });

  testWidgets('BulkLabels: resumo de todos os campos', (tester) async {
    late List<String> summary;
    await pumpWidgetApp(
      tester,
      Consumer(
        builder: (context, ref, _) {
          final labels = BulkLabels(
            context,
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
                markChoice: const SetTo('go'),
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
    );
    await tester.pumpAndSettle();
    expect(summary, [
      'Pokébola → ${ptText.removeAction}',
      'OT → Ash (123456)',
      'Natureza → Timid',
      'Idioma → Xx Yy',
      'Data de captura → 04/03/2026',
      'Gênero → Sem gênero',
      'Shiny → Sim',
      'Alfa → Não',
      'Marca de origem → GO',
      '#99',
      ptText.keepAction,
      ptText.keepAction,
      ptText.keepAction,
    ]);
  });
}
