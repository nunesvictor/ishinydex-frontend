import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:material_ui/material_ui.dart';

/// Quantos sprites são decodificados de uma vez. Com o WebAssembly numa
/// thread só (Safari, sem os headers COOP/COEP no Pages), decodificar disputa
/// a thread com o desenho da tela: lotes pequenos não travam a rolagem.
const precacheBatchSize = 4;

/// Baixa e decodifica um sprite para o `imageCache`. Erros (sprite que não
/// existe, sem internet) são ignorados: o [PokemonSprite] mostra o fallback.
typedef SpritePrecache = Future<void> Function(
  BuildContext context,
  String url,
);

Future<void> precacheSprite(BuildContext context, String url) =>
    precacheImage(spriteImage(url), context, onError: (_, _) {});

/// As URLs remotas que a grade de uma box desenha: o sprite de cada slot e a
/// ball do espécime depositado, sem repetir.
Set<String> boxSpriteUrls(List<Slot> slots) => {
  for (final slot in slots) ...[
    ?slot.spriteUrl,
    ?slot.specimen?.pokeballSpriteUrl,
  ],
};

/// Pré-carrega os sprites e as balls das boxes vizinhas (a anterior e a
/// próxima) da box aberta, para elas aparecerem prontas ao trocar de box
/// (#406).
///
/// A box aberta vem primeiro: os slots das vizinhas só são pedidos depois que
/// os dela chegaram, e as imagens só depois do quadro em que ela aparece, em
/// lotes de [precacheBatchSize]. Trocar de box cancela o que faltava e
/// começa pelas novas vizinhas. Não desenha nada além do [child].
class NeighborBoxPrecache extends ConsumerStatefulWidget {
  const NeighborBoxPrecache({
    required this.dexId,
    required this.boxes,
    required this.index,
    required this.child,
    this.precache = precacheSprite,
    super.key,
  });

  final int dexId;
  final List<BoxSummary> boxes;
  final int index;
  final Widget child;

  /// Trocável nos testes, onde não há rede.
  final SpritePrecache precache;

  @override
  ConsumerState<NeighborBoxPrecache> createState() =>
      _NeighborBoxPrecacheState();
}

class _NeighborBoxPrecacheState extends ConsumerState<NeighborBoxPrecache> {
  /// Já pedidas (com sucesso ou não): não pede de novo.
  final _requested = <String>{};

  /// A fila da vez; trocar de box põe outra no lugar e a anterior para.
  List<String> _queue = const [];

  @override
  Widget build(BuildContext context) {
    final current = widget.boxes[widget.index];
    // Assistir (em vez de ler uma vez) mantém os slots das vizinhas
    // carregados: ao deslizar para elas, a grade já aparece sem o "carregando".
    final ready = ref
        .watch(slotsProvider((dexId: widget.dexId, boxId: current.id)))
        .hasValue;
    if (ready) {
      final urls = <String>{};
      for (final i in [widget.index + 1, widget.index - 1]) {
        if (i < 0 || i >= widget.boxes.length) continue;
        final key = (dexId: widget.dexId, boxId: widget.boxes[i].id);
        final slots = ref.watch(slotsProvider(key)).value;
        if (slots != null) urls.addAll(boxSpriteUrls(slots));
      }
      _enqueue(urls.where((url) => !_requested.contains(url)).toList());
    }
    return widget.child;
  }

  void _enqueue(List<String> urls) {
    if (urls.isEmpty) return;
    final queue = _queue = urls;
    // Depois do quadro da box aberta: as imagens dela vêm primeiro.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run(queue)));
  }

  Future<void> _run(List<String> queue) async {
    for (var start = 0; start < queue.length; start += precacheBatchSize) {
      if (!mounted || !identical(queue, _queue)) return;
      final batch = queue
          .skip(start)
          .take(precacheBatchSize)
          .where(_requested.add)
          .toList();
      await Future.wait([
        for (final url in batch) widget.precache(context, url),
      ]);
    }
  }
}
