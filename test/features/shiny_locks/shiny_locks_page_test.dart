import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/shiny_locks/domain/models.dart';
import 'package:ishinydex/features/shiny_locks/presentation/shiny_locks_page.dart';
import 'package:ishinydex/features/shiny_locks/shiny_lock_providers.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/form_picker.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/api_fixtures.dart';
import '../../helpers/helpers.dart';
import '../../helpers/mocks.dart';

Future<void> _go(WidgetTester tester, String location) async {
  ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
      .read(routerProvider)
      .go(location);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Some com o snackbar da ação anterior (ele cobre o botão flutuante).
Future<void> _dismissSnackBar(WidgetTester tester) async {
  ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last))
      .removeCurrentSnackBar();
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.widgetWithText(TextField, label);

/// Escolhe a forma [id] no seletor, buscando por [search].
Future<void> _pickForm(WidgetTester tester, String search, int id) async {
  await _tap(tester, find.text('Adicionar forma'));
  await tester.enterText(
    find.descendant(
      of: find.byType(FormPicker),
      matching: find.byType(TextField),
    ),
    search,
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  await _tap(tester, find.byKey(ValueKey('form-$id')));
}

void main() {
  for (final size in [compactSize, expandedSize]) {
    testWidgets('criar, editar e apagar (${size.width.toInt()}px)', (
      tester,
    ) async {
      final backend = await pumpFullApp(tester, size: size);
      await _go(tester, Routes.settings);
      await _tap(tester, find.text('Shiny locks'));

      // O exemplo do fake: só por distribuição, uma forma.
      expect(find.text('Pikachu de evento'), findsOneWidget);
      expect(find.text('1 forma'), findsOneWidget);
      expect(find.text('Todos · 1'), findsOneWidget);
      await _tap(tester, find.text('Impossível · 0'));
      expect(find.text('Nenhum shiny lock deste tipo.'), findsOneWidget);
      await _tap(tester, find.text('Distribuição · 1'));
      expect(find.text('Pikachu de evento'), findsOneWidget);
      await _tap(tester, find.text('Todos · 1'));

      // Novo: sem nome e sem formas, os erros aparecem nos campos.
      await _tap(tester, find.text('Novo shiny lock'));
      expect(find.text('Novo shiny lock'), findsOneWidget);
      await _tap(tester, find.text('Salvar'));
      expect(find.text('Este campo não pode ser em branco.'), findsOneWidget);
      expect(find.text('Esta lista não pode estar vazia.'), findsOneWidget);
      // Mexer no campo tira o erro dele; o das formas fica.
      await tester.enterText(_field('Nome'), 'Vulpix de teste');
      await tester.pump();
      expect(find.text('Este campo não pode ser em branco.'), findsNothing);
      expect(find.text('Esta lista não pode estar vazia.'), findsOneWidget);
      await tester.enterText(_field('Descrição (opcional)'), 'Teste.');
      await tester.pump();
      await _pickForm(tester, 'vulp', 37);
      expect(find.text('Esta lista não pode estar vazia.'), findsNothing);
      expect(find.text('Formas · 1'), findsOneWidget);
      // A mesma forma de novo é ignorada; outra entra na ordem da dex.
      await _pickForm(tester, 'vulp', 37);
      await _pickForm(tester, 'bulba', 1);
      expect(find.text('Formas · 2'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('lock-form-1'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('lock-form-37'))).dy,
        ),
      );
      await _tap(tester, find.text('Salvar'));
      expect(find.text('Shiny lock salvo.'), findsOneWidget);
      expect(find.text('Vulpix de teste'), findsOneWidget);
      expect(find.text('2 formas'), findsOneWidget);
      expect((await backend.fetchForm(37)).isShinylocked, true);

      // Editar: tipo, ativo e descrição.
      await _dismissSnackBar(tester);
      await _tap(tester, find.text('Pikachu de evento'));
      expect(find.text('Editar shiny lock'), findsOneWidget);
      expect(find.textContaining('por distribuição (evento)'), findsOneWidget);
      await _tap(tester, find.text('Shiny impossível'));
      expect(find.textContaining('Não existe shiny'), findsOneWidget);
      await _tap(tester, find.text('Ativo'));
      await _tap(tester, find.text('Salvar'));
      expect(find.text('Shiny lock salvo.'), findsOneWidget);
      // Inativo: esmaecido, com o selo, e sem efeito na forma.
      expect(find.text('Inativo'), findsOneWidget);
      expect(find.text('Impossível · 2'), findsOneWidget);
      expect((await backend.fetchForm(25)).isShinylocked, false);

      // Nome repetido: o erro da API aparece no campo; fechar não salva.
      await _dismissSnackBar(tester);
      await _tap(tester, find.text('Vulpix de teste'));
      await tester.enterText(_field('Nome'), 'Pikachu de evento');
      await _tap(tester, find.text('Salvar'));
      expect(
        find.text('Já existe um shiny lock com este nome.'),
        findsOneWidget,
      );
      await _tap(tester, find.byType(CloseButton));
      expect(find.text('Vulpix de teste'), findsOneWidget);

      // Tirar uma forma e apagar (cancelar a confirmação não apaga).
      await _tap(tester, find.text('Vulpix de teste'));
      await _tap(tester, find.byTooltip('Remover forma').first);
      expect(find.text('Formas · 1'), findsOneWidget);
      await _tap(tester, find.text('Apagar shiny lock'));
      expect(find.text('Apagar Vulpix de teste?'), findsOneWidget);
      await _tap(tester, find.text('Cancelar'));
      expect(find.text('Editar shiny lock'), findsOneWidget);
      await _tap(tester, find.text('Apagar shiny lock'));
      await _tap(tester, find.widgetWithText(TextButton, 'Apagar'));
      expect(find.text('Shiny lock apagado.'), findsOneWidget);
      expect(find.text('Vulpix de teste'), findsNothing);
      expect((await backend.fetchForm(37)).isShinylocked, false);
    });
  }

  group('com o repositório simulado', () {
    late MockShinyLockRepository repository;
    final lock = ShinyLock.fromJson(shinyLockJson);

    setUpAll(() => registerFallbackValue(const ShinyLockDraft()));
    setUp(() => repository = MockShinyLockRepository());

    Future<void> pump(WidgetTester tester) => pumpWidgetApp(
      tester,
      const ShinyLocksPage(),
      overrides: [shinyLockRepositoryProvider.overrideWithValue(repository)],
    );

    testWidgets('erro com retry e lista vazia', (tester) async {
      var calls = 0;
      when(() => repository.fetchShinyLocks()).thenAnswer((_) async {
        if (calls++ == 0) throw const NetworkFailure();
        return const [];
      });
      await pump(tester);
      await tester.pumpAndSettle();
      expect(find.text(const NetworkFailure().message), findsOneWidget);
      await _tap(tester, find.text('Tentar novamente'));
      expect(
        find.textContaining('Nenhum shiny lock cadastrado'),
        findsOneWidget,
      );
    });

    testWidgets('falhas ao salvar e ao apagar aparecem no topo', (
      tester,
    ) async {
      when(() => repository.fetchShinyLocks()).thenAnswer((_) async => [lock]);
      when(() => repository.updateShinyLock(any(), any()))
          .thenThrow(const NetworkFailure());
      when(() => repository.deleteShinyLock(any()))
          .thenThrow(const ServerFailure());
      await pump(tester);
      await tester.pumpAndSettle();
      // O ícone do tipo e a forma de exemplo.
      expect(find.byIcon(Icons.card_giftcard), findsWidgets);
      await _tap(tester, find.text('Treasures of Ruin'));

      await _tap(tester, find.text('Salvar'));
      expect(find.text(const NetworkFailure().message), findsOneWidget);

      await _tap(tester, find.text('Apagar shiny lock'));
      await _tap(tester, find.widgetWithText(TextButton, 'Apagar'));
      expect(find.text(const ServerFailure().message), findsOneWidget);
      expect(find.text('Editar shiny lock'), findsOneWidget);
      verify(() => repository.updateShinyLock(25, any())).called(1);
    });
  });

  test('ShinyLockTypeUi: ícones e rótulos curtos', () {
    expect(ShinyLockType.unobtainable.icon, Icons.lock_outline);
    expect(ShinyLockType.distroOnly.shortLabel, 'Distribuição');
    expect(ShinyLockTypeUi.ordered.first, ShinyLockType.unobtainable);
  });
}
