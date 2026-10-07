import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/features/sync/presentation/sync_page.dart';
import 'package:ishinydex/features/sync/sync_providers.dart';

import '../../helpers/helpers.dart';

/// Um controlador em que o teste escolhe a fase.
class _Phases extends SyncController {
  @override
  SyncState build() => const SyncState();

  void go(SyncPhase phase) => state = SyncState(phase: phase, connected: true);
}

void main() {
  Future<_Phases> pump(WidgetTester tester) async {
    await pumpWidgetApp(
      tester,
      const Scaffold(body: SyncActivityBar()),
      overrides: [syncControllerProvider.overrideWith(_Phases.new)],
    );
    return ProviderScope.containerOf(
      tester.element(find.byType(SyncActivityBar)),
    ).read(syncControllerProvider.notifier) as _Phases;
  }

  final bar = find.byType(LinearProgressIndicator);

  testWidgets('sync rápido: a faixa não aparece', (tester) async {
    final sync = await pump(tester);
    sync.go(SyncPhase.syncing);
    await tester.pump(const Duration(milliseconds: 300));
    expect(bar, findsNothing);
    sync.go(SyncPhase.idle);
    await tester.pump(const Duration(seconds: 1));
    expect(bar, findsNothing);
  });

  testWidgets('sync demorado: a faixa aparece e some no fim', (tester) async {
    final sync = await pump(tester);
    sync.go(SyncPhase.syncing);
    await tester.pump(SyncActivityBar.showDelay);
    await tester.pump();
    expect(bar, findsOneWidget);
    sync.go(SyncPhase.offline);
    await tester.pump();
    expect(bar, findsNothing);
  });

  testWidgets('sai da tela no meio da espera', (tester) async {
    final sync = await pump(tester);
    sync.go(SyncPhase.syncing);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    // Sem timer pendente no fim do teste.
  });
}
