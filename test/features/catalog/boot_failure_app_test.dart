import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/l10n/app_language.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/features/catalog/presentation/boot_failure_app.dart';

void main() {
  testWidgets('formato mais novo: mostra o motivo e tenta de novo', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      BootFailureApp(
        error: const DataFailure(Problem.dataFromNewerApp()),
        onRetry: () => retries++,
        language: AppLanguage.pt,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível abrir o iShinyDex.'), findsOneWidget);
    expect(
      find.text('Os dados foram salvos por uma versão mais nova do app.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Tentar novamente'));
    expect(retries, 1);
  });

  testWidgets('outro erro: sugere conferir a conexão (no idioma do aparelho)', (
    tester,
  ) async {
    await tester.pumpWidget(
      BootFailureApp(error: StateError('x'), onRetry: () {}),
    );
    await tester.pumpAndSettle();
    expect(find.text("Couldn't open iShinyDex."), findsOneWidget);
    expect(find.textContaining('Check your connection'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  });
}
