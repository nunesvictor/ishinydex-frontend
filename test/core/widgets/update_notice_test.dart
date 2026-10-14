import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/web/browser_stub.dart' as stub;
import 'package:ishinydex/core/widgets/update_notice.dart';

class _FakeUpdates implements AppUpdates {
  VoidCallback? ready;
  int reloads = 0;

  @override
  void onReady(VoidCallback callback) => ready = callback;

  @override
  void reload() => reloads++;
}

void main() {
  testWidgets('versão nova com o app aberto: aviso e Recarregar', (
    tester,
  ) async {
    final updates = _FakeUpdates();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appUpdatesProvider.overrideWithValue(updates)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('pt'),
          home: Scaffold(body: UpdateNotice(child: Text('app'))),
        ),
      ),
    );
    expect(find.text('app'), findsOne);
    expect(find.text('Nova versão do iShinyDex disponível.'), findsNothing);

    updates.ready!();
    await tester.pumpAndSettle();
    expect(find.text('Nova versão do iShinyDex disponível.'), findsOne);
    await tester.tap(find.text('Recarregar'));
    await tester.pumpAndSettle();
    expect(updates.reloads, 1);

    // Depois de sair da árvore, o aviso não tenta mais aparecer.
    await tester.pumpWidget(const SizedBox());
    updates.ready!();
    await tester.pump();
  });

  test('no navegador de verdade; fora dele, nada', () {
    expect(
      ProviderContainer().read(appUpdatesProvider),
      isA<BrowserAppUpdates>(),
    );
    const BrowserAppUpdates().onReady(() => fail('fora do navegador'));
    expect(const BrowserAppUpdates().reload, throwsUnsupportedError);
    stub.onAppUpdateReady(() => fail('fora do navegador'));
    expect(stub.reloadPage, throwsUnsupportedError);
  });
}
