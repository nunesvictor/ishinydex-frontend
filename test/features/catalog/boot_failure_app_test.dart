import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/features/catalog/presentation/boot_failure_app.dart';

void main() {
  testWidgets('formato mais novo: mostra o motivo e tenta de novo', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      BootFailureApp(
        error: const FormatException('Os dados são de uma versão mais nova.'),
        onRetry: () => retries++,
      ),
    );
    expect(find.text('Não foi possível abrir o iShinyDex.'), findsOneWidget);
    expect(find.text('Os dados são de uma versão mais nova.'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    expect(retries, 1);
  });

  testWidgets('outro erro: sugere conferir a conexão', (tester) async {
    await tester.pumpWidget(
      BootFailureApp(error: StateError('x'), onRetry: () {}),
    );
    expect(find.textContaining('Confira a conexão'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  });
}
