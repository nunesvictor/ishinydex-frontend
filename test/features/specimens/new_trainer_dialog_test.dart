import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/domain/specimen_repository.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/new_trainer_dialog.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';
import '../../helpers/mocks.dart';

void main() {
  Future<List<Trainer?>> open(
    WidgetTester tester, {
    Size size = compactSize,
    SpecimenRepository? repository,
  }) async {
    final results = <Trainer?>[];
    await pumpWidgetApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              results.add(await showNewTrainerDialog(context)),
          child: const Text('abrir'),
        ),
      ),
      size: size,
      overrides: [
        specimenRepositoryProvider.overrideWithValue(
          repository ?? FakeBackend.seeded(),
        ),
      ],
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return results;
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  for (final size in [compactSize, expandedSize]) {
    testWidgets('cria com versão e devolve o treinador '
        '(${size.width.toInt()}px)', (tester) async {
      final results = await open(tester, size: size);
      expect(find.text('Novo treinador'), findsOneWidget);

      await tester.enterText(field('Nome'), ' Red ');
      await tester.enterText(field('ID do treinador'), '1996');
      await tester.tap(find.byKey(const ValueKey('field-version')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'Red'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Novo treinador'), findsNothing);
      expect(results.single!.label, 'Red (1996) · Red');
    });
  }

  testWidgets('erros de validação e de par repetido', (tester) async {
    await open(tester);
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    // Nome e ID em branco: erro embaixo de cada campo (+ mensagem geral).
    expect(find.text('Este campo não pode ser em branco.'), findsWidgets);

    // Já existe "Ash (123456)" no fake.
    await tester.enterText(field('Nome'), 'Ash');
    await tester.enterText(field('ID do treinador'), '123456');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(
      find.text('Os campos name, trainer_id devem criar um set único.'),
      findsOneWidget,
    );
  });

  testWidgets('cancelar devolve null', (tester) async {
    final results = await open(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(results, [null]);
  });

  testWidgets('falha nas versões não impede salvar; retry recarrega', (
    tester,
  ) async {
    final repository = MockSpecimenRepository();
    var calls = 0;
    when(repository.fetchVersions).thenAnswer((_) async {
      if (calls++ == 0) throw const NetworkFailure();
      return const [
        GameVersion(name: 'red', versionGroup: 'red-blue', generation: 'i'),
      ];
    });
    when(() => repository.createTrainer(name: 'Red', trainerId: '1996'))
        .thenAnswer(
          (_) async => const Trainer(id: 9, name: 'Red', trainerId: '1996'),
        );
    final results = await open(tester, repository: repository);
    expect(find.text('Não foi possível carregar as versões.'), findsOneWidget);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('field-version')), findsOneWidget);

    await tester.enterText(field('Nome'), 'Red');
    await tester.enterText(field('ID do treinador'), '1996');
    await tester.tap(find.text('Salvar'));
    await tester.pump();
    // Salvando: botão vira spinner e as ações ficam desabilitadas.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(results.single!.id, 9);
  });
}
