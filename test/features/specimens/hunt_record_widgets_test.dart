import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/hunt_record_card.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/hunt_record_section.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

import '../../helpers/helpers.dart';

const _sr = ShinyMethod(
  id: 'sr',
  label: 'Soft reset',
  units: ['resets'],
  versions: {'sword'},
);
const _random = ShinyMethod(
  id: 'random',
  label: 'Encontro aleatório',
  units: ['encounters', 'hours'],
  versions: {'sword'},
);
const _dynamax = ShinyMethod(
  id: 'dynamax',
  label: 'Dynamax Adventures',
  units: ['runs'],
  versions: {'shield'},
);

void main() {
  final today = DateTime(2026, 10, 9);

  Future<ValueNotifier<HuntRecord?>> pump(
    WidgetTester tester, {
    HuntRecord? initial,
    List<ShinyMethod> methods = const [_sr, _random],
    String? Function(String)? errorFor,
  }) async {
    final value = ValueNotifier<HuntRecord?>(initial);
    await pumpWidgetApp(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: ValueListenableBuilder(
            valueListenable: value,
            builder: (context, hunt, _) => HuntRecordSection(
              value: hunt,
              methods: methods,
              allMethods: const [_sr, _random, _dynamax],
              game: 'Sword',
              capturedAt: DateTime(2026, 10, 20),
              errorFor: errorFor,
              today: today,
              onChanged: (h) => value.value = h,
            ),
          ),
        ),
      ),
      size: const Size(400, 1200),
    );
    return value;
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('abre com hoje, escolhe método, unidade, horas e post', (
    tester,
  ) async {
    final value = await pump(tester);
    expect(find.text('Opcional: método, contagem, início e post'), findsOne);

    await tap(tester, find.text('Registro da caçada'));
    expect(value.value, HuntRecord(startedAt: today));
    expect(find.textContaining('11 dias até a captura'), findsOne);
    expect(find.text('Métodos de Sword, o jogo do OT'), findsOne);

    await tap(tester, find.byKey(const ValueKey('field-hunt-method')));
    await tap(tester, find.text('Soft reset').last);
    expect(value.value?.unit, 'resets');
    await tester.enterText(
      find.byKey(const ValueKey('field-hunt-count')),
      '4213',
    );
    await tester.pump();
    expect(value.value?.count, 4213);
    expect(find.text('Soft reset · 4.213 resets'), findsOne);

    // Outro método: a unidade vira a padrão dele; a contagem fica.
    await tap(tester, find.byKey(const ValueKey('field-hunt-method')));
    await tap(tester, find.text('Encontro aleatório').last);
    expect(value.value?.unit, 'encounters');
    expect(value.value?.count, 4213);

    // Horas: a contagem some e vira horas + minutos.
    await tap(tester, find.text('horas'));
    expect(value.value?.unit, 'hours');
    expect(value.value?.count, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('field-hunt-hours')),
      '38',
    );
    await tester.enterText(
      find.byKey(const ValueKey('field-hunt-minutes')),
      '30',
    );
    await tester.pump();
    expect(value.value?.count, 2310);
    await tester.enterText(find.byKey(const ValueKey('field-hunt-hours')), '');
    await tester.enterText(
      find.byKey(const ValueKey('field-hunt-minutes')),
      '',
    );
    await tester.pump();
    expect(value.value?.count, isNull);

    // Início: limpar e escolher no calendário.
    await tap(tester, find.byTooltip('Limpar o início'));
    expect(find.text('Não informado'), findsOne);
    await tap(tester, find.text('Início da caçada'));
    await tap(tester, find.text('OK'));
    expect(value.value?.startedAt, today);
    await tap(tester, find.text('Início da caçada'));
    await tap(tester, find.text('Cancelar'));
    expect(value.value?.startedAt, today);

    await tester.enterText(
      find.byKey(const ValueKey('field-hunt-post')),
      ' https://x ',
    );
    await tester.pump();
    expect(value.value?.postUrl, 'https://x');
    // Fechar não mexe no registro.
    await tap(tester, find.text('Registro da caçada'));
    expect(value.value?.postUrl, 'https://x');
  });

  testWidgets('preenchido: abre aberto; método fora do jogo; erros', (
    tester,
  ) async {
    await pump(
      tester,
      initial: const HuntRecord(method: 'dynamax', count: 150, unit: 'hours'),
      errorFor: (field) => field == 'huntPostUrl' ? 'Link inválido' : null,
    );
    expect(find.text('Não existe em Sword'), findsOne);
    expect(find.text('Dynamax Adventures · 2 h 30 min'), findsOne);
    expect(find.text('Link inválido'), findsOne);
    // A unidade guardada não é do método: vale a padrão dele.
    expect(find.text('runs'), findsOne);
  });

  testWidgets('horas guardadas preenchem os campos; GO sem método', (
    tester,
  ) async {
    await pump(
      tester,
      methods: const [],
      initial: HuntRecord(count: 150, unit: 'hours', startedAt: today),
      errorFor: (field) => field == 'huntStartedAt' ? 'Depois' : null,
    );
    expect(find.byKey(const ValueKey('field-hunt-method')), findsNothing);
    expect(find.text('Métodos de Sword, o jogo do OT'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('field-hunt-hours')))
          .controller
          ?.text,
      '2',
    );
    expect(find.text('Depois'), findsOne);
  });

  testWidgets('cartão do detalhe: resumo, datas e Ver post', (tester) async {
    final opened = <String>[];
    final backend = FakeBackend();
    await pumpWidgetApp(
      tester,
      Scaffold(
        body: Column(
          children: [
            HuntRecordCard(
              hunt: HuntRecord(
                method: 'sr',
                count: 4213,
                unit: 'resets',
                startedAt: DateTime(2026, 6, 12),
                postUrl: 'https://x',
              ),
              capturedAt: DateTime(2026, 9, 14),
            ),
            const HuntRecordCard(hunt: HuntRecord()),
          ],
        ),
      ),
      overrides: [
        fakeBackendProvider.overrideWithValue(backend),
        shinyMethodsProvider.overrideWithValue(
          (_, {fromGo = false}) => const [_sr],
        ),
        openLinkProvider.overrideWithValue(opened.add),
      ],
    );
    expect(find.text('Soft reset · 4.213 resets · 3 meses'), findsOne);
    expect(find.textContaining('Início'), findsOne);
    await tester.tap(find.text('Ver post'));
    expect(opened, ['https://x']);
  });
}
