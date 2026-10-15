import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/slot_swipe.dart';

import '../../helpers/helpers.dart';

/// Slots 0 a [last], numa área de 400 px; as setas de fora mudam o slot com
/// a direção do passo, como o painel do dex.
class _Harness extends StatefulWidget {
  const _Harness({this.last = 2, this.stuck = false, this.previews = false});

  final int last;

  /// Com a prévia do vizinho de cada lado (#267).
  final bool previews;

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
        previous: widget.previews && index > 0
            ? Text('prévia ${index - 1}')
            : null,
        next: widget.previews && index < widget.last
            ? Text('prévia ${index + 1}')
            : null,
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
  bool previews = false,
  Locale locale = portuguese,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: _Harness(last: last, stuck: stuck, previews: previews),
        ),
      ),
    ),
  );
  return tester.state<_HarnessState>(find.byType(_Harness));
}

/// O deslocamento atual do conteúdo, em px.
double _offset(WidgetTester tester) =>
    _x(tester, const ValueKey('swipe-current'));

/// O deslocamento do que tem a chave [key] (o slot atual ou uma prévia).
double _x(WidgetTester tester, Key key) =>
    tester.widget<Transform>(find.byKey(key)).transform.getTranslation().x;

/// O deslocamento da prévia de um lado (1: direita; -1: esquerda).
double _previewX(WidgetTester tester, int side) => tester
    .widget<Transform>(
      find
          .ancestor(
            of: find.byKey(ValueKey('swipe-preview-$side')),
            matching: find.byType(Transform),
          )
          .first,
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

  group('prévia do vizinho (#267)', () {
    testWidgets('o vizinho entra junto com o dedo, do lado oposto', (
      tester,
    ) async {
      await _pump(tester, previews: true);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(SlotSwipe)),
      );
      await gesture.moveBy(const Offset(-30, 0));
      await gesture.moveBy(const Offset(-100, 0));
      await tester.pump();
      expect(find.text('prévia 1'), findsOne);
      // Encostado no atual: 400 px à direita dele.
      expect(_previewX(tester, 1), _offset(tester) + 400);
      await gesture.up();
      await tester.pumpAndSettle();
      // Voltou: a prévia some.
      expect(find.text('prévia 1'), findsNothing);
    });

    testWidgets('completar não dá salto: o novo já estava no lugar', (
      tester,
    ) async {
      final state = await _pump(tester, previews: true);
      await tester.fling(find.byType(SlotSwipe), const Offset(-300, 0), 1000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.index, 1);
      await tester.pump();
      expect(_offset(tester), 0);
      expect(find.text('slot 1'), findsOne);

      // E para trás: a prévia do anterior, pela esquerda.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(SlotSwipe)),
      );
      await gesture.moveBy(const Offset(30, 0));
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();
      expect(find.text('prévia 0'), findsOne);
      expect(_previewX(tester, -1), _offset(tester) - 400);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('começo e fim do dex: "Início do dex" e "Fim do dex"', (
      tester,
    ) async {
      await _pump(tester, previews: true, last: 0);
      for (final (dx, text) in [
        (-200.0, 'Fim do dex'),
        (200.0, 'Início do dex'),
      ]) {
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(SlotSwipe)),
        );
        await gesture.moveBy(Offset(dx.sign * 30, 0));
        await gesture.moveBy(Offset(dx, 0));
        await tester.pump();
        expect(find.text(text), findsOne, reason: text);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.text(text), findsNothing);
      }
    });

    testWidgets('em inglês', (tester) async {
      await _pump(tester, last: 0, locale: english);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(SlotSwipe)),
      );
      await gesture.moveBy(const Offset(-30, 0));
      await gesture.moveBy(const Offset(-200, 0));
      await tester.pump();
      expect(find.text('End of the dex'), findsOne);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a prévia da box vizinha, nos dois sentidos', (tester) async {
      for (final (forward, title, hint) in [
        (true, 'PRÓXIMA BOX', 'Solte para ir ao primeiro slot dela'),
        (false, 'BOX ANTERIOR', 'Solte para ir ao último slot dela'),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            locale: portuguese,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: BoxPreview(boxName: 'HOME 2', forward: forward),
            ),
          ),
        );
        expect(find.text(title), findsOne);
        expect(find.text('HOME 2'), findsOne);
        expect(find.text(hint), findsOne);
      }
    });
  });
}
