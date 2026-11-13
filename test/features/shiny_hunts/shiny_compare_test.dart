import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/data/sprite_source.dart';
import 'package:ishinydex/features/shiny_hunts/domain/sprite_diff.dart';
import 'package:ishinydex/features/shiny_hunts/presentation/shiny_compare.dart';
import 'package:ishinydex/features/shiny_hunts/shiny_hunt_providers.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

/// Um sprite de [colors] pixels numa linha (`0xRRGGBBAA`).
SpritePixels _pixels(List<int> colors) => SpritePixels(
  width: colors.length,
  height: 1,
  rgba: Uint8List.fromList([
    for (final c in colors) ...[
      c >> 24 & 0xff,
      c >> 16 & 0xff,
      c >> 8 & 0xff,
      c & 0xff,
    ],
  ]),
);

// O Zapdos de mentira: 17 pixels amarelos que quase não mudam, 2 olhos que
// mudam muito, um pixel transparente nos dois e um de contorno quase
// transparente.
final SpritePixels _normal = _pixels([
  ...List.filled(17, 0xF9D44FFF),
  0x101010FF,
  0x101010FF,
  0x00000000,
  0xF9D44F40,
]);
final SpritePixels _shiny = _pixels([
  ...List.filled(17, 0xF1C943FF),
  0xE00000FF,
  0xE00000FF,
  0x00000000,
  0xF1C94340,
]);

const _form = FormRef(
  id: 145,
  name: 'zapdos',
  pokeapiId: 145,
  spriteUrl: 'https://sprites/145.png',
  shinySpriteUrl: 'https://sprites/shiny/145.png',
);

Future<void> _pump(
  WidgetTester tester, {
  Size size = compactSize,
  Future<SpritePixels> Function(String url)? load,
  Locale locale = portuguese,
}) => pumpWidgetApp(
  tester,
  const Scaffold(
    body: Center(child: ShinyCompareButton(form: _form)),
  ),
  size: size,
  locale: locale,
  overrides: [
    spritePixelsProvider.overrideWithValue(
      load ?? (url) async => url.contains('shiny') ? _shiny : _normal,
    ),
  ],
);

