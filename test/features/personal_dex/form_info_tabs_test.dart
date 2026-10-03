import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/base_stats_chart.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/form_info_tabs.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/species_info.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/api_fixtures.dart';
import '../../helpers/helpers.dart';
import '../../helpers/mocks.dart';

FormRef _ref(int id, {String formName = ''}) => FormRef(
  id: id,
  name: 'forma-$id',
  formName: formName,
  pokeapiId: id,
  spriteUrl: 'http://x/$id.png',
  shinySpriteUrl: 'http://x/shiny/$id.png',
);

void main() {
  group('BaseStatsChart', () {
    testWidgets('sem status: só o aviso', (tester) async {
      await pumpWidgetApp(tester, const BaseStatsChart(stats: []));
      expect(find.text('Sem status base para esta forma.'), findsOneWidget);
    });

    testWidgets('acima da escala encosta na borda; vários EV; redesenha', (
      tester,
    ) async {
      const stats = [
        FormStat(stat: 'hp', baseStat: 255, effort: 2),
        FormStat(stat: 'defense', baseStat: 10, effort: 1),
      ];
      await pumpWidgetApp(
        tester,
        const Center(child: BaseStatsChart(stats: stats)),
      );
      // Total e os dois EV; os status que faltam valem 0 no hexágono.
      expect(find.textContaining('Total '), findsOneWidget);
      expect(
        find.textContaining('dá 2 EV de HP e 1 EV de Defesa'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('HP 255; Ataque 0')), findsOneWidget);
      // Outros status: o painter se redesenha (shouldRepaint).
      await pumpWidgetApp(
        tester,
        const Center(
          child: BaseStatsChart(stats: [FormStat(stat: 'hp', baseStat: 45)]),
        ),
      );
      expect(find.textContaining(' · dá'), findsNothing);
    });
  });

  group('BaseStatsChart com natureza', () {
    const stats = [
      FormStat(stat: 'hp', baseStat: 78),
      FormStat(stat: 'attack', baseStat: 84),
      FormStat(stat: 'special-attack', baseStat: 109),
    ];
    const modest = Choice(
      value: 'modest',
      label: 'Modest',
      increased: 'special-attack',
      decreased: 'attack',
    );

    testWidgets('aumentado em vermelho com ↑, diminuído em azul com ↓', (
      tester,
    ) async {
      await pumpWidgetApp(
        tester,
        const Center(
          child: BaseStatsChart(stats: stats, nature: modest),
        ),
      );
      expect(
        find.bySemanticsLabel(
          RegExp(
            'Ataque 84, diminuído pela natureza.*'
            'Atq. Esp. 109, aumentado pela natureza',
          ),
        ),
        findsOneWidget,
      );
      final caption = tester.widget<RichText>(
        find.descendant(
          of: find.byType(Text),
          matching: find.byWidgetPredicate(
            (w) =>
                w is RichText &&
                w.text.toPlainText().startsWith('Natureza Modest'),
          ),
        ),
      );
      expect(caption.text.toPlainText(), contains('↑ Atq. Esp.'));
      expect(caption.text.toPlainText(), contains('↓ Ataque'));
      final spans = <TextSpan>[];
      caption.text.visitChildren((span) {
        if (span is TextSpan) spans.add(span);
        return true;
      });
      Color? colorOf(String text) =>
          spans.firstWhere((s) => s.text?.contains(text) ?? false).style?.color;
      expect(colorOf('↑'), BaseStatsChart.increasedColor(Brightness.light));
      expect(colorOf('↓'), BaseStatsChart.decreasedColor(Brightness.light));

      // Outra natureza: o painter se redesenha.
      await pumpWidgetApp(
        tester,
        const Center(
          child: BaseStatsChart(
            stats: stats,
            nature: Choice(
              value: 'adamant',
              label: 'Adamant',
              increased: 'attack',
              decreased: 'special-attack',
            ),
          ),
        ),
      );
      expect(find.textContaining('Natureza Adamant'), findsOneWidget);
    });

    testWidgets('natureza neutra não pinta nada', (tester) async {
      await pumpWidgetApp(
        tester,
        const Center(
          child: BaseStatsChart(
            stats: stats,
            nature: Choice(value: 'hardy', label: 'Hardy'),
          ),
        ),
      );
      expect(find.textContaining('Natureza Hardy (neutra)'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('natureza')), findsNothing);
    });

    test('no tema escuro, cores mais claras', () {
      expect(
        BaseStatsChart.increasedColor(Brightness.dark),
        isNot(BaseStatsChart.increasedColor(Brightness.light)),
      );
      expect(
        BaseStatsChart.decreasedColor(Brightness.dark),
        isNot(BaseStatsChart.decreasedColor(Brightness.light)),
      );
    });
  });

  group('SpeciesInfo', () {
    testWidgets('fora de um dex: outras formas e grade, sem navegação', (
      tester,
    ) async {
      final form = FormDetail.fromJson(formDetailJson).copyWith(
        otherForms: [
          _ref(5, formName: 'mega-x'),
          _ref(6),
        ],
        genderRate: -1,
      );
      await pumpWidgetApp(tester, Scaffold(body: SpeciesInfo(form: form)));
      expect(find.text('Outras formas'), findsOneWidget);
      expect(find.text('Mega X'), findsOneWidget);
      expect(find.text('Forma 6'), findsOneWidget);
      expect(find.text('Linha evolutiva'), findsNothing);
      expect(find.text('Sem gênero'), findsOneWidget);
    });

    test('genderRatio e decimal', () {
      expect(genderRatio(-1), 'Sem gênero');
      expect(genderRatio(0), 'Só macho');
      expect(genderRatio(8), 'Só fêmea');
      expect(genderRatio(1), '♂ 87,5% · ♀ 12,5%');
      expect(genderRatio(4), '♂ 50% · ♀ 50%');
      expect(decimal(1.7), '1,7');
      expect(decimal(50.0), '50');
    });
  });

  testWidgets('FormInfoTabs: erro ao carregar a forma, com retry', (
    tester,
  ) async {
    final repository = MockSpecimenRepository();
    var calls = 0;
    when(() => repository.fetchForm(1)).thenAnswer((_) async {
      if (calls++ == 0) throw const NetworkFailure();
      return FormDetail.fromJson(formDetailJson);
    });
    await pumpWidgetApp(
      tester,
      const SingleChildScrollView(
        child: FormInfoTabs(formId: 1, summary: Text('resumo')),
      ),
      overrides: [specimenRepositoryProvider.overrideWithValue(repository)],
    );
    expect(find.text('resumo'), findsOneWidget);

    await tester.tap(find.text('Status'));
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível carregar os detalhes da forma.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.byType(BaseStatsChart), findsOneWidget);
  });
}
