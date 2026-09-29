import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';
import '../../helpers/mocks.dart';

void main() {
  testWidgets('lista os dexes com progresso', (tester) async {
    await pumpFullApp(tester);
    expect(find.text('Shiny Living Dex'), findsOneWidget);
    expect(find.text('Living Dex'), findsOneWidget);
    expect(find.text('Faltam 19'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsWidgets);
  });

  testWidgets('dex completo e pull-to-refresh', (tester) async {
    final backend = FakeBackend()
      ..addForm(id: 1, name: 'bulbasaur')
      ..addDex(name: 'Mini')
      ..addDex(name: 'Outro')
      ..addBox(dexId: 1, name: 'B', formIds: const []);
    await pumpFullApp(tester, backend: backend, size: compactSize);
    expect(find.text('Completo!'), findsNWidgets(2));
    await tester.fling(find.text('Mini'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Mini'), findsOneWidget);
  });

  testWidgets('estado vazio', (tester) async {
    await pumpFullApp(tester, backend: FakeBackend());
    expect(find.text('Nenhum PersonalDex cadastrado.'), findsOneWidget);
  });

  testWidgets('erro e tentar novamente', (tester) async {
    final repository = MockPersonalDexRepository();
    var calls = 0;
    when(repository.fetchDexes).thenAnswer((_) async {
      calls++;
      // 1ª chamada: redirect de entrada (cai na lista); 2ª: a própria lista.
      if (calls <= 2) throw const NetworkFailure();
      return const [PersonalDex(id: 1, name: 'Ok', total: 1, registered: 0)];
    });
    await pumpFullApp(
      tester,
      overrides: [personalDexRepositoryProvider.overrideWithValue(repository)],
    );
    expect(find.text(const NetworkFailure().message), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Ok'), findsOneWidget);
  });
}
