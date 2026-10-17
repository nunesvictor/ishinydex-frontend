import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/theme/app_palette.dart';
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

  test('barra de título: grafite fixo nos dois temas (#290)', () {
    for (final brightness in Brightness.values) {
      final colors = AppPalette.classic.of(brightness);
      final bar =
          (brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light())
              .appBarTheme;
      expect(bar.backgroundColor, const Color(0xFF1C1B1B));
      expect(bar.foregroundColor, const Color(0xFFFFFFFF));
      expect(bar.iconTheme!.color, colors.onTopBar);
      expect(bar.actionsIconTheme!.color, colors.onTopBar);
      expect(bar.scrolledUnderElevation, 0);
      expect(bar.systemOverlayStyle, SystemUiOverlayStyle.light);
      // No escuro, a linha de 1 px separa a barra do fundo.
      expect(
        bar.shape,
        brightness == Brightness.dark
            ? Border(bottom: BorderSide(color: colors.outlineVariant))
            : isNull,
      );
    }
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

  testWidgets(
    'a barra rolada continua grafite em todas as plataformas (#215)',
    variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
    (tester) async {
      final theme = AppTheme.light();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Espécimes'),
              actions: [
                Builder(
                  builder: (context) => TextButton(
                    style: AppTheme.topBarTextButton(context),
                    onPressed: () {},
                    child: const Text('Salvar'),
                  ),
                ),
              ],
            ),
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
      expect(material.color, AppPalette.classic.light.topBar);
      expect(material.surfaceTintColor, Colors.transparent);
      final physical = tester.widget<PhysicalModel>(
        find.descendant(of: bar.first, matching: find.byType(PhysicalModel)),
      );
      expect(physical.color, AppPalette.classic.light.topBar);
      // Título e "Salvar" em branco sobre o grafite.
      final title = tester.widget<RichText>(
        find.descendant(
          of: find.text('Espécimes'),
          matching: find.byType(RichText),
        ),
      );
      expect(title.text.style!.color, AppPalette.classic.light.onTopBar);
      final save = tester.widget<RichText>(
        find.descendant(
          of: find.text('Salvar'),
          matching: find.byType(RichText),
        ),
      );
      expect(save.text.style!.color, AppPalette.classic.light.onTopBar);
    },
  );
}
