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
      expect(find.bySemanticsLabel(RegExp('HP 255, Ataque 0')), findsOneWidget);
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
