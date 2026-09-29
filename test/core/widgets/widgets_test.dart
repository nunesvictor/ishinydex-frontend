import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/confirm_dialog.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/core/widgets/progress_badge.dart';

import '../../helpers/helpers.dart';

void main() {
  group('PokemonSprite', () {
    testWidgets('sem url mostra o placeholder', (tester) async {
      await pumpWidgetApp(tester, const PokemonSprite(url: null));
      expect(find.byIcon(Icons.catching_pokemon), findsOneWidget);
    });

    testWidgets('imagem com erro cai no placeholder', (tester) async {
      await pumpWidgetApp(
        tester,
        const PokemonSprite(url: 'http://x/1.png', semanticLabel: 'bulba'),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.catching_pokemon), findsOneWidget);
    });
  });

  testWidgets('ProgressBadge mostra contagem e percentual', (tester) async {
    await pumpWidgetApp(
      tester,
      const Column(
        children: [
          ProgressBadge(registered: 1, total: 3),
          ProgressBadge(registered: 3, total: 3),
          ProgressBadge(registered: 0, total: 0),
        ],
      ),
    );
    expect(find.text('1/3 (33%)'), findsOneWidget);
    expect(find.text('3/3 (100%)'), findsOneWidget);
    expect(find.text('0/0 (0%)'), findsOneWidget);
  });

  testWidgets('views de estado', (tester) async {
    var retried = false;
    await pumpWidgetApp(
      tester,
      Column(
        children: [
          const SizedBox(height: 50, child: LoadingView()),
          ErrorView(error: 'falhou', onRetry: () => retried = true),
          const ErrorView(error: 'sem retry'),
          const EmptyView(message: 'vazio'),
        ],
      ),
    );
    expect(find.text('falhou'), findsOneWidget);
    expect(find.text('vazio'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    expect(retried, true);
  });

  group('showConfirmDialog', () {
    Future<bool?> open(WidgetTester tester, TargetPlatform platform) async {
      bool? result;
      await pumpWidgetApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showConfirmDialog(
              context,
              title: 'Título',
              message: 'Mensagem',
              destructive: true,
              icon: Icons.warning_amber_rounded,
            ),
            child: const Text('abrir'),
          ),
        ),
        platform: platform,
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Mensagem'), findsOneWidget);
      return result;
    }

    testWidgets('confirmar (Material)', (tester) async {
      await open(tester, TargetPlatform.android);
      expect(find.byType(TextButton), findsWidgets);
      // Destrutivo: confirmação na cor de erro e ícone de alerta.
      final context = tester.element(find.text('Confirmar'));
      expect(
        DefaultTextStyle.of(context).style.color,
        Theme.of(context).colorScheme.error,
      );
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(find.text('Mensagem'), findsNothing);
    });

    testWidgets('cancelar (Cupertino) retorna false', (tester) async {
      bool? result;
      await setScreenSize(tester, compactSize);
      await pumpWidgetApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showConfirmDialog(
              context,
              title: 'T',
              message: 'M',
            ),
            child: const Text('abrir'),
          ),
        ),
        platform: TargetPlatform.iOS,
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDialogAction), findsNWidgets(2));
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(result, false);
    });

    testWidgets('fechar sem escolher retorna false', (tester) async {
      bool? result;
      await pumpWidgetApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showConfirmDialog(
              context,
              title: 'T',
              message: 'M',
            ),
            child: const Text('abrir'),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(result, false);
    });
  });
}
