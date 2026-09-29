import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/slot_search.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';
import '../../helpers/mocks.dart';

void main() {
  late MockPersonalDexRepository repository;

  setUp(() => repository = MockPersonalDexRepository());

  Future<void> pump(WidgetTester tester) => pumpWidgetApp(
    tester,
    const Scaffold(body: SlotSearch(dexId: 1)),
    overrides: [personalDexRepositoryProvider.overrideWithValue(repository)],
  );

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  testWidgets('pede 2 letras, mas aceita um número de 1 dígito', (
    tester,
  ) async {
    when(() => repository.searchSlots(dexId: 1, search: '6'))
        .thenAnswer((_) async => const []);
    await pump(tester);
    const hint = 'Digite o nome (2 letras ou mais) ou o número.';
    expect(find.text(hint), findsOneWidget);
    await type(tester, 'p');
    expect(find.text(hint), findsOneWidget);
    await type(tester, '6');
    expect(find.text('Nenhuma forma deste dex encontrada.'), findsOneWidget);
  });

  testWidgets('erro com retry', (tester) async {
    var calls = 0;
    when(() => repository.searchSlots(dexId: 1, search: 'mew'))
        .thenAnswer((_) async {
          if (calls++ == 0) throw const NetworkFailure();
          return const [];
        });
    await pump(tester);
    await type(tester, 'mew');
    expect(find.text(const NetworkFailure().message), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma forma deste dex encontrada.'), findsOneWidget);
  });
}