void main() {
  group('SpriteDiff', () {
    test('o que muda, as cores principais e o mapa', () {
      final diff = SpriteDiff.of(_normal, _shiny);
      // 20 pixels visíveis (o transparente nos dois fica de fora); 2 mudam.
      expect(diff.changedShare, closeTo(2 / 20, 1e-9));
      // Só os opacos contam nas cores: 17 amarelos e 2 olhos.
      expect(
        [for (final c in diff.colors) (c.from, c.to)],
        [(0xF9D44F, 0xF1C943), (0x101010, 0xE00000)],
      );
      expect(diff.colors.first.share, closeTo(17 / 19, 1e-9));
      expect(SpriteDiff.isAlmostSame(diff.colors.first), isTrue);
      expect(SpriteDiff.isAlmostSame(diff.colors.last), isFalse);
      // No mapa, o olho fica no rosa do destaque; o amarelo, em cinza; o
      // transparente, transparente.
      final map = diff.map.rgba;
      expect(map.sublist(17 * 4, 18 * 4), [0xD6, 0x00, 0x6E, 0xFF]);
      expect(map[0], map[1]);
      expect(map.sublist(19 * 4, 20 * 4), [0, 0, 0, 0]);
    });

    test('cores com pouca área e sprite vazio', () {
      final diff = SpriteDiff.of(
        _pixels([...List.filled(30, 0x0000FFFF), 0xFF0000FF]),
        _pixels([...List.filled(30, 0x00FF00FF), 0xFF0000FF]),
        maxColors: 1,
      );
      expect(diff.colors, hasLength(1));
      final tiny = SpriteDiff.of(
        _pixels([...List.filled(30, 0x0000FFFF), 0xFF0000FF]),
        _pixels([...List.filled(30, 0x0000FFFF), 0xFF0000FF]),
      );
      // O vermelho tem 1/31 da área, menos que 5%: fica de fora.
      expect(tiny.colors, hasLength(1));
      expect(tiny.changedShare, 0);
      final empty = SpriteDiff.of(_pixels([0]), _pixels([0]));
      expect(empty.changedShare, 0);
      expect(empty.colors, isEmpty);
    });
  });

  testWidgets('baixa e lê os pixels de um sprite', (tester) async {
    await tester.runAsync(() async {
      // Um PNG de 2×1, feito na hora.
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder)
        ..drawRect(
          const ui.Rect.fromLTWH(0, 0, 1, 1),
          ui.Paint()..color = const ui.Color(0xFFFF0000),
        )
        ..drawRect(
          const ui.Rect.fromLTWH(1, 0, 1, 1),
          ui.Paint()..color = const ui.Color(0xFF0000FF),
        );
      final image = await recorder.endRecording().toImage(2, 1);
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final dio = Dio();
      DioAdapter(dio: dio).onGet(
        _form.spriteUrl,
        (server) => server.reply(200, png.buffer.asUint8List()),
      );
      // Pelo provider, com o Dio dos sprites trocado.
      final container = createContainer(
        overrides: [spriteDioProvider.overrideWithValue(dio)],
      );
      final load = container.read(spritePixelsProvider);
      // O provider reduz (ou amplia) para 256 de largura.
      expect((await load(_form.spriteUrl)).width, 256);
      final pixels = await SpriteSource(dio, size: 2).pixels(_form.spriteUrl);
      expect((pixels.width, pixels.height), (2, 1));
      expect(pixels.rgba.sublist(0, 4), [255, 0, 0, 255]);
      expect(pixels.rgba.sublist(4, 8), [0, 0, 255, 255]);
    });
  });

  testWidgets('segurar troca o shiny pelo normal (celular)', (tester) async {
    await _pump(tester);
    expect(
      find.byTooltip('Comparar o shiny com o normal: Zapdos'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('compare-145')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Normal e shiny lado a lado'), findsOneWidget);
    expect(find.text('Segure para ver o normal'), findsOneWidget);

    final hold = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('compare-hold'))),
    );
    await tester.pump();
    expect(find.text('Solte para ver o shiny'), findsOneWidget);
    await hold.up();
    await tester.pump();
    expect(find.text('Segure para ver o normal'), findsOneWidget);
    // Um gesto cancelado também volta.
    final cancel = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('compare-hold'))),
    );
    await tester.pump();
    await cancel.cancel();
    await tester.pump();
    expect(find.text('Segure para ver o normal'), findsOneWidget);
  });

  testWidgets('a diferença: o mapa, o resumo e as cores', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('compare-145')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('compare-diff-mode')));
      await tester.pump();
      // O mapa vira imagem fora do relógio falso dos testes.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    // A diferença chega; o mapa vira imagem fora do relógio falso.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    expect(
      find.text('10% da imagem muda de forma visível: as partes em rosa.'),
      findsOneWidget,
    );
    expect(find.text('quase igual'), findsOneWidget);
    expect(find.byTooltip('#F9D44F'), findsOneWidget);
    expect(find.byType(PixelsImage), findsOneWidget);
    // Voltar ao segurar.
    await tester.tap(find.byKey(const ValueKey('compare-hold-mode')));
    await tester.pumpAndSettle();
    expect(find.byType(PixelsImage), findsNothing);
  });

  testWidgets('pouca diferença, em inglês e no PC', (tester) async {
    await _pump(
      tester,
      size: expandedSize,
      locale: english,
      // Um pixel muda em 20: só 5%.
      load: (url) async => url.contains('shiny')
          ? _pixels([...List.filled(19, 0x3CCEFAFF), 0x77DDD5FF])
          : _pixels(List.filled(20, 0x3CCEFAFF)),
    );
    await tester.tap(find.byKey(const ValueKey('compare-145')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('compare-diff-mode')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Only 5% of the image changes clearly: the pink areas. '
        'The rest shifts by a barely visible shade.',
      ),
      findsOneWidget,
    );
    // A cor que ocupa quase tudo não muda.
    expect(find.text('almost the same'), findsOneWidget);
  });

  testWidgets('sem internet: o aviso e tentar de novo', (tester) async {
    var calls = 0;
    await _pump(
      tester,
      load: (url) async {
        calls++;
        throw DioException(requestOptions: RequestOptions(path: url));
      },
    );
    await tester.tap(find.byKey(const ValueKey('compare-145')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('compare-diff-mode')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Não deu para baixar as imagens. Confira a internet e tente de novo.',
      ),
      findsOneWidget,
    );
    final before = calls;
    await tester.tap(find.text(ptText.tryAgain));
    await tester.pumpAndSettle();
    expect(calls, greaterThan(before));
  });

  testWidgets('sem forma, só o sprite', (tester) async {
    await pumpWidgetApp(tester, const ShinyCompareButton(form: null));
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('o mapa que sai da tela antes de pronto', (tester) async {
    final diff = SpriteDiff.of(_normal, _shiny);
    await tester.runAsync(() async {
      await pumpWidgetApp(tester, PixelsImage(diff.map));
      await pumpWidgetApp(tester, const SizedBox());
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    expect(find.byType(PixelsImage), findsNothing);
  });
}
