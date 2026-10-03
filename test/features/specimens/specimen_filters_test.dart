import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/settings/data/date_format_storage.dart';
import 'package:ishinydex/features/settings/settings_providers.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/specimen_filters.dart';

import '../../helpers/helpers.dart';

/// Monta um botão que abre os filtros e guarda o que voltou.
Future<List<SpecimenQuery?>> pumpFilters(
  WidgetTester tester, {
  SpecimenQuery initial = emptySpecimenQuery,
  Size size = compactSize,
}) async {
  final results = <SpecimenQuery?>[];
  await pumpWidgetApp(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async =>
              results.add(await showSpecimenFilters(context, initial)),
          child: const Text('abrir'),
        ),
      ),
    ),
    size: size,
    overrides: [
      envProvider.overrideWithValue(fakeEnv),
      fakeBackendProvider.overrideWithValue(FakeBackend.seeded()),
    ],
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return results;
}

/// Toca numa linha da folha (rolando até ela, se preciso; [delta]
/// negativo rola para cima).
Future<void> tapInSheet(
  WidgetTester tester,
  Finder finder, {
  double delta = 200,
}) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find.byType(Scrollable).first,
  );
  // Inteiro na área visível: na borda, o toque cairia no rodapé.
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Marca opções no seletor e confirma.
Future<void> pick(WidgetTester tester, List<String> labels) async {
  for (final label in labels) {
    await tester.tap(find.widgetWithText(CheckboxListTile, label));
    await tester.pump();
  }
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  group('compacto', () {
    testWidgets('monta a consulta com todos os filtros', (tester) async {
      final results = await pumpFilters(tester);
      expect(find.text('Filtros'), findsOneWidget);
      // Nada ativo: "Limpar" desabilitado.
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Limpar'))
            .onPressed,
        isNull,
      );

      await tapInSheet(tester, find.text('Ordenar por'));
      await tester.tap(find.text('Capturados recentemente'));
      await tester.pumpAndSettle();
      expect(find.text('Capturados recentemente'), findsOneWidget);

      await tapInSheet(tester, find.text('Pokébola'));
      await pick(tester, ['Sem pokébola', 'Dream Ball']);
      expect(find.text('Sem pokébola +1'), findsOneWidget);

      await tapInSheet(tester, find.text('Treinador original (OT)'));
      await pick(tester, ['Sem OT', 'Ash (123456) · Scarlet']);
      expect(find.text('Sem OT +1'), findsOneWidget);

      await tapInSheet(tester, find.text('Natureza'));
      // Poucas opções: sem busca.
      expect(find.widgetWithText(TextField, 'Buscar'), findsNothing);
      await pick(tester, ['Modest']);
      expect(find.text('Modest'), findsOneWidget);

      await tapInSheet(tester, find.text('Idioma'));
      await pick(tester, ['Japonês']);

      // Tipos: no máximo dois; o terceiro fica desabilitado.
      await tapInSheet(tester, find.widgetWithText(FilterChip, 'Fogo'));
      await tapInSheet(tester, find.widgetWithText(FilterChip, 'Voador'));
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Água'))
            .onSelected,
        isNull,
      );
      // Desmarcar libera de novo.
      await tapInSheet(tester, find.widgetWithText(FilterChip, 'Voador'));
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Água'))
            .onSelected,
        isNotNull,
      );
      await tapInSheet(tester, find.widgetWithText(FilterChip, 'Voador'));

      // Categoria: qualquer uma das marcadas, como nas caçadas.
      await tapInSheet(tester, find.widgetWithText(FilterChip, 'Lendário'));
      await tapInSheet(tester, find.widgetWithText(FilterChip, 'Ultra Beast'));
      await tapInSheet(tester, find.widgetWithText(FilterChip, 'I'));
      // Marca de origem: chip com o ícone da marca; "sem marca", sem ícone.
      final paldea = find.widgetWithText(FilterChip, 'SV');
      expect(find.byTooltip('Scarlet e Violet'), findsOneWidget);
      await tapInSheet(tester, paldea);
      expect(
        find.descendant(of: paldea, matching: find.byType(Image)),
        findsOneWidget,
      );
      final noMark = find.widgetWithText(FilterChip, 'Sem marca de origem');
      await tapInSheet(tester, noMark);
      expect(
        find.descendant(of: noMark, matching: find.byType(Image)),
        findsNothing,
      );
      await tapInSheet(tester, find.widgetWithText(FilterChip, 'GO'));
      await tapInSheet(tester, find.widgetWithText(FilterChip, 'GO'));
      await tapInSheet(tester, find.widgetWithText(FilterChip, 'Fêmea'));

      await tester.scrollUntilVisible(
        find.widgetWithText(TextField, 'Habilidade'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Habilidade'),
        'keen',
      );

      // Sem intervalo: o calendário abre no mês atual; fechar não muda nada.
      await tapInSheet(tester, find.text('Data de captura'));
      // O cabeçalho do calendário do Material ("Data de início – …") estoura
      // só na fonte de teste (Ahem: todo caractere tem a largura da fonte).
      // Com fonte real, o texto de término é Flexible e vira reticências.
      expect(
        tester.takeException(),
        isA<FlutterError>().having(
          (e) => e.message,
          'message',
          contains('overflowed'),
        ),
      );
      expect(find.byIcon(Icons.edit_outlined), findsNothing); // sem digitação
      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();
      expect(find.text('Qualquer data'), findsOneWidget);

      await tester.tap(find.text('Mostrar resultados'));
      await tester.pumpAndSettle();
      expect(
        results.single,
        const SpecimenQuery(
          ordering: SpecimenOrdering.capturedDesc,
          pokeballs: ['dream-ball'],
          withoutPokeball: true,
          ots: [1],
          withoutOt: true,
          natures: ['modest'],
          languages: ['ja'],
          types: ['fire', 'flying'],
          generations: ['generation-i'],
          categories: [SpeciesCategory.legendary, SpeciesCategory.ultraBeast],
          originMarks: ['paldea', 'none'],
          genders: ['female'],
          ability: 'keen',
        ),
      );
    });

    testWidgets('limpar, cancelar seletores e fechar sem aplicar', (
      tester,
    ) async {
      final initial = SpecimenQuery(
        shinyOnly: true,
        pokeballs: const ['poke-ball'],
        ability: 'blaze',
        capturedAfter: DateTime(2026, 1, 2),
        capturedBefore: DateTime(2026, 1, 5),
      );
      final results = await pumpFilters(tester, initial: initial);
      expect(find.text('Poké Ball'), findsOneWidget);

      // Cancelar o seletor não muda nada; "Nenhum" desmarca tudo.
      await tapInSheet(tester, find.text('Pokébola'));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Dream Ball'));
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Poké Ball'), findsOneWidget);
      await tapInSheet(tester, find.text('Pokébola'));
      await tester.tap(find.text('Nenhum'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Todas'), findsNWidgets(2)); // pokébola e natureza

      // Fechar a escolha de ordem sem escolher não muda nada.
      await tapInSheet(tester, find.text('Ordenar por'), delta: -200);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Ordem das boxes'), findsOneWidget);

      // Intervalo já definido: o calendário abre nele. Escolher outro
      // intervalo (10 a 20/01) aparece no formato dos Ajustes (mm/dd).
      await tapInSheet(tester, find.text('Data de captura'));
      await tester.tap(find.text('10').hitTestable().first);
      await tester.tap(find.text('20').hitTestable().first);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('01/10/2026 – 01/20/2026'), findsOneWidget);
      await tester.tap(find.byTooltip('Limpar datas'));
      await tester.pumpAndSettle();
      expect(find.text('Qualquer data'), findsOneWidget);

      await tester.tap(find.text('Limpar'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Habilidade'))
            .controller!
            .text,
        isEmpty,
      );

      // Arrastar a folha para baixo fecha sem aplicar.
      await tester.drag(find.text('Filtros'), const Offset(0, 800));
      await tester.pumpAndSettle();
      expect(results, [null]);
    });
  });

  testWidgets('expandido: abre como diálogo', (tester) async {
    final results = await pumpFilters(tester, size: expandedSize);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    await tapInSheet(tester, find.widgetWithText(FilterChip, 'Macho'));
    await tapInSheet(tester, find.widgetWithText(FilterChip, 'Macho'));
    await tapInSheet(tester, find.widgetWithText(FilterChip, 'Sem gênero'));
    await tester.tap(find.text('Mostrar resultados'));
    await tester.pumpAndSettle();
    expect(results.single, const SpecimenQuery(genders: ['genderless']));
  });

  testWidgets('seletor com muitas opções tem busca sem acentos', (
    tester,
  ) async {
    final results = <Set<String>?>[];
    await pumpWidgetApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => results.add(
            await showChoicePicker(
              context,
              title: 'Natureza',
              choices: [
                for (var i = 0; i < 7; i++) Choice(value: 'n$i', label: 'N$i'),
                const Choice(value: 'poke-ball', label: 'Poké Ball'),
              ],
              selected: const {'n0'},
            ),
          ),
          child: const Text('abrir'),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Buscar'), 'poke');
    await tester.pump();
    expect(find.byType(CheckboxListTile), findsOneWidget);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Poké Ball'));
    await tester.enterText(find.widgetWithText(TextField, 'Buscar'), '');
    await tester.pump();
    // Desmarcar uma opção já escolhida.
    await pick(tester, ['N0']);
    expect(results.single, {'poke-ball'});
  });

  group('ActiveFilterChips', () {
    Future<List<SpecimenQuery>> pumpChips(
      WidgetTester tester,
      SpecimenQuery query,
    ) async {
      final changes = <SpecimenQuery>[];
      await pumpWidgetApp(
        tester,
        Scaffold(
          body: ActiveFilterChips(query: query, onChanged: changes.add),
        ),
        overrides: [
          envProvider.overrideWithValue(fakeEnv),
          fakeBackendProvider.overrideWithValue(FakeBackend.seeded()),
        ],
        dateFormat: InMemoryDateFormatStorage(CaptureDateFormat.home),
      );
      await tester.pumpAndSettle();
      return changes;
    }

    testWidgets('sem filtro avançado não ocupa espaço', (tester) async {
      await pumpChips(tester, const SpecimenQuery(shinyOnly: true));
      expect(find.byType(InputChip), findsNothing);
    });

    testWidgets('um chip por filtro; o X limpa só aquele', (tester) async {
      final query = SpecimenQuery(
        ordering: SpecimenOrdering.createdDesc,
        pokeballs: const ['dream-ball'],
        types: const ['fire', 'flying'],
        ots: const [2, 99],
        generations: const ['generation-i', 'generation-iv'],
        categories: const [SpeciesCategory.legendary, SpeciesCategory.baby],
        originMarks: const ['go', 'none'],
        genders: const ['female'],
        natures: const ['modest', 'timid'],
        languages: const ['ja'],
        ability: ' keen ',
        capturedAfter: DateTime(2026, 3, 4),
      );
      final changes = await pumpChips(tester, query);
      final expected = {
        'Cadastrados recentemente': query.copyWith(
          ordering: SpecimenOrdering.box,
        ),
        'Dream Ball': query.copyWith(pokeballs: const []),
        'Fogo / Voador': query.copyWith(types: const []),
        'OT: Ash +1': query.copyWith(ots: const []),
        'Geração I, IV': query.copyWith(generations: const []),
        'Lendário +1': query.copyWith(categories: const []),
        'Origem: GO +1': query.copyWith(originMarks: const []),
        'Fêmea': query.copyWith(genders: const []),
        'Modest +1': query.copyWith(natures: const []),
        'Japonês': query.copyWith(languages: const []),
        'Habilidade: keen': query.copyWith(ability: ''),
        'Desde 03/04/2026': query.copyWith(capturedAfter: null),
      };
      for (final label in expected.keys) {
        final chip = find.widgetWithText(InputChip, label);
        await tester.scrollUntilVisible(
          chip,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        // Chip inteiro na tela: o X de um chip largo pode ficar de fora.
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(of: chip, matching: find.byIcon(Icons.clear)),
        );
        await tester.pump();
      }
      expect(changes, [...expected.values]);
    });
  });

  test('helpers de texto', () {
    const choices = [Choice(value: 'poke-ball', label: 'Poké Ball')];
    expect(labelsOf(['poke-ball', 'safari-ball'], choices), [
      'Poké Ball',
      'Safari Ball',
    ]);
    expect(summarize([]), isNull);
    expect(summarize(['A']), 'A');
    expect(summarize(['A', 'B', 'C']), 'A +2');
    expect(generationNumber('generation-viii'), 'VIII');
    final pattern = CaptureDatePattern(CaptureDateFormat.home, 'pt_BR');
    final a = DateTime(2026, 1, 2);
    final b = DateTime(2026, 3, 4);
    expect(captureRangeLabel(pattern, a, b), '01/02/2026 – 03/04/2026');
    expect(captureRangeLabel(pattern, a, null), 'Desde 01/02/2026');
    expect(captureRangeLabel(pattern, null, b), 'Até 03/04/2026');
    expect(captureRangeLabel(pattern, null, null), '');
  });
}
