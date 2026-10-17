import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/widgets/web_safe_area.dart';

void main() {
  Future<MediaQueryData> pumpWith(
    WidgetTester tester,
    double top, {
    EdgeInsets padding = EdgeInsets.zero,
  }) async {
    late MediaQueryData seen;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(padding: padding, viewPadding: padding),
        child: WebSafeArea(
          readTop: () => top,
          child: Builder(
            builder: (context) {
              seen = MediaQuery.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return seen;
  }

  testWidgets('a barra de status da página vira o padding do topo (#290)', (
    tester,
  ) async {
    final data = await pumpWith(
      tester,
      59,
      padding: const EdgeInsets.only(bottom: 34),
    );
    expect(data.padding, const EdgeInsets.only(top: 59, bottom: 34));
    expect(data.viewPadding, const EdgeInsets.only(top: 59, bottom: 34));
  });

  testWidgets('sem barra por cima (ou já com padding maior), não muda', (
    tester,
  ) async {
    expect((await pumpWith(tester, 0)).padding, EdgeInsets.zero);
    expect(
      (await pumpWith(
        tester,
        20,
        padding: const EdgeInsets.only(top: 24),
      )).padding.top,
      24,
    );
  });

  testWidgets('a AppBar desce o título e pinta até o topo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WebSafeArea(
          readTop: () => 59,
          child: Scaffold(appBar: AppBar(title: const Text('Shiny'))),
        ),
      ),
    );
    expect(tester.getTopLeft(find.byType(AppBar)).dy, 0);
    expect(tester.getSize(find.byType(AppBar)).height, 59 + kToolbarHeight);
    expect(tester.getTopLeft(find.text('Shiny')).dy, greaterThan(59));
  });
}
