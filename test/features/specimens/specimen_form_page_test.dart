import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_form_page.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/api_fixtures.dart';
import '../../helpers/helpers.dart';
import '../../helpers/mocks.dart';

final _form = FormRef.fromJson(
  registeredSlotJson['form'] as Map<String, dynamic>,
);

void main() {
  late MockSpecimenRepository repository;

  setUpAll(() => registerFallbackValue(const SpecimenDraft(form: 0)));

  setUp(() {
    repository = MockSpecimenRepository();
    when(() => repository.fetchForm(1))
        .thenAnswer((_) async => FormDetail.fromJson(formDetailJson));
    when(repository.fetchOptions)
        .thenAnswer((_) async => SpecimenOptions.fromJson(optionsJson));
    when(repository.fetchTrainers).thenAnswer(
      (_) async => const [Trainer(id: 12, name: 'Ash', trainerId: '123456')],
    );
  });

  Future<List<Specimen?>> pumpForm(
    WidgetTester tester, {
    int? specimenId,
    Size size = const Size(600, 1600),
  }) async {
    final results = <Specimen?>[];
    await pumpWidgetApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => results.add(
            await Navigator.of(context).push<Specimen>(
              MaterialPageRoute(
                builder: (_) => SpecimenFormPage(
                  form: _form,
                  specimenId: specimenId,
                  initialShiny: true,
                ),
              ),
            ),
          ),
          child: const Text('abrir'),
        ),
      ),
      size: size,
      overrides: [specimenRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.tap(find.text('abrir'));
    await tester.pump();
    return results;
  }

  Future<void> choose(WidgetTester tester, String field, String label) async {
    await tester.tap(find.byKey(ValueKey('field-$field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('preenche tudo e salva', (tester) async {
    when(() => repository.create(any())).thenAnswer(
      (invocation) async => Specimen(
        id: 99,
        form: (invocation.positionalArguments.first as SpecimenDraft).form,
      ),
    );
    final results = await pumpForm(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, ' Bulba ');
    await choose(tester, 'ability', 'Chlorophyll (oculta)');
    await choose(tester, 'gender', 'Macho');
    await choose(tester, 'nature', 'Adamant');
    await choose(tester, 'language', 'Português brasileiro');
    await choose(tester, 'pokeball', 'Poké Ball');
    await choose(tester, 'ot', 'Ash (123456)');
    await choose(tester, 'ot', '—');
    await choose(tester, 'ot', 'Ash (123456)');
    await tester.tap(find.text('Shiny'));
    await tester.tap(find.text('Alfa'));
    await tester.tap(find.text('Veio do Pokémon GO'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'obs');

    await tester.tap(find.text('Data de captura'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Não informada'), findsNothing);
    // Cancelar o seletor mantém a data.
    await tester.tap(find.text('Data de captura'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salvar e depositar'));
    await tester.pumpAndSettle();
    final draft =
        verify(() => repository.create(captureAny())).captured.single
            as SpecimenDraft;
    expect(draft.nickname, 'Bulba');
    expect(draft.ability, 'chlorophyll');
    expect(draft.gender, 'male');
    expect(draft.ot, 12);
    expect(draft.isShiny, false);
    expect(draft.isAlpha, true);
    expect(draft.isFromGo, true);
    expect(draft.capturedAt, isNotNull);
    expect(draft.observation, 'obs');
    expect(results.single!.id, 99);
  });

  testWidgets('erro de validação aparece no campo', (tester) async {
    when(() => repository.create(any())).thenThrow(
      ValidationFailure({
        'nickname': ['Apelido muito longo.'],
      }),
    );
    await pumpForm(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar e depositar'));
    await tester.pumpAndSettle();
    expect(find.text('Apelido muito longo.'), findsNWidgets(2));
  });

  testWidgets('falha de rede mostra mensagem geral', (tester) async {
    when(() => repository.create(any())).thenThrow(const NetworkFailure());
    await pumpForm(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar e depositar'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text(const NetworkFailure().message), findsOneWidget);
  });

  testWidgets('forma shiny-locked e erro de carregamento com retry', (
    tester,
  ) async {
    var calls = 0;
    when(() => repository.fetchForm(1)).thenAnswer((_) async {
      if (calls++ == 0) throw const ServerFailure();
      return FormDetail.fromJson({...formDetailJson, 'is_shinylocked': true});
    });
    await pumpForm(tester);
    await tester.pumpAndSettle();
    expect(find.text(const ServerFailure().message), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Atenção: esta forma é shiny-locked.'), findsOneWidget);
  });

  testWidgets('erro nas opções ou treinadores também vira ErrorView', (
    tester,
  ) async {
    when(repository.fetchOptions).thenThrow(const ServerFailure());
    await pumpForm(tester);
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('erro nos treinadores', (tester) async {
    when(repository.fetchTrainers).thenThrow(const ServerFailure());
    await pumpForm(tester);
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  group('edição', () {
    final existing = Specimen.fromJson({
      ...specimenJson,
      'nickname': 'Bulba',
      'observation': 'obs antiga',
    });

    for (final size in [compactSize, expandedSize]) {
      testWidgets('vem preenchido e salva com update '
          '(${size.width.toInt()}px)', (tester) async {
        when(() => repository.fetchSpecimen(1))
            .thenAnswer((_) async => existing);
        when(() => repository.update(1, any())).thenAnswer(
          (invocation) async => existing.copyWith(nickname: 'Saura'),
        );
        final results = await pumpForm(tester, specimenId: 1, size: size);
        await tester.pumpAndSettle();
        expect(find.text('Editar espécime'), findsOneWidget);
        expect(find.text('Bulba'), findsOneWidget);
        expect(find.text('Overgrow'), findsOneWidget);

        await tester.enterText(find.byType(TextField).first, 'Saura');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await tester.pumpAndSettle();
        expect(find.text('obs antiga'), findsOneWidget);
        await tester.tap(find.text('Salvar'));
        await tester.pumpAndSettle();

        final draft =
            verify(() => repository.update(1, captureAny())).captured.single
                as SpecimenDraft;
        expect(draft.nickname, 'Saura');
        expect(draft.form, 1);
        expect(draft.ability, 'overgrow');
        expect(draft.ot, 7);
        verifyNever(() => repository.create(any()));
        expect(results.single!.nickname, 'Saura');
      });
    }

    testWidgets('erro ao carregar o specimen com retry', (tester) async {
      var calls = 0;
      when(() => repository.fetchSpecimen(1)).thenAnswer((_) async {
        if (calls++ == 0) throw const NotFoundFailure();
        return existing;
      });
      await pumpForm(tester, specimenId: 1);
      await tester.pumpAndSettle();
      expect(find.text(const NotFoundFailure().message), findsOneWidget);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text('Bulba'), findsOneWidget);
    });
  });
}
