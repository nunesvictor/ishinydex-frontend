import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/theme/app_theme.dart';

void main() {
  test('temas claro e escuro em Material 3', () {
    expect(AppTheme.light().colorScheme.brightness, Brightness.light);
    expect(AppTheme.dark().colorScheme.brightness, Brightness.dark);
    expect(
      AppTheme.light().pageTransitionsTheme.builders[TargetPlatform.iOS],
      isA<CupertinoPageTransitionsBuilder>(),
    );
  });

  test('barra de título: no iOS não muda de cor ao rolar (#205)', () {
    final scheme = AppTheme.light().colorScheme;
    final ios = AppTheme.appBarTheme(scheme, TargetPlatform.iOS)!;
    expect(ios.backgroundColor, scheme.surface);
    expect(ios.scrolledUnderElevation, 1);
    expect(ios.shadowColor, scheme.outlineVariant);
    expect(AppTheme.appBarTheme(scheme, TargetPlatform.android), isNull);
  });

  test('a Roboto vai junto com o app (#212)', () {
    expect(AppTheme.light().textTheme.bodyMedium!.fontFamily, 'Roboto');
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: ${AppTheme.fontFamily}'));
    for (final weight in ['Regular', 'Medium', 'Bold']) {
      final asset = 'assets/fonts/Roboto-$weight.ttf';
      expect(pubspec, contains(asset));
      expect(File(asset).existsSync(), isTrue, reason: asset);
    }
  });

  testWidgets('iOS: a barra rolada fica da cor do fundo (#215)', (
    tester,
  ) async {
    final theme = AppTheme.light().copyWith(
      appBarTheme: AppTheme.appBarTheme(
        AppTheme.light().colorScheme,
        TargetPlatform.iOS,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          appBar: AppBar(title: const Text('Espécimes')),
          body: ListView(
            children: [
              for (var i = 0; i < 50; i++) ListTile(title: Text('$i')),
            ],
          ),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    final bar = find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(Material),
    );
    final material = tester.widget<Material>(bar.first);
    // Rolada: a elevação da linha fina, sem a tinta que escurece.
    expect(material.elevation, 1);
    expect(material.color, theme.colorScheme.surface);
    expect(material.surfaceTintColor, Colors.transparent);
    // E a cor de fato pintada (o Material aplica a tinta por cima).
    final physical = tester.widget<PhysicalModel>(
      find.descendant(of: bar.first, matching: find.byType(PhysicalModel)),
    );
    expect(physical.color, theme.colorScheme.surface);
  });
}
