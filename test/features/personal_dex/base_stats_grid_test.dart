import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/theme/app_theme.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/base_stats_chart.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';

import '../../helpers/contrast.dart';
import '../../helpers/helpers.dart';

void main() {
  // A grade do hexágono aparece nos dois temas da identidade C (#263).
  for (final theme in [AppTheme.light(), AppTheme.dark()]) {
    testWidgets('grade visível (${theme.brightness.name})', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          locale: portuguese,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Center(
            child: BaseStatsChart(stats: [FormStat(stat: 'hp', baseStat: 45)]),
          ),
        ),
      );
      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(BaseStatsChart),
          matching: find.byType(CustomPaint),
        ),
      );
      // O painter é privado: o campo é lido pelo nome.
      final grid = (paint.painter! as dynamic).grid as Color;
      final scheme = theme.colorScheme;
      expect(grid, scheme.outline);
      expect(contrast(grid, scheme.surface), greaterThan(2));
    });
  }
}
