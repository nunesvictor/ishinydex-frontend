import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/slot_swipe.dart';

/// Slots 0 a [last], numa área de 400 px; as setas de fora mudam o slot com
/// a direção do passo, como o painel do dex.
class _Harness extends StatefulWidget {
  const _Harness({this.last = 2, this.stuck = false});

  final int last;

  /// O "seguinte" não troca nada (a box vizinha não tinha o que mostrar).
  final bool stuck;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int index = 0;
  int direction = 0;

  void go(int delta) => setState(() {
    index += delta;
    direction = delta;
  });

  void tap(int to) => setState(() {
    index = to;
    direction = 0;
  });

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 400,
      height: 300,
      child: SlotSwipe(
        direction: direction,
        onPrevious: index == 0 ? null : () => go(-1),
        onNext: index == widget.last
            ? null
            : widget.stuck
            ? () {}
            : () => go(1),
        child: Container(
          key: ValueKey('slot-$index'),
          color: Colors.white,
          alignment: Alignment.center,
          child: Text('slot $index'),
        ),
      ),
    ),
  );
}

Future<_HarnessState> _pump(
  WidgetTester tester, {
  int last = 2,
  bool stuck = false,
  bool reduceMotion = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: _Harness(last: last, stuck: stuck),
        ),
      ),
    ),
  );
  return tester.state<_HarnessState>(find.byType(_Harness));
}

/// O deslocamento atual do conteúdo, em px.
double _offset(WidgetTester tester) => tester
    .widget<Transform>(
      find.descendant(
        of: find.byType(SlotSwipe),
        matching: find.byType(Transform),
      ),
    )
    .transform
    .getTranslation()
    .x;

/// Arrasta devagar (sem velocidade de fling).
Future<void> _slowDrag(WidgetTester tester, double dx) async {
  await tester.timedDrag(
    find.byType(SlotSwipe),
    Offset(dx, 0),
    const Duration(seconds: 2),
  );
}

void main() {
  testWidgets('arrastar pouco e soltar: volta ao lugar, sem trocar', (
    tester,
  ) async {
    final state = await _pump(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SlotSwipe)),
    );
    await gesture.moveBy(const Offset(-30, 0));
    await gesture.moveBy(const Offset(-50, 0));
    await tester.pump();
    // O conteúdo acompanha o dedo (o primeiro trecho é o limiar do gesto).
    expect(_offset(tester), lessThan(-40));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(state.index, 0);
    expect(_offset(tester), 0);
  });

  testWidgets('arrastar além de 1/3: troca; o novo entra pela direita', (
    tester,
  ) async {
    final state = await _pump(tester);
    await _slowDrag(tester, -200);
    // Sai pela esquerda até o fim, e só então troca.
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.index, 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_offset(tester), greaterThan(0));
    await tester.pumpAndSettle();
    expect(find.text('slot 1'), findsOneWidget);
    expect(_offset(tester), 0);

    // E de volta: o anterior entra pela esquerda.
    await _slowDrag(tester, 200);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.index, 0);
    expect(_offset(tester), lessThan(0));
    await tester.pumpAndSettle();
  });

  testWidgets('um gesto rápido e curto também troca', (tester) async {
    final state = await _pump(tester);
    await tester.fling(find.byType(SlotSwipe), const Offset(-60, 0), 1000);
    await tester.pumpAndSettle();
    expect(state.index, 1);
    expect(_offset(tester), 0);
  });

  testWidgets('sem vizinho: resiste (anda menos que o dedo) e não troca', (
    tester,
  ) async {
    final state = await _pump(tester, last: 0);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SlotSwipe)),
    );
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(200, 0));
    await tester.pump();
    final moved = _offset(tester);
    expect(moved, greaterThan(0));
    expect(moved, lessThan(100));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(state.index, 0);
    expect(_offset(tester), 0);

    // Do outro lado também (fling, sem o seguinte).
    await tester.fling(find.byType(SlotSwipe), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(state.index, 0);
  });

  testWidgets('setas: entra do lado do passo; toque na grade: na hora', (
    tester,
  ) async {
    final state = await _pump(tester);
    state.go(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_offset(tester), greaterThan(0));
    await tester.pumpAndSettle();
    state.go(-1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_offset(tester), lessThan(0));
    await tester.pumpAndSettle();
    state.tap(2);
    await tester.pump();
    expect(_offset(tester), 0);
    expect(find.text('slot 2'), findsOneWidget);
  });

  testWidgets('reduzir movimento: troca e volta sem animação', (tester) async {
    final state = await _pump(tester, reduceMotion: true);
    await tester.fling(find.byType(SlotSwipe), const Offset(-300, 0), 1000);
    await tester.pump();
    expect(state.index, 1);
    expect(_offset(tester), 0);
    // Pelas setas, também na hora.
    state.go(1);
    await tester.pump();
    expect(_offset(tester), 0);
    // Um gesto curto volta na hora.
    await _slowDrag(tester, -40);
    await tester.pump();
    expect(_offset(tester), 0);
  });

  testWidgets('se o slot novo não chegar, o atual volta', (tester) async {
    final state = await _pump(tester, stuck: true);
    await tester.fling(find.byType(SlotSwipe), const Offset(-300, 0), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_offset(tester), -400);
    // Durante a espera, um gesto novo não faz nada.
    await tester.fling(find.byType(SlotSwipe), const Offset(-300, 0), 1000);
    await tester.pump(SlotSwipe.giveUp);
    await tester.pumpAndSettle();
    expect(state.index, 0);
    expect(_offset(tester), 0);
  });
}
