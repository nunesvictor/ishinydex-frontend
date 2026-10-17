import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/theme/app_palette.dart';
import 'package:ishinydex/core/theme/app_theme.dart';

import '../../helpers/contrast.dart';

void main() {
  for (final brightness in Brightness.values) {
    final colors = AppPalette.classic.of(brightness);
    final theme = brightness == Brightness.dark
        ? AppTheme.dark()
        : AppTheme.light();
    final scheme = theme.colorScheme;

    group('Clássico (${brightness.name})', () {
      test('o tema usa as cores da paleta', () {
        expect(scheme.brightness, brightness);
        expect(scheme.primary, colors.primary);
        expect(scheme.surface, colors.surface);
        expect(scheme.secondaryContainer, colors.secondaryContainer);
        // Slot faltante e registrado (`slot_tile.dart`).
        expect(scheme.surfaceContainerLow, colors.surfaceContainerLow);
        expect(scheme.surfaceContainerHighest, colors.surfaceContainerHighest);
        // Sem a tinta vermelha nas superfícies elevadas.
        expect(scheme.surfaceTint, colors.onSurface);
        // Os avisos (SnackBar, #278).
        expect(scheme.inverseSurface, colors.inverseSurface);
        expect(scheme.onInverseSurface, colors.onInverseSurface);
        expect(scheme.inversePrimary, colors.inversePrimary);
        expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
        final extension = theme.extension<AppColors>()!;
        expect(extension.success, colors.success);
        expect(extension.huntBadge, colors.huntBadge);
      });

      test('contraste: texto 4,5, ícones 3', () {
        for (final (fg, bg, min, name) in [
          (scheme.onSurface, scheme.surface, 4.5, 'texto'),
          (scheme.onSurfaceVariant, scheme.surface, 4.5, 'texto secundário'),
          (
            scheme.onSurfaceVariant,
            scheme.surfaceContainerHighest,
            4.5,
            'texto no slot registrado',
          ),
          (scheme.onPrimary, scheme.primary, 4.5, 'botão'),
          (
            scheme.onPrimaryContainer,
            scheme.primaryContainer,
            4.5,
            'container primário',
          ),
          (
            scheme.onSecondaryContainer,
            scheme.secondaryContainer,
            4.5,
            'filtro marcado',
          ),
          (scheme.primary, scheme.surface, 3, 'ação sobre o fundo'),
          (colors.onHuntBadge, colors.huntBadge, 3, 'selo da caçada'),
          (colors.success, scheme.surface, 3, 'concluído'),
          (scheme.onInverseSurface, scheme.inverseSurface, 4.5, 'aviso'),
          (scheme.inversePrimary, scheme.inverseSurface, 4.5, 'ação do aviso'),
        ]) {
          expect(contrast(fg, bg), greaterThanOrEqualTo(min), reason: name);
        }
      });
    });
  }

  testWidgets('AppColors.of: sem a extensão no tema, as da Clássico', (
    tester,
  ) async {
    late AppColors colors;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Builder(
          builder: (context) {
            colors = AppColors.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(colors.success, AppPalette.classic.dark.success);
  });

  test('AppColors: copyWith e lerp (a animação entre claro e escuro)', () {
    final light = AppPalette.classic.light.extension;
    final dark = AppPalette.classic.dark.extension;
    expect(light.copyWith().shiny, light.shiny);
    expect(
      light.copyWith(shiny: dark.shiny, success: dark.success).shiny,
      dark.shiny,
    );
    expect(
      light
          .copyWith(huntBadge: dark.huntBadge, onHuntBadge: dark.onHuntBadge)
          .onHuntBadge,
      dark.onHuntBadge,
    );
    expect(light.lerp(null, 0.5), same(light));
    expect(light.lerp(dark, 1).success, dark.success);
    expect(light.lerp(dark, 0).huntBadge, light.huntBadge);
  });
}
