import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/neighbor_box_precache.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

/// Registra os pedidos de pré-carregamento; cada um só termina quando o
/// teste mandar, para conferir os lotes.
class _Recorder {
  final urls = <String>[];
  final _pending = <Completer<void>>[];

  Future<void> call(BuildContext context, String url) {
    urls.add(url);
    final done = Completer<void>();
    _pending.add(done);
    return done.future;
  }

  /// Termina os pedidos em andamento (o lote da vez).
  Future<void> finishBatch(WidgetTester tester) async {
    for (final done in _pending) {
      done.complete();
    }
    _pending.clear();
    await tester.pump();
  }
}

void main() {
  late FakeBackend backend;
  late List<BoxSummary> boxes;

  /// As URLs de cada box do dex 1 (o seed tem duas), na ordem da grade.
  late List<Set<String>> urls;

  Future<void> pumpPrecache(
    WidgetTester tester,
    int index,
    _Recorder recorder,
  ) async {
    await pumpWidgetApp(
      tester,
      NeighborBoxPrecache(
        dexId: 1,
        boxes: boxes,
        index: index,
        precache: recorder.call,
        child: const Text('box'),
      ),
      overrides: [personalDexRepositoryProvider.overrideWithValue(backend)],
    );
    await tester.pumpAndSettle();
  }

  /// Termina lote a lote até não haver mais pedidos.
  Future<void> drain(WidgetTester tester, _Recorder recorder) async {
    var before = -1;
    while (recorder.urls.length != before) {
      before = recorder.urls.length;
      await recorder.finishBatch(tester);
      expect(
        recorder.urls.length - before,
        lessThanOrEqualTo(precacheBatchSize),
      );
    }
  }

  setUp(() async {
    backend = FakeBackend.seeded();
    boxes = await backend.fetchBoxes(1);
    urls = [
      for (final box in boxes)
        boxSpriteUrls(await backend.fetchSlots(dexId: 1, boxId: box.id)),
    ];
  });

  test('boxSpriteUrls: sprites e balls, sem repetir', () async {
    final slots = await backend.fetchSlots(dexId: 1, boxId: boxes[0].id);
    final balls = {for (final s in slots) ?s.specimen?.pokeballSpriteUrl};
    expect(balls, isNotEmpty);
    expect(boxSpriteUrls([...slots, ...slots]), {
      for (final s in slots) ?s.spriteUrl,
      ...balls,
    });
  });

  testWidgets('na primeira box, pré-carrega a próxima em lotes de 4', (
    tester,
  ) async {
    expect(boxes, hasLength(2));
    expect(urls[1].length, greaterThan(precacheBatchSize));
    final recorder = _Recorder();
    await pumpPrecache(tester, 0, recorder);
    expect(find.text('box'), findsOneWidget);
    // Só um lote por vez, na ordem da grade.
    expect(recorder.urls, urls[1].take(precacheBatchSize));
    await drain(tester, recorder);
    expect(recorder.urls, urls[1].toList());
  });

  testWidgets('na última box, pré-carrega a anterior', (tester) async {
    final recorder = _Recorder();
    await pumpPrecache(tester, 1, recorder);
    await drain(tester, recorder);
    expect(recorder.urls, urls[0].toList());
  });

  testWidgets('trocar de box para a fila anterior e começa a das vizinhas', (
    tester,
  ) async {
    final recorder = _Recorder();
    await pumpPrecache(tester, 0, recorder);
    final started = urls[1].take(precacheBatchSize).toList();
    expect(recorder.urls, started);
    // Na box 1, a vizinha é a 0; o resto da 1 (agora aberta) não é pedido.
    await pumpPrecache(tester, 1, recorder);
    await drain(tester, recorder);
    // As balls que já tinham sido pedidas não se repetem.
    expect(recorder.urls, [
      ...started,
      ...urls[0].where((url) => !started.contains(url)),
    ]);
  });

  testWidgets('fora da tela, para de pré-carregar', (tester) async {
    final recorder = _Recorder();
    await pumpPrecache(tester, 0, recorder);
    expect(recorder.urls, hasLength(precacheBatchSize));
    await tester.pumpWidget(const SizedBox());
    await recorder.finishBatch(tester);
    expect(recorder.urls, hasLength(precacheBatchSize));
  });

  testWidgets('precacheSprite ignora o sprite que não carrega', (tester) async {
    await pumpWidgetApp(tester, const Text('box'));
    final context = tester.element(find.text('box'));
    await tester.runAsync(
      () => precacheSprite(context, 'https://example.com/nao-existe.png'),
    );
    expect(tester.takeException(), isNull);
  });
}
