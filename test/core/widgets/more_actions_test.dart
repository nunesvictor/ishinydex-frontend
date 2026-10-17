import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/widgets/more_actions.dart';
import 'package:ishinydex/l10n/app_localizations.dart';

void main() {
  // O pior caso real (#298): visitando o Champions, com duas ações
  // desabilitadas e as explicações mais longas.
  List<MoreAction> actions(List<String> log) => [
    MoreAction(
      icon: Icons.emoji_events,
      label: 'Voltou do Champions',
      subtitle: 'Libera o envio para saves',
      onSelected: () => log.add('voltou'),
    ),
    MoreAction(
      icon: Icons.flight_takeoff,
      label: 'Enviar para jogo…',
      subtitle: 'Está visitando o Champions',
      enabled: false,
      onSelected: () => log.add('enviar'),
    ),
    MoreAction(
      icon: Icons.warning_amber_rounded,
      label: 'Libertar',
      subtitle: 'Não dá enquanto visita o Champions',
      destructive: true,
      onSelected: () => log.add('libertar'),
    ),
    MoreAction(
      icon: Icons.move_up,
      label: 'Retirar do slot',
      subtitle: 'Volta para o inventário, disponível',
      onSelected: () => log.add('retirar'),
    ),
  ];

  Future<void> pump(
    WidgetTester tester,
    Widget bar, {
    double width = 320,
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: Scaffold(body: Column(children: [const Spacer(), bar])),
      ),
    );
  }

  testWidgets('o "⋯" abre um menu preso ao botão, sem folha por cima', (
    tester,
  ) async {
    final log = <String>[];
    await pump(
      tester,
      DetailActionBar(
        primary: FilledButton(onPressed: () {}, child: const Text('Editar')),
        actions: actions(log),
      ),
    );
    await tester.tap(find.byTooltip('Mais ações'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(MenuItemButton), findsNWidgets(4));

    // Na ordem, com o Libertar no fim, depois do separador.
    final labels = [
      'Voltou do Champions',
      'Enviar para jogo…',
      'Retirar do slot',
      'Libertar',
    ];
    for (var i = 1; i < labels.length; i++) {
      expect(
        tester.getTopLeft(find.text(labels[i])).dy,
        greaterThan(tester.getTopLeft(find.text(labels[i - 1])).dy),
        reason: labels[i],
      );
    }
    final divider = tester.getCenter(find.byType(Divider)).dy;
    expect(divider, greaterThan(tester.getCenter(find.text(labels[2])).dy));
    expect(divider, lessThan(tester.getCenter(find.text('Libertar')).dy));
    // A explicação numa segunda linha, inclusive o motivo da desabilitada.
    expect(find.text('Está visitando o Champions'), findsOneWidget);

    // Desabilitada: não responde, e o menu continua aberto.
    await tester.tap(find.text('Enviar para jogo…'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(log, isEmpty);
    expect(find.byType(MenuItemButton), findsNWidgets(4));

    // Tocar de novo no "⋯" fecha.
    await tester.tap(find.byTooltip('Mais ações'));
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);

    // Escolher uma ação fecha o menu e a chama.
    await tester.tap(find.byTooltip('Mais ações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retirar do slot'));
    await tester.pumpAndSettle();
    expect(log, ['retirar']);
    expect(find.byType(MenuItemButton), findsNothing);
  });

  testWidgets('sem ação principal, "Mais ações" ocupa a barra', (tester) async {
    final log = <String>[];
    await pump(tester, DetailActionBar(actions: actions(log)));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Mais ações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voltou do Champions'));
    await tester.pumpAndSettle();
    expect(log, ['voltou']);
  });

  testWidgets('sem ações, não há o botão', (tester) async {
    await pump(
      tester,
      DetailActionBar(
        primary: FilledButton(onPressed: () {}, child: const Text('Depositar')),
        actions: const [],
      ),
    );
    expect(find.byTooltip('Mais ações'), findsNothing);
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('pior caso cabe na tela de 320 px (texto ${scale}x)', (
      tester,
    ) async {
      await pump(
        tester,
        DetailActionBar(
          primary: FilledButton(onPressed: () {}, child: const Text('Editar')),
          actions: actions([]),
        ),
        textScaler: TextScaler.linear(scale),
      );
      await tester.tap(find.byTooltip('Mais ações'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final item in find.byType(MenuItemButton).evaluate()) {
        final rect = tester.getRect(find.byWidget(item.widget));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
      }
    });
  }
}
