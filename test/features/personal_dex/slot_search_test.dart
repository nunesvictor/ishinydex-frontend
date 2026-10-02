import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/slot_search.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';
import '../../helpers/mocks.dart';

void main() {
  group('SlotSearchResults', () {
    late MockPersonalDexRepository repository;

    setUp(() => repository = MockPersonalDexRepository());

    Future<void> pump(WidgetTester tester, String search) => pumpWidgetApp(
      tester,
      Scaffold(
        body: SlotSearchResults(dexId: 1, search: search, onSelected: (_) {}),
      ),
      overrides: [personalDexRepositoryProvider.overrideWithValue(repository)],
    );

    testWidgets('pede 2 letras, mas aceita um número de 1 dígito', (
      tester,
    ) async {
      when(() => repository.searchSlots(dexId: 1, search: '6'))
          .thenAnswer((_) async => const []);
      const hint = 'Digite o nome (2 letras ou mais) ou o número.';
      await pump(tester, '');
      expect(find.text(hint), findsOneWidget);
      await pump(tester, 'p');
      expect(find.text(hint), findsOneWidget);
      await pump(tester, '6');
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma forma deste dex encontrada.'), findsOneWidget);
    });

    testWidgets('erro com retry', (tester) async {
      var calls = 0;
      when(() => repository.searchSlots(dexId: 1, search: 'mew'))
          .thenAnswer((_) async {
            if (calls++ == 0) throw const NetworkFailure();
            return const [];
          });
      await pump(tester, 'mew');
      await tester.pumpAndSettle();
      expect(find.text(const NetworkFailure().message), findsOneWidget);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma forma deste dex encontrada.'), findsOneWidget);
    });
  });

  testWidgets('SlotSearchBar sem trailing: só "Cancelar" quando ativa', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    var cancelled = false;
    Future<void> pump({required bool active}) => pumpWidgetApp(
      tester,
      Scaffold(
        body: SlotSearchBar(
          controller: controller,
          focusNode: focusNode,
          active: active,
          onChanged: (_) {},
          onCancel: () => cancelled = true,
          onClear: () {},
        ),
      ),
    );
    await pump(active: false);
    expect(find.text('Cancelar'), findsNothing);
    await pump(active: true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    expect(cancelled, isTrue);
  });
}
