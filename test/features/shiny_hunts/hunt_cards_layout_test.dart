import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/clock.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/shiny_hunts/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/presentation/hunt_card.dart';
import 'package:ishinydex/features/shiny_hunts/presentation/hunt_lists.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

import '../../helpers/helpers.dart';

final _now = DateTime(2026, 10, 20, 12);

// O pior caso real: o método mais longo.
const _methods = [
  ShinyMethod(
    id: 'sparkling-power',
    label: 'Sparkling Power (sanduíche)',
    units: ['encounters', 'hours'],
    versions: {},
  ),
];

void main() {
  test('colunas pela largura (#312)', () {
    expect(huntColumns(400), 1);
    expect(huntColumns(719), 1);
    // iPad mini, Air e Pro 11" em retrato: dois.
    expect(huntColumns(744), 2);
    expect(huntColumns(820), 2);
    expect(huntColumns(834), 2);
    expect(huntColumns(1400), 3);
  });

  for (final width in [400.0, 744.0, 820.0, 834.0, 1400.0]) {
    testWidgets('cards preenchem a linha, fileiras da mesma altura '
        '(${width.toInt()} px)', (tester) async {
      final backend = FakeBackend.seeded();
      final ot = backend.addTrainer(
        name: 'Victor',
        trainerId: '1',
        version: 'scarlet',
      );
      final save = (await backend.createSave(trainerId: ot)).id;
      // Na mesma fileira: um de contador (com 5 dígitos) e um de cronômetro,
      // com o método mais longo; e um terceiro para a segunda fileira.
      for (final hunt in [
        ShinyHunt(
          id: 0,
          form: 1,
          save: save,
          method: 'sparkling-power',
          count: 12345,
          startedAt: DateTime(2026, 9),
        ),
        ShinyHunt(
          id: 0,
          form: 2,
          save: save,
          method: 'sparkling-power',
          unit: 'hours',
          accumulatedSeconds: 3600 * 123,
          startedAt: DateTime(2026, 8),
        ),
        const ShinyHunt(id: 0, form: 3),
      ]) {
        await backend.saveShinyHunt(hunt);
      }
      await pumpWidgetApp(
        tester,
        const Scaffold(body: HuntCards(paused: false)),
        size: Size(width, 2400),
        hunts: backend,
        overrides: [
          fakeBackendProvider.overrideWithValue(backend),
          clockProvider.overrideWithValue(() => _now),
          shinyMethodsProvider.overrideWithValue(
            (_, {fromGo = false, formId}) => _methods,
          ),
        ],
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final cards =
          [
            for (final e in find.byType(HuntCard).evaluate())
              tester.getRect(find.byWidget(e.widget)),
          ]..sort(
            (a, b) => a.top == b.top
                ? a.left.compareTo(b.left)
                : a.top.compareTo(b.top),
          );
      expect(cards, hasLength(3));
      final columns = huntColumns(width);
      final rows = <double, List<Rect>>{};
      for (final r in cards) {
        (rows[r.top] ??= []).add(r);
      }
      for (final row in rows.values) {
        expect(row.length, lessThanOrEqualTo(columns));
        // Mesma altura e mesma largura na fileira.
        expect({for (final r in row) r.height}, hasLength(1));
        expect({for (final r in row) r.width.roundToDouble()}, hasLength(1));
        expect(row.first.left, moreOrLessEquals(16));
      }
      // A primeira fileira, cheia, vai até a margem da direita.
      final first = rows.values.first;
      if (first.length == columns) {
        expect(first.last.right, moreOrLessEquals(width - 16));
      }
    });
  }
}
