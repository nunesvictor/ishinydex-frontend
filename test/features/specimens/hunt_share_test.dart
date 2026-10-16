import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/misc.dart';
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

    testWidgets('com dados faltando, a fileira se ajusta (#295)', (
      tester,
    ) async {
      double centerX(Finder f) => tester.getCenter(f).dx;
      final card = find.byType(HuntShareCard);

      // Um número (o Buzzwole): centralizado, com a unidade e o método.
      await pump(
        tester,
        const HuntShareData(
          name: 'Buzzwole',
          dexNumber: '#0794',
          spriteUrl: null,
          count: 22,
          unit: 'runs',
          method: 'Dynamax Adventures',
        ),
      );
      expect(find.text('runs · Dynamax Adventures'), findsOne);
      expect(centerX(find.text('22')), moreOrLessEquals(centerX(card)));

      // Nenhum número: o método no lugar da fileira.
      await pump(
        tester,
        const HuntShareData(
          name: 'Buzzwole',
          dexNumber: '#0794',
          spriteUrl: null,
          method: 'Dynamax Adventures',
        ),
      );
      expect(
        tester.widget<Text>(find.text('Dynamax Adventures')).style?.fontSize,
        16,
      );

      // Dois números: espaços iguais também nas bordas.
      await pump(
        tester,
        HuntShareData(
          name: 'Jangmo-o',
          dexNumber: '#0782',
          spriteUrl: null,
          count: 312,
          unit: 'encounters',
          startedAt: DateTime(2026, 10, 12),
          capturedAt: DateTime(2026, 10, 17),
        ),
      );
      Rect cell(String text) => tester.getRect(
        find.ancestor(of: find.text(text), matching: find.byType(FittedBox)),
      );
      final row = tester.getRect(
        find.ancestor(of: find.text('312'), matching: find.byType(Row)).first,
      );
      final (left, right) = (cell('312'), cell('5 dias'));
      final gaps = [
        left.left - row.left,
        right.left - left.right,
        row.right - right.right,
      ];
      expect(gaps[0], moreOrLessEquals(gaps[1], epsilon: 1));
      expect(gaps[2], moreOrLessEquals(gaps[1], epsilon: 1));
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

  group('HuntShareData.of e o rodapé do OT', () {
    test('só com espécime shiny, com forma e registro', () {
      expect(HuntShareData.of(_specimen), isNotNull);
      expect(HuntShareData.of(_specimen.copyWith(isShiny: false)), isNull);
      expect(HuntShareData.of(_specimen.copyWith(hunt: null)), isNull);
      expect(HuntShareData.of(_specimen.copyWith(formRef: null)), isNull);
      final data = HuntShareData.of(_specimen, method: 'SOS', ot: _ot)!;
      expect(data.version, 'ultra-moon');
      expect(data.trainerId, '123456');
      // Igualdade por valor (a folha refaz a imagem quando os dados mudam).
      expect(data, HuntShareData.of(_specimen, method: 'SOS', ot: _ot));
      expect(
        data.hashCode,
        HuntShareData.of(_specimen, method: 'SOS', ot: _ot).hashCode,
      );
      expect(data == HuntShareData.of(_specimen), isFalse);
    });

    testWidgets('OT com nome; o ID só com a chave', (tester) async {
      final data = HuntShareData.of(_specimen, ot: _ot)!;
      Future<void> pump({required bool showId}) => pumpWidgetApp(
        tester,
        Center(
          child: HuntShareCard(data: data, showTrainerId: showId),
        ),
        size: const Size(500, 700),
      );
      await pump(showId: false);
      expect(find.text('OT Victor'), findsOne);
      await pump(showId: true);
      expect(find.text('OT Victor (123456)'), findsOne);
    });
  });

  group('folha do card', () {
    late _Sharer sharer;
    late int captures;

    setUp(() {
      sharer = _Sharer();
      captures = 0;
    });

    List<Override> overrides({PngCapturer? capturer}) => [
      fileSharerProvider.overrideWithValue(sharer.call),
      pngCapturerProvider.overrideWithValue(
        capturer ??
            (_, _) async {
              captures++;
              return _png;
            },
      ),
      trainersProvider.overrideWith((ref) async => const [_ot]),
      shinyMethodsProvider.overrideWithValue(
        (_, {fromGo = false}) => const [_random],
      ),
    ];

    Future<void> open(
      WidgetTester tester, {
      bool found = false,
      PngCapturer? capturer,
      Locale locale = portuguese,
      Specimen? specimen,
    }) async {
      await pumpWidgetApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showHuntShareSheet(
                context,
                specimen ?? _specimen,
                found: found,
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
        locale: locale,
        size: const Size(402, 874),
        overrides: overrides(capturer: capturer),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    ButtonStyleButton button(WidgetTester tester) => tester
        .widget<ButtonStyleButton>(find.byKey(const ValueKey('share-hunt')));

    testWidgets('do espécime: a imagem pronta ao abrir; compartilhar fecha', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('Compartilhar a caçada'), findsOne);
      expect(find.text('Agora não'), findsNothing);
      // O método e o OT vieram dos providers.
      expect(
        find.text(
          'Encontro aleatório · maior cadeia 38 · achado em 0,6× as odds',
        ),
        findsOne,
      );
      expect(find.text('OT Victor'), findsOne);
      expect(button(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey('share-hunt')));
      await tester.pumpAndSettle();
      expect(sharer.calls.single, (
        _png,
        'ishinydex-bulbasaur.png',
        'image/png',
      ));
      expect(find.byType(HuntShareSheet), findsNothing);
    });

    testWidgets('depois do Encontrei!: "Shiny registrado!" e "Agora não"', (
      tester,
    ) async {
      await open(tester, found: true);
      expect(find.text('Shiny registrado!'), findsOne);
      expect(
        find.text(
          'Bulbasaur foi para os seus espécimes e a caçada terminou. Quer '
          'compartilhar o resultado?',
        ),
        findsOne,
      );
      await tester.tap(find.text('Agora não'));
      await tester.pumpAndSettle();
      expect(find.byType(HuntShareSheet), findsNothing);
      expect(sharer.calls, isEmpty);
    });

    testWidgets('a chave do ID refaz a imagem', (tester) async {
      await open(tester);
      expect(captures, 1);
      await tester.tap(find.text('Mostrar o ID do treinador'));
      await tester.pumpAndSettle();
      expect(find.text('OT Victor (123456)'), findsOne);
      expect(captures, 2);
      expect(button(tester).onPressed, isNotNull);
    });

    testWidgets('sem ID do OT, sem a chave; sem o que mostrar, nada', (
      tester,
    ) async {
      await open(tester, specimen: _specimen.copyWith(ot: null));
      expect(find.text('Mostrar o ID do treinador'), findsNothing);
      await open(tester, specimen: _specimen.copyWith(isShiny: false));
      expect(find.byType(HuntShareCard), findsNothing);
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

    testWidgets('enquanto prepara, o botão espera; uma troca no meio vale', (
      tester,
    ) async {
      final pending = <Completer<Uint8List>>[];
      // O indicador de carregamento gira sempre: sem pumpAndSettle.
      Future<void> settle() async {
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await pumpWidgetApp(
        tester,
        Scaffold(body: HuntShareSheet(specimen: _specimen)),
        overrides: overrides(
          capturer: (_, _) {
            pending.add(Completer<Uint8List>());
            return pending.last.future;
          },
        ),
      );
      await settle();
      expect(find.text('Preparando a imagem…'), findsOne);
      expect(button(tester).onPressed, isNull);
      // Liga o ID antes da 1ª imagem chegar: ela não vale mais.
      await tester.tap(find.text('Mostrar o ID do treinador'));
      await settle();
      pending.first.complete(_png);
      await settle();
      expect(button(tester).onPressed, isNull);
      pending.last.complete(_png);
      await settle();
      expect(button(tester).onPressed, isNotNull);
    });

    testWidgets('se a imagem falhar, avisa; a próxima tentativa limpa', (
      tester,
    ) async {
      var fail = true;
      await open(
        tester,
        capturer: (_, _) async => fail ? throw StateError('x') : _png,
      );
      expect(find.text('Não deu para compartilhar a imagem.'), findsOne);
      expect(button(tester).onPressed, isNull);
      fail = false;
      await tester.tap(find.text('Mostrar o ID do treinador'));
      await tester.pumpAndSettle();
      expect(find.text('Não deu para compartilhar a imagem.'), findsNothing);
      expect(button(tester).onPressed, isNotNull);
    });

    testWidgets('em inglês', (tester) async {
      await open(tester, locale: english, found: true);
      expect(find.text('Shiny registered!'), findsOne);
      expect(find.text('Not now'), findsOne);
      expect(find.text('Show the trainer ID'), findsOne);
      expect(find.text('Share'), findsOne);
    });

    testWidgets('botão no registro da caçada: só num shiny, abre a folha', (
      tester,
    ) async {
      Future<void> pump(Specimen? specimen) => pumpWidgetApp(
        tester,
        Scaffold(
          body: HuntRecordCard(hunt: _hunt, specimen: specimen),
        ),
        overrides: overrides(),
      );
      await pump(null);
      expect(find.byTooltip('Compartilhar'), findsNothing);
      await pump(_specimen.copyWith(isShiny: false));
      expect(find.byTooltip('Compartilhar'), findsNothing);
      await pump(_specimen);
      await tester.tap(find.byTooltip('Compartilhar'));
      await tester.pumpAndSettle();
      expect(find.byType(HuntShareSheet), findsOne);
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

  test('fora do navegador, compartilhar não existe', () {
    expect(
      () => stub.shareFile(_png, name: 'x.png', type: 'image/png'),
      throwsUnsupportedError,
    );
  });
}

const _ot = Trainer(
  id: 7,
  name: 'Victor',
  trainerId: '123456',
  version: 'ultra-moon',
);

const _random = ShinyMethod(
  id: 'random',
  label: 'Encontro aleatório',
  units: ['encounters'],
  versions: {},
);

final _hunt = HuntRecord(
  method: 'random',
  count: 312,
  unit: 'encounters',
  startedAt: DateTime(2026, 10, 12),
  odds: 273,
  multiple: 0.6,
  bestChain: 38,
);

final Specimen _specimen = Specimen.fromJson({...specimenJson, 'ot': 7})
    .copyWith(hunt: _hunt, capturedAt: DateTime(2026, 10, 17));
