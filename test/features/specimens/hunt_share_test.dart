import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/web/browser_stub.dart' as stub;
import 'package:ishinydex/core/web/share_outcome.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/hunt_share_sheet.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/hunt_record_card.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/hunt_share_card.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

import '../../fixtures/api_fixtures.dart';
import '../../helpers/helpers.dart';

final _full = HuntShareData(
  name: 'Jangmo-o',
  dexNumber: '#0782',
  spriteUrl: null,
  version: 'ultra-moon',
  startedAt: DateTime(2026, 10, 12),
  capturedAt: DateTime(2026, 10, 17),
  method: 'SOS',
  count: 312,
  unit: 'encounters',
  odds: 273,
  multiple: 0.6,
  bestChain: 38,
);

/// Um PNG de mentira: a captura de verdade tem o próprio teste.
final _png = Uint8List.fromList([137, 80, 78, 71]);

class _Sharer {
  ShareOutcome outcome = ShareOutcome.shared;
  final calls = <(Uint8List, String, String)>[];

  Future<ShareOutcome> call(
    Uint8List bytes, {
    required String name,
    required String type,
  }) async {
    calls.add((bytes, name, type));
    return outcome;
  }
}

void main() {
  group('HuntShareCard', () {
    Future<void> pump(
      WidgetTester tester,
      HuntShareData data, {
      Locale locale = portuguese,
    }) => pumpWidgetApp(
      tester,
      Center(child: HuntShareCard(data: data)),
      locale: locale,
      size: const Size(500, 700),
    );

    testWidgets('o card da v3: números, detalhes e a marca do app', (
      tester,
    ) async {
      await pump(tester, _full);
      expect(find.text('SHINY ENCONTRADO'), findsOne);
      expect(find.text('Jangmo-o'), findsOne);
      expect(find.text('#0782 · Ultra Moon · 17/10/2026'), findsOne);
      for (final text in [
        '312',
        'encontros',
        '5 dias',
        'de caçada',
        '1/273',
        'odds no fim',
      ]) {
        expect(find.text(text), findsOne, reason: text);
      }
      expect(
        find.text('SOS · maior cadeia 38 · achado em 0,6× as odds'),
        findsOne,
      );
      expect(find.text('iShinyDex'), findsOne);
      expect(tester.getSize(find.byType(HuntShareCard)), HuntShareCard.size);
    });

    testWidgets('em horas, odds pequenas e sem unidade', (tester) async {
      await pump(
        tester,
        const HuntShareData(
          name: 'Eevee',
          dexNumber: '#0133',
          spriteUrl: null,
          count: 150,
          unit: 'hours',
          odds: 4.5,
        ),
      );
      expect(find.text('2 h 30 min'), findsOne);
      expect(find.text('horas'), findsOne);
      expect(find.text('1/4,5'), findsOne);
      await pump(
        tester,
        const HuntShareData(
          name: 'Eevee',
          dexNumber: '#0133',
          spriteUrl: null,
          count: 1200,
        ),
      );
      expect(find.text('1.200'), findsOne);
    });

    testWidgets('só o essencial: sem números nem detalhes', (tester) async {
      await pump(
        tester,
        const HuntShareData(name: 'Eevee', dexNumber: '#0133', spriteUrl: null),
      );
      expect(find.text('#0133'), findsOne);
      expect(find.text('de caçada'), findsNothing);
    });

    test('o brilho só se redesenha se a cor ou o ponto mudarem', () {
      const red = SparklePainter(color: Colors.red, dot: true);
      expect(
        red.shouldRepaint(const SparklePainter(color: Colors.red, dot: true)),
        isFalse,
      );
      expect(
        red.shouldRepaint(const SparklePainter(color: Colors.blue, dot: true)),
        isTrue,
      );
      expect(
        red.shouldRepaint(const SparklePainter(color: Colors.red, dot: false)),
        isTrue,
      );
    });

    testWidgets('em inglês', (tester) async {
      await pump(tester, _full, locale: english);
      expect(find.text('SHINY FOUND'), findsOne);
      expect(find.text('hunting'), findsOne);
      expect(find.text('odds at the end'), findsOne);
    });
  });

  group('folha "Compartilhar a caçada"', () {
    late _Sharer sharer;

    setUp(() => sharer = _Sharer());

    Future<void> open(
      WidgetTester tester, {
      PngCapturer? capturer,
      Locale locale = portuguese,
    }) async {
      await pumpWidgetApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showHuntShareSheet(context, _full),
              child: const Text('abrir'),
            ),
          ),
        ),
        locale: locale,
        size: const Size(402, 874),
        overrides: [
          fileSharerProvider.overrideWithValue(sharer.call),
          pngCapturerProvider.overrideWithValue(
            capturer ?? (_, _) async => _png,
          ),
        ],
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    ButtonStyleButton button(WidgetTester tester) => tester
        .widget<ButtonStyleButton>(find.byKey(const ValueKey('share-hunt')));

    testWidgets('a imagem fica pronta ao abrir; compartilhar fecha a folha', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('Compartilhar a caçada'), findsOne);
      expect(find.byType(HuntShareCard), findsOne);
      expect(button(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey('share-hunt')));
      await tester.pumpAndSettle();
      expect(sharer.calls.single, (
        _png,
        'ishinydex-jangmo-o.png',
        'image/png',
      ));
      expect(find.byType(HuntShareSheet), findsNothing);
    });

    testWidgets('baixado, recusado, falha e desistência', (tester) async {
      await open(tester);
      for (final (outcome, message) in [
        (ShareOutcome.downloaded, 'Imagem baixada.'),
        (
          ShareOutcome.notAllowed,
          'O navegador não deixou compartilhar. Tente de novo.',
        ),
        (ShareOutcome.failed, 'Não deu para compartilhar a imagem.'),
      ]) {
        sharer.outcome = outcome;
        await tester.tap(find.byKey(const ValueKey('share-hunt')));
        // O aviso anterior sai e o novo entra.
        await tester.pumpAndSettle();
        expect(find.text(message), findsOne, reason: '$outcome');
        // A folha continua aberta, para tentar de novo.
        expect(find.byType(HuntShareSheet), findsOne);
      }
      sharer.outcome = ShareOutcome.cancelled;
      ScaffoldMessenger.of(tester.element(find.byType(HuntShareSheet)))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('share-hunt')));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(HuntShareSheet), findsOne);
    });

    testWidgets('enquanto prepara, o botão espera', (tester) async {
      await pumpWidgetApp(
        tester,
        const HuntShareSheet(data: _waiting),
        overrides: [
          // A imagem nunca fica pronta.
          pngCapturerProvider.overrideWithValue(
            (_, _) => Completer<Uint8List>().future,
          ),
        ],
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Preparando a imagem…'), findsOne);
      expect(button(tester).onPressed, isNull);
    });

    testWidgets('se a imagem falhar, avisa e não compartilha', (tester) async {
      await open(tester, capturer: (_, _) async => throw StateError('x'));
      expect(find.text('Não deu para compartilhar a imagem.'), findsOne);
      expect(button(tester).onPressed, isNull);
      expect(find.text('Compartilhar'), findsOne);
    });

    testWidgets('com sprite: espera a imagem dele antes de capturar', (
      tester,
    ) async {
      await pumpWidgetApp(
        tester,
        const HuntShareSheet(
          data: HuntShareData(
            name: 'Eevee',
            dexNumber: '#0133',
            spriteUrl: 'http://x/eevee.png',
          ),
        ),
        overrides: [
          pngCapturerProvider.overrideWithValue((_, _) async => _png),
        ],
      );
      await tester.pumpAndSettle();
      expect(button(tester).onPressed, isNotNull);
    });

    testWidgets('em inglês', (tester) async {
      await open(tester, locale: english);
      expect(find.text('Share the hunt'), findsOne);
      expect(find.text('Share'), findsOne);
    });
  });

  testWidgets('capturePng: o PNG de verdade, no tamanho pedido', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          key: key,
          child: const SizedBox(
            width: 10,
            height: 20,
            child: ColoredBox(color: Colors.red),
          ),
        ),
      ),
    );
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final png = (await tester.runAsync(() => capturePng(boundary, 2)))!;
    // A assinatura do PNG e a largura (20 px) no cabeçalho IHDR.
    expect(png.sublist(1, 4), 'PNG'.codeUnits);
    expect(ByteData.sublistView(png).getUint32(16), 20);
    expect(ByteData.sublistView(png).getUint32(20), 40);
  });

  group('botão no registro da caçada', () {
    final shiny = Specimen.fromJson({...specimenJson, 'ot': null});

    Future<void> pump(WidgetTester tester, Specimen? specimen) => pumpWidgetApp(
      tester,
      Scaffold(
        body: HuntRecordCard(
          hunt: const HuntRecord(method: 'random', count: 12, unit: 'eggs'),
          specimen: specimen,
        ),
      ),
      overrides: [
        pngCapturerProvider.overrideWithValue((_, _) async => _png),
        shinyMethodsProvider.overrideWithValue(
          (_, {fromGo = false}) => const [
            ShinyMethod(
              id: 'random',
              label: 'Encontro aleatório',
              units: ['encounters'],
              versions: {},
            ),
          ],
        ),
      ],
    );

    testWidgets('num shiny, abre a folha', (tester) async {
      await pump(tester, shiny);
      await tester.tap(find.byTooltip('Compartilhar'));
      await tester.pumpAndSettle();
      expect(find.byType(HuntShareSheet), findsOne);
      expect(find.text('Bulbasaur'), findsWidgets);
      // O método, no idioma da tela, nos detalhes do card.
      expect(find.textContaining('Encontro aleatório'), findsWidgets);
    });

    testWidgets('sem espécime ou sem shiny, não aparece', (tester) async {
      await pump(tester, null);
      expect(find.byTooltip('Compartilhar'), findsNothing);
      await pump(tester, shiny.copyWith(isShiny: false));
      expect(find.byTooltip('Compartilhar'), findsNothing);
    });
  });

  test('fora do navegador, compartilhar não existe', () {
    expect(
      () => stub.shareFile(_png, name: 'x.png', type: 'image/png'),
      throwsUnsupportedError,
    );
  });
}

const _waiting = HuntShareData(
  name: 'Eevee',
  dexNumber: '#0133',
  spriteUrl: null,
);
