import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ishinydex/app.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/personal_dex/data/last_dex_storage.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';

/// Fluxo completo no navegador, na demonstração:
/// abrir dex → selecionar slot faltante → depositar.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('abrir um dex e depositar', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: noRetry,
        overrides: [
          envProvider.overrideWithValue(const Env()),
          fakeBackendProvider.overrideWithValue(FakeBackend.seeded()),
          lastDexStorageProvider.overrideWithValue(InMemoryLastDexStorage()),
        ],
        child: const IShinyDexApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Dois dexes: o app abre na lista.
    await tester.tap(find.text('Shiny Living Dex'));
    await tester.pumpAndSettle();
    expect(find.textContaining('HOME 1'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('slot-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Depositar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saur'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Depositar'));
    await tester.pumpAndSettle();

    expect(find.text('Specimen depositado.'), findsOneWidget);
  });
}
