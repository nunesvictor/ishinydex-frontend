import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/features/auth/auth_providers.dart';
import 'package:ishinydex/features/auth/data/auth_repository.dart';
import 'package:ishinydex/features/auth/data/token_storage.dart';
import 'package:ishinydex/features/auth/presentation/login_page.dart';

import '../../helpers/helpers.dart';

class _SlowAuth implements AuthRepository {
  final completer = Completer<String>();

  @override
  Future<String> login({required String username, required String password}) =>
      completer.future;
}

void main() {
  testWidgets('valida campos obrigatórios', (tester) async {
    await pumpWidgetApp(
      tester,
      const LoginPage(),
      overrides: [
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entrar'));
    await tester.pump();
    expect(find.text('Campo obrigatório'), findsNWidgets(2));
  });

  testWidgets('mostra carregamento e erro', (tester) async {
    final auth = _SlowAuth();
    await pumpWidgetApp(
      tester,
      const LoginPage(),
      overrides: [
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
        authRepositoryProvider.overrideWithValue(auth),
      ],
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'ash');
    await tester.enterText(find.byType(TextFormField).at(1), 'x');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    auth.completer.completeError(Exception('Credenciais inválidas'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Credenciais inválidas'), findsOneWidget);
  });
}
