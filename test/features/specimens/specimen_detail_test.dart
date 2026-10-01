import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/network/paginated.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_detail.dart';
import 'package:ishinydex/features/specimens/presentation/specimens_page.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/form_picker.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/api_fixtures.dart';
import '../../helpers/helpers.dart';
import '../../helpers/mocks.dart';

/// specimenJson: bulbasaur depositado no slot 1, com habilidade, natureza,
/// gênero, idioma, OT 7 e data de captura.
final _specimen = Specimen.fromJson({
  ...specimenJson,
  'observation': 'Pego no safári',
  'is_from_go': true,
  'origin_mark': 'go',
});

void main() {
  late MockSpecimenRepository specimens;
  late MockPersonalDexRepository dexes;

  setUpAll(() => registerFallbackValue(emptySpecimenQuery));

  setUp(() {
    specimens = MockSpecimenRepository();
    dexes = MockPersonalDexRepository();
    when(() => specimens.fetchSpecimen(1)).thenAnswer((_) async => _specimen);
    when(specimens.fetchOptions)
        .thenAnswer((_) async => SpecimenOptions.fromJson(optionsJson));
    when(specimens.fetchTrainers).thenAnswer(
      (_) async => const [
        Trainer(id: 7, name: 'Ash', trainerId: '123456', version: 'scarlet'),
      ],
    );
  });

  Future<List<String>> pumpDetail(
    WidgetTester tester, {
    // Alta o bastante para os botões no fim do detalhe caberem na tela.
    Size size = const Size(400, 1600),
  }) async {
    final released = <String>[];
    await pumpWidgetApp(
      tester,
      Scaffold(
        body: SpecimenDetailView(
          specimenId: 1,
          onReleased: () => released.add('ok'),
        ),
      ),
      size: size,
      overrides: [
        specimenRepositoryProvider.overrideWithValue(specimens),
        personalDexRepositoryProvider.overrideWithValue(dexes),
      ],
    );
    await tester.pumpAndSettle();
    return released;
  }

  group('SpecimenDetailView', () {
    for (final size in [compactSize, expandedSize]) {
      testWidgets('mostra os campos com os rótulos da API '
          '(${size.width.toInt()}px)', (tester) async {
        await pumpDetail(tester, size: size);
        // Rótulos das opções (quando a API os tem) ou nome formatado.
        expect(find.text('Overgrow'), findsOneWidget);
        expect(find.text('Naughty'), findsOneWidget); // fora das opções
        expect(find.text('Macho'), findsOneWidget);
        expect(find.text('En'), findsOneWidget);
        expect(find.text('Ash (123456) · Scarlet'), findsOneWidget);
        // Data com ano (o formato "médio" do Material em pt-BR omite o ano).
        expect(find.text('23/09/2024'), findsOneWidget);
        expect(find.text('Pego no safári'), findsOneWidget);
        expect(find.text('Bulbasaur · #0001'), findsOneWidget);
        // Cabeçalho: nome e selos em emoji, na mesma linha.
        expect(find.text('Bulbasaur'), findsOneWidget);
        expect(find.text(shinyEmoji), findsOneWidget);
        expect(find.text(goEmoji), findsOneWidget);
        expect(find.text(maleEmoji), findsOneWidget);
        expect(
          tester.getCenter(find.text(shinyEmoji)).dy,
          moreOrLessEquals(
            tester.getCenter(find.text('Bulbasaur')).dy,
            epsilon: 2,
          ),
        );
        // Marca de origem: GO tem prioridade (o backend manda "go").
        expect(find.text('GO'), findsOneWidget);
        expect(find.byTooltip('Marca de origem: Pokémon GO'), findsOneWidget);
      });
    }

    testWidgets('erro ao carregar com retry', (tester) async {
      var calls = 0;
      when(() => specimens.fetchSpecimen(1)).thenAnswer((_) async {
        if (calls++ == 0) throw const NotFoundFailure();
        return _specimen;
      });
      await pumpDetail(tester);
      expect(find.text(const NotFoundFailure().message), findsOneWidget);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text('Ver no dex'), findsOneWidget);
    });

    testWidgets('ver no dex: slot sem dex e falha da API', (tester) async {
      final slot = Slot.fromJson(registeredSlotJson);
      var calls = 0;
      when(() => dexes.fetchSlot(1)).thenAnswer((_) async {
        if (calls++ == 0) return slot.copyWith(personalDex: null);
        throw const NetworkFailure();
      });
      await pumpDetail(tester);

      await tester.tap(find.text('Ver no dex'));
      await tester.pumpAndSettle();
      expect(
        find.text('O slot deste espécime não pertence a um dex.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Ver no dex'));
      await tester.pumpAndSettle();
      expect(find.text(const NetworkFailure().message), findsOneWidget);
    });

    testWidgets('falha ao libertar mantém o espécime', (tester) async {
      when(() => specimens.release(1))
          .thenThrow(ValidationFailure(const {}, detail: 'Não pode.'));
      final released = await pumpDetail(tester);
      await tester.tap(find.text('Libertar'));
      await tester.pumpAndSettle();
      // Depositado: o aviso fala do slot.
      expect(find.textContaining('slot ficará faltante'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Libertar'));
      await tester.pumpAndSettle();
      expect(find.text('Não pode.'), findsOneWidget);
      expect(released, isEmpty);
    });

    testWidgets('sem formRef não oferece editar', (tester) async {
      when(() => specimens.fetchSpecimen(1))
          .thenAnswer((_) async => const Specimen(id: 1, form: 1));
      await pumpDetail(tester);
      expect(find.text('Editar espécime'), findsNothing);
      expect(find.text('Disponível'), findsOneWidget);
    });
  });

  group('SpecimenList', () {
    Specimen numbered(int id) => Specimen(id: id, form: 1, nickname: 'S$id');

    Future<void> pumpList(WidgetTester tester) => pumpWidgetApp(
      tester,
      Scaffold(
        body: SpecimenList(query: emptySpecimenQuery, onTap: (_) {}),
      ),
      size: const Size(400, 4000), // altura para montar as duas páginas
      overrides: [specimenRepositoryProvider.overrideWithValue(specimens)],
    );

    testWidgets('erro na 1ª página com retry', (tester) async {
      var calls = 0;
      when(
        () => specimens.fetchSpecimens(
          any(),
          page: 1,
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) async {
        if (calls++ == 0) throw const NetworkFailure();
        return const Paginated(count: 0, results: []);
      });
      await pumpList(tester);
      await tester.pumpAndSettle();
      expect(find.text(const NetworkFailure().message), findsOneWidget);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhum espécime encontrado.'), findsOneWidget);
    });

    testWidgets('erro numa página seguinte aparece uma vez, com retry', (
      tester,
    ) async {
      when(
        () => specimens.fetchSpecimens(
          any(),
          page: 1,
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer(
        (_) async => Paginated(
          count: 23,
          next: 'page=2',
          results: [for (var i = 1; i <= 20; i++) numbered(i)],
        ),
      );
      var calls = 0;
      when(
        () => specimens.fetchSpecimens(
          any(),
          page: 2,
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) async {
        if (calls++ == 0) throw const NetworkFailure();
        // Encolheu entre as páginas: só 1 dos 3 itens esperados.
        return Paginated(count: 21, results: [numbered(21)]);
      });
      await pumpList(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('Não foi possível carregar mais espécimes.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text('S21'), findsOneWidget);
      expect(find.byType(SpecimenListTile), findsNWidgets(21));
    });
  });

  testWidgets('FormPicker: erro na busca com retry e sem resultados', (
    tester,
  ) async {
    var calls = 0;
    when(() => specimens.searchForms('xy')).thenAnswer((_) async {
      if (calls++ == 0) throw const ServerFailure();
      return const [];
    });
    await pumpWidgetApp(
      tester,
      const Scaffold(body: FormPicker()),
      overrides: [specimenRepositoryProvider.overrideWithValue(specimens)],
    );
    await tester.enterText(find.byType(TextField), 'xy');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text(const ServerFailure().message), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma forma encontrada.'), findsOneWidget);
  });
}
