import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/widgets/status_tint.dart';

void main() {
  test('css: #RRGGBB sem a transparência', () {
    expect(StatusTint.css(const Color(0xFFFAFAFA)), '#fafafa');
    expect(StatusTint.css(const Color(0x80131313)), '#131313');
  });

  testWidgets('grava a cor ao abrir e a cada troca, só quando muda', (
    tester,
  ) async {
    final applied = <String>[];
    Widget tint(Color color) =>
        StatusTint(color: color, apply: applied.add, child: const SizedBox());
    await tester.pumpWidget(tint(const Color(0xFFFAFAFA)));
    expect(applied, ['#fafafa']);
    await tester.pumpWidget(tint(const Color(0xFFFAFAFA)));
    expect(applied, ['#fafafa']);
    await tester.pumpWidget(tint(const Color(0xFF131313)));
    expect(applied, ['#fafafa', '#131313']);
  });

  testWidgets('fora do navegador, a gravação padrão não faz nada', (
    tester,
  ) async {
    await tester.pumpWidget(
      const StatusTint(color: Colors.black, child: SizedBox()),
    );
    expect(find.byType(SizedBox), findsOneWidget);
  });
}
