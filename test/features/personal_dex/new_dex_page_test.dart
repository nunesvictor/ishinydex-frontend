import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/new_dex_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';
import '../../helpers/mocks.dart';

Finder nameField() => find.widgetWithText(TextField, 'Nome');

Future<void> scrollToEnd(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.drag(find.byType(ListView), const Offset(0, -3000));
  await tester.pumpAndSettle();
}

void main() {
  group('pelo app inteiro', () {
    for (final size in [compactSize, expandedSize]) {
      testWidgets('cria o dex padrão e abre ele (${size.width.toInt()}px)', (
        tester,
      ) async {
        await pumpFullApp(tester, size: size);
        await tester.tap(find.text('Novo PersonalDex'));
        await tester.pumpAndSettle();
        expect(find.byType(NewDexPage), findsOneWidget);

        await tester.enterText(nameField(), ' Minha Dex ');
        await tester.tap(find.text('Nova box a cada geração'));
        await tester.tap(find.text('Dex shiny'));
        await tester.pumpAndSettle();
        await scrollToEnd(tester);
        expect(
          find.text('58 formas em 2 boxes, a partir da HOME 4.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Criar PersonalDex'));
        await tester.pumpAndSettle();

        // Abriu o dex novo, nas boxes livres.
        expect(find.text('Minha Dex'), findsWidgets);
        expect(find.text('HOME 4 · 0/30'), findsOneWidget);
      });
    }

    testWidgets('fechar sem criar volta para a lista', (tester) async {
      await pumpFullApp(tester);
      await tester.tap(find.text('Novo PersonalDex'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.byType(NewDexPage), findsNothing);
      expect(find.text('Shiny Living Dex'), findsOneWidget);
    });
  });

  group('NewDexPage', () {
    late MockPersonalDexRepository repository;

    setUp(() => repository = MockPersonalDexRepository());

    Future<void> pump(WidgetTester tester) async {
      await pumpWidgetApp(
        tester,
        const NewDexPage(),
        size: const Size(600, 2000),
        overrides: [
          personalDexRepositoryProvider.overrideWithValue(repository),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets('explica o padrão e o personalizado chama o fluxo "em breve"', (
      tester,
    ) async {
      await pumpWidgetApp(
        tester,
        const NewDexPage(),
        size: const Size(600, 2000),
        overrides: [
          personalDexRepositoryProvider.overrideWithValue(FakeBackend.seeded()),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('O que entra no conjunto padrão?'));
      await tester.pumpAndSettle();
      expect(find.text(standardSetRules.last), findsOneWidget);

      await tester.tap(find.text('Personalizado'));
      await tester.pumpAndSettle();
      expect(find.text('Em breve'), findsWidgets);
      await tester.tap(find.text('Entendi'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('sem espaço: explica e não deixa criar', (tester) async {
      when(() => repository.previewNewDex(forceNewBox: false)).thenAnswer(
        (_) async => const DexPreview(
          forms: 1227,
          boxesNeeded: 45,
          largestFreeRun: 10,
          enoughSpace: false,
        ),
      );
      await pump(tester);
      expect(
        find.textContaining('precisa de 45 boxes livres seguidas'),
        findsOneWidget,
      );
      expect(
        find.textContaining('o HOME tem no máximo 200 boxes'),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Criar PersonalDex'),
      );
      expect(button.onPressed, isNull);
    });

    for (final (preview, text) in [
      (
        const DexPreview(
          forms: 1227,
          boxesNeeded: 45,
          largestFreeRun: 0,
          enoughSpace: true,
          boxesToCreate: 45,
        ),
        '1227 formas em 45 boxes novas, criadas no fim.',
      ),
      (
        const DexPreview(
          forms: 1227,
          boxesNeeded: 45,
          largestFreeRun: 44,
          enoughSpace: true,
          boxesToCreate: 1,
          firstBox: BoxRef(id: 7, name: 'HOME 7', position: 7),
        ),
        '1227 formas em 45 boxes, a partir da HOME 7 (cria 1 box nova no fim).',
      ),
      (
        const DexPreview(
          forms: 1227,
          boxesNeeded: 45,
          largestFreeRun: 40,
          enoughSpace: true,
          boxesToCreate: 5,
          firstBox: BoxRef(id: 11, name: 'HOME 11', position: 11),
        ),
        '1227 formas em 45 boxes, a partir da HOME 11 '
            '(cria 5 boxes novas no fim).',
      ),
    ]) {
      testWidgets('boxes novas no resumo: $text', (tester) async {
        when(() => repository.previewNewDex(forceNewBox: false))
            .thenAnswer((_) async => preview);
        await pump(tester);
        expect(find.text(text), findsOneWidget);
      });
    }

    testWidgets('erro na simulação com retry', (tester) async {
      var calls = 0;
      when(() => repository.previewNewDex(forceNewBox: false))
          .thenAnswer((_) async {
            if (calls++ == 0) throw const NetworkFailure();
            return const DexPreview(
              forms: 3,
              boxesNeeded: 1,
              largestFreeRun: 2,
              enoughSpace: true,
              firstBox: BoxRef(id: 1, name: 'HOME 1', position: 1),
            );
          });
      await pump(tester);
      expect(find.text(const NetworkFailure().message), findsOneWidget);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(
        find.text('3 formas em 1 boxes, a partir da HOME 1.'),
        findsOneWidget,
      );
    });

    testWidgets('erro de validação da API aparece no campo', (tester) async {
      when(() => repository.previewNewDex(forceNewBox: false)).thenAnswer(
        (_) async => const DexPreview(
          forms: 3,
          boxesNeeded: 1,
          largestFreeRun: 1,
          enoughSpace: true,
          firstBox: BoxRef(id: 1, name: 'HOME 1', position: 1),
        ),
      );
      when(
        () => repository.createDex(
          name: 'Shiny',
          isShinyDex: false,
          forceNewBox: false,
        ),
      ).thenThrow(
        ValidationFailure({
          'name': ['personal dex com este name já existe.'],
        }),
      );
      await pump(tester);
      await tester.enterText(nameField(), 'Shiny');
      await tester.tap(find.text('Criar PersonalDex'));
      await tester.pumpAndSettle();
      expect(find.text('personal dex com este name já existe.'), findsWidgets);
    });

    testWidgets('simulação que não é AppFailure mostra mensagem genérica', (
      tester,
    ) async {
      when(() => repository.previewNewDex(forceNewBox: false))
          .thenThrow(StateError('x'));
      await pump(tester);
      expect(find.text('Não foi possível simular o dex.'), findsOneWidget);
    });
  });
}
