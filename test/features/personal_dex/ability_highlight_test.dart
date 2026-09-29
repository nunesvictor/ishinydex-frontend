import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/form_details.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/api_fixtures.dart';
import '../../helpers/helpers.dart';
import '../../helpers/mocks.dart';

/// Primeiro [TextSpan] com [text] dentro do texto de habilidades.
TextSpan? spanWith(WidgetTester tester, String text) {
  TextSpan? found;
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text == text) found = span;
      return found == null;
    });
  }
  return found;
}

void main() {
  late MockSpecimenRepository repository;

  setUp(() {
    repository = MockSpecimenRepository();
    when(() => repository.fetchForm(1))
        .thenAnswer((_) async => FormDetail.fromJson(formDetailJson));
  });

  Future<void> pump(
    WidgetTester tester, {
    String? highlight,
    Size? size,
  }) async {
    await pumpWidgetApp(
      tester,
      Scaffold(body: FormDetails(formId: 1, highlightAbility: highlight)),
      size: size ?? compactSize,
      overrides: [specimenRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
  }

  for (final size in [compactSize, expandedSize]) {
    testWidgets('destaca a habilidade do espécime (${size.width.toInt()}px)', (
      tester,
    ) async {
      await pump(tester, highlight: 'chlorophyll', size: size);
      expect(
        find.text('Habilidades: Overgrow · ✓ Chlorophyll (oculta)'),
        findsOneWidget,
      );
      final span = spanWith(tester, '✓ Chlorophyll (oculta)')!;
      expect(span.style!.fontWeight, FontWeight.bold);
      expect(spanWith(tester, 'Overgrow')!.style, isNull);
    });
  }

  testWidgets('sem habilidade (ou uma que não é da forma), nada muda', (
    tester,
  ) async {
    await pump(tester, highlight: 'levitate');
    expect(
      find.text('Habilidades: Overgrow · Chlorophyll (oculta)'),
      findsOneWidget,
    );
  });

  test('SpecimenSummary traz a habilidade', () {
    final slot = Slot.fromJson({
      ...registeredSlotJson,
      'specimen': {
        ...(registeredSlotJson['specimen']! as Map<String, dynamic>),
        'ability': 'overgrow',
      },
    });
    expect(slot.specimen!.ability, 'overgrow');
  });
}
