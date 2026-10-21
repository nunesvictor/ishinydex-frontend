import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/catalog_providers.dart';
import 'package:ishinydex/features/catalog/data/catalog_loader.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/new_dex_page.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/dex_recipe_picker.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/catalog_fixture.dart';
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
    testWidgets('em inglês: o formulário e a prévia', (tester) async {
      await pumpFullApp(tester, language: AppLanguage.en);
      await tester.tap(find.text('New PersonalDex'));
      await tester.pumpAndSettle();
      expect(find.text('What goes in'), findsOneWidget);
      expect(find.text('Living Form Lite · default'), findsOneWidget);
      expect(find.text('Regional forms'), findsOneWidget);
      await scrollToEnd(tester);
      expect(find.textContaining('forms in'), findsOneWidget);
      expect(find.text('Create PersonalDex'), findsOneWidget);
    });

    for (final size in [compactSize, expandedSize]) {
      testWidgets('cria o dex padrão e abre ele (${size.width.toInt()}px)', (
        tester,
      ) async {
        await pumpFullApp(tester, size: size);
        await tester.tap(find.text('Novo PersonalDex'));
        await tester.pumpAndSettle();
        expect(find.byType(NewDexPage), findsOneWidget);

        // No celular, as chaves (#34) empurram o resto para baixo.
        await tester.scrollUntilVisible(
          find.text('Nova box a cada geração'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(nameField(), ' Minha Dex ');
        await tester.tap(find.text('Nova box a cada geração'));
        await tester.tap(find.text('Shiny dex'));
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

    testWidgets('atalhos e chaves: um liga as outras, e fora deles é '
        '"Personalizado" (#34)', (tester) async {
      final backend = FakeBackend.seeded();
      await pumpWidgetApp(
        tester,
        const NewDexPage(),
        size: const Size(600, 2000),
        overrides: [personalDexRepositoryProvider.overrideWithValue(backend)],
      );
      await tester.pumpAndSettle();
      bool selected(String label) => tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label))
          .selected;
      bool on(String title) => tester
          .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title))
          .value;
      // O padrão: o Living Form Lite, com as três chaves.
      expect(selected('Living Form Lite · o padrão'), isTrue);
      expect(on('Formas regionais'), isTrue);
      expect(on('Pré-evoluções'), isTrue);
      expect(on('Formas alternativas'), isTrue);
      expect(find.text('Personalizado'), findsNothing);

      await tester.tap(find.text('Final Form'));
      await tester.pumpAndSettle();
      expect(selected('Final Form'), isTrue);
      expect(on('Pré-evoluções'), isFalse);
      expect(on('Formas alternativas'), isFalse);
      expect(on('Formas regionais'), isTrue);

      // Ligar as formas alternativas dá o Final Form + formas.
      await tester.tap(find.text('Formas alternativas'));
      await tester.pumpAndSettle();
      expect(selected('Final Form + formas'), isTrue);

      // Sem as regionais, nenhum atalho: "Personalizado", que não se escolhe.
      await tester.tap(find.text('Formas regionais'));
      await tester.pumpAndSettle();
      expect(selected('Personalizado'), isTrue);
      expect(
        tester
            .widget<ChoiceChip>(
              find.widgetWithText(ChoiceChip, 'Personalizado'),
            )
            .onSelected,
        isNull,
      );

      await tester.tap(find.text('Living Dex'));
      await tester.pumpAndSettle();
      expect(selected('Living Dex'), isTrue);
      expect(find.text('Personalizado'), findsNothing);

      // Desligar as pré-evoluções do Living dá o Final Form.
      await tester.tap(find.text('Pré-evoluções'));
      await tester.pumpAndSettle();
      expect(selected('Final Form'), isTrue);
    });

    testWidgets('o "?" explica os tipos e dá os créditos a Austin John', (
      tester,
    ) async {
      await pumpWidgetApp(
        tester,
        const NewDexPage(),
        size: const Size(400, 900),
        overrides: [
          personalDexRepositoryProvider.overrideWithValue(FakeBackend.seeded()),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tipos de dex'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Regionais'), findsOneWidget);
      expect(find.text('Final Form + formas'), findsWidgets);
      expect(
        find.textContaining('mesmo quando o shiny é igual'),
        findsOneWidget,
      );
      expect(find.textContaining('Austin John Plays'), findsOneWidget);
      expect(find.text(austinJohnSheetUrl), findsOneWidget);
      // Sem catálogo carregado, a tabela vem sem os números.
      expect(find.textContaining(RegExp(r'^[\d.]+ formas$')), findsNothing);
    });

    for (final (locale, help) in [
      (portuguese, 'Tipos de dex'),
      (const Locale('en'), 'Dex types'),
    ]) {
      testWidgets(
        'pior caso: 320 px e texto em 130% (${locale.languageCode})',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await pumpWidgetApp(
            tester,
            const NewDexPage(),
            size: const Size(320, 3000),
            locale: locale,
            overrides: [
              personalDexRepositoryProvider.overrideWithValue(
                FakeBackend.seeded(),
              ),
            ],
          );
          await tester.pumpAndSettle();
          // "Personalizado" também aparece, o chip mais largo junto dos outros.
          await tester.tap(find.byType(Switch).first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final chip in find.byType(ChoiceChip).evaluate()) {
            final rect = tester.getRect(find.byWidget(chip.widget));
            expect(rect.left, greaterThanOrEqualTo(16));
            expect(rect.right, lessThanOrEqualTo(320 - 16));
          }
          await tester.tap(find.byTooltip(help));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('a ajuda com o catálogo: quantas formas cada atalho dá', (
      tester,
    ) async {
      await pumpWidgetApp(
        tester,
        const DexTypesHelp(),
        overrides: [
          catalogLoadProvider.overrideWithValue(
            CatalogLoad(
              catalog: Catalog.fromJson(catalogJson(), spriteBase: 'http://s'),
              elapsed: Duration.zero,
            ),
          ),
        ],
      );
      // No catálogo de teste: 9 no padrão; 6 sem as pré-evoluções
      // (saem Bulbasaur, Ivysaur e Eevee).
      expect(find.text('9 formas'), findsNWidgets(2));
      expect(find.text('6 formas'), findsNWidgets(2));
      expect(find.byIcon(Icons.check), findsNWidgets(8));
    });

    testWidgets('sem espaço: explica e não deixa criar', (tester) async {
      when(
        () => repository.previewNewDex(
          recipe: const DexRecipe(),
          forceNewBox: false,
        ),
      ).thenAnswer(
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
        find.textContaining('o HOME tem no máximo 300 boxes'),
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
        when(
          () => repository.previewNewDex(
            recipe: const DexRecipe(),
            forceNewBox: false,
          ),
        ).thenAnswer((_) async => preview);
        await pump(tester);
        expect(find.text(text), findsOneWidget);
      });
    }

    testWidgets('erro na simulação com retry', (tester) async {
      var calls = 0;
      when(
        () => repository.previewNewDex(
          recipe: const DexRecipe(),
          forceNewBox: false,
        ),
      ).thenAnswer((_) async {
        if (calls++ == 0) throw const NotFoundFailure();
        return const DexPreview(
          forms: 3,
          boxesNeeded: 1,
          largestFreeRun: 2,
          enoughSpace: true,
          firstBox: BoxRef(id: 1, name: 'HOME 1', position: 1),
        );
      });
      await pump(tester);
      expect(find.text('Não encontrado.'), findsOneWidget);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(
        find.text('3 formas em 1 boxes, a partir da HOME 1.'),
        findsOneWidget,
      );
    });

    testWidgets('erro de validação da API aparece no campo', (tester) async {
      when(
        () => repository.previewNewDex(
          recipe: const DexRecipe(),
          forceNewBox: false,
        ),
      ).thenAnswer(
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
        const ValidationFailure({
          'name': [Problem.dexNameTaken()],
        }),
      );
      await pump(tester);
      await tester.enterText(nameField(), 'Shiny');
      await tester.tap(find.text('Criar PersonalDex'));
      await tester.pumpAndSettle();
      expect(find.text('Já existe uma dex com este nome.'), findsWidgets);
    });

    testWidgets('simulação que não é AppFailure mostra mensagem genérica', (
      tester,
    ) async {
      when(
        () => repository.previewNewDex(
          recipe: const DexRecipe(),
          forceNewBox: false,
        ),
      ).thenThrow(StateError('x'));
      await pump(tester);
      expect(find.text('Não foi possível simular o dex.'), findsOneWidget);
    });
  });
}
