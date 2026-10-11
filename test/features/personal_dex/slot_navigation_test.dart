import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/slot_navigation.dart';

void main() {
  const box = BoxRef(id: 1, name: 'HOME 1', position: 0);
  const form = FormRef(
    id: 1,
    name: 'Bulbasaur',
    pokeapiId: 1,
    spriteUrl: '',
    shinySpriteUrl: '',
  );
  Slot slot(
    int id,
    int row,
    int col, {
    bool free = false,
    bool missing = true,
  }) => Slot(
    id: id,
    box: box,
    row: row,
    col: col,
    form: free ? null : form,
    specimen: missing ? null : const SpecimenSummary(id: 1),
  );

  test('na ordem da grade, sem os livres', () {
    final slots = [
      slot(3, 1, 0),
      slot(2, 0, 1),
      slot(1, 0, 0),
      slot(4, 1, 1, free: true),
    ];
    expect(navigableSlots(slots, onlyMissing: false).map((s) => s.id), [
      1,
      2,
      3,
    ]);
  });

  test('com o filtro, só os faltantes e o selecionado', () {
    final slots = [
      slot(1, 0, 0, missing: false),
      slot(2, 0, 1),
      slot(3, 0, 2, missing: false),
    ];
    expect(navigableSlots(slots, onlyMissing: true).map((s) => s.id), [2]);
    expect(navigableSlots(slots, onlyMissing: true, keep: 3).map((s) => s.id), [
      2,
      3,
    ]);
  });

  testWidgets('o balão some sozinho e volta a cada troca nova', (tester) async {
    Future<void> show(BoxNotice notice) => tester.pumpWidget(
      MaterialApp(home: Center(child: BoxNoticeBalloon(notice))),
    );
    double opacity() =>
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

    await show(const BoxNotice(1, 'HOME 2'));
    expect(find.text('HOME 2'), findsOneWidget);
    expect(opacity(), 1);
    await tester.pump(BoxNoticeBalloon.visibleFor);
    expect(opacity(), 0);

    // A mesma troca (mesmo id) não reaparece; uma troca nova, sim.
    await show(const BoxNotice(1, 'HOME 2'));
    expect(opacity(), 0);
    await show(const BoxNotice(2, 'HOME 2'));
    expect(opacity(), 1);
    await tester.pump(BoxNoticeBalloon.visibleFor);
    expect(opacity(), 0);
  });
}
