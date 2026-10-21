import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/widgets/type_chip.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/form_details.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/api_fixtures.dart';
import '../../helpers/helpers.dart';
import '../../helpers/mocks.dart';

void main() {
  late MockSpecimenRepository repository;

  setUp(() => repository = MockSpecimenRepository());

  Future<void> pump(
    WidgetTester tester, {
    Size size = compactSize,
    Locale locale = portuguese,
  }) => pumpWidgetApp(
    tester,
    const Scaffold(body: FormDetails(formId: 1)),
    size: size,
    locale: locale,
    overrides: [specimenRepositoryProvider.overrideWithValue(repository)],
  );

  for (final size in [compactSize, expandedSize]) {
    testWidgets('tipos em ordem, habilidades e selos '
        '(${size.width.toInt()}px)', (tester) async {
      when(() => repository.fetchForm(1)).thenAnswer(
        (_) async => FormDetail.fromJson({
          ...formDetailJson,
          // Fora de ordem de propósito: a tela ordena pelo slot.
          'types': [
            {'slot': 2, 'type': 'poison'},
            {
              'slot': 1,
              'type': 'grass',
              'sprite_url': 'http://x/types/small/12.png',
            },
          ],
          'is_shinylocked': true,
          'is_distro_only': true,
        }),
      );
      await pump(tester, size: size);
      await tester.pumpAndSettle();

      // Os tipos com o ícone do HOME e o nome (#230), depois os selos.
      expect(
        tester.widgetList<TypeChip>(find.byType(TypeChip)).map((c) => c.type),
        ['grass', 'poison'],
      );
      expect(
        tester.widgetList<TypeIcon>(find.byType(TypeIcon)).map((i) => i.type),
        ['grass', 'poison'],
      );
      expect(find.text('Grass'), findsOneWidget);
      final labels = tester
          .widgetList<Chip>(find.byType(Chip))
          .map((c) => (c.label as Text).data)
          .toList();
      expect(labels, ['Shiny lock', 'Só distribuição']);
      expect(
        find.text('Habilidades: Overgrow · Chlorophyll (oculta)'),
        findsOneWidget,
      );
    });
  }

  testWidgets('em inglês: a habilidade oculta diz "hidden"', (tester) async {
    when(() => repository.fetchForm(1))
        .thenAnswer((_) async => FormDetail.fromJson(formDetailJson));
    await pump(tester, locale: english);
    await tester.pumpAndSettle();
    expect(find.textContaining('(hidden)'), findsOneWidget);
    expect(find.textContaining('(oculta)'), findsNothing);
  });

  testWidgets('sem selos nem habilidades', (tester) async {
    when(() => repository.fetchForm(1)).thenAnswer(
      (_) async =>
          FormDetail.fromJson({...formDetailJson, 'abilities': <Object>[]}),
    );
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.text('Shiny lock'), findsNothing);
    expect(find.text('Só distribuição'), findsNothing);
    expect(find.textContaining('Habilidades'), findsNothing);
  });

  testWidgets('carregando e erro com retry', (tester) async {
    var calls = 0;
    when(() => repository.fetchForm(1)).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (calls++ == 0) throw const NotFoundFailure();
      return FormDetail.fromJson(formDetailJson);
    });
    await pump(tester);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível carregar os detalhes da forma.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Grass'), findsOneWidget);
  });
}
