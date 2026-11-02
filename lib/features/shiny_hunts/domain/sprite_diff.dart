import 'dart:typed_data';

/// Os pixels de um sprite: RGBA, linha a linha.
class SpritePixels {
  const SpritePixels({
    required this.width,
    required this.height,
    required this.rgba,
  });

  final int width;
  final int height;
  final Uint8List rgba;
}

/// Uma cor principal do normal e a mesma área no shiny: a parte da imagem
/// que ela ocupa (0 a 1) e as duas cores (`0xRRGGBB`).
typedef ColorShift = ({double share, int from, int to});

/// A diferença entre o sprite normal e o shiny (#381): o mapa, com o que
/// muda de forma visível pintado de rosa sobre o shiny em cinza; a parte da
/// imagem que muda; e as cores principais, normal → shiny.
class SpriteDiff {
  const SpriteDiff({
    required this.map,
    required this.changedShare,
    required this.colors,
  });

  /// Compara [normal] com [shiny], do mesmo tamanho. Pixels quase
  /// transparentes nas duas ficam de fora; as cores principais vêm dos
  /// pixels opacos, agrupadas pela cor do normal (3 bits por canal), até
  /// [maxColors].
  factory SpriteDiff.of(
    SpritePixels normal,
    SpritePixels shiny, {
    int maxColors = 4,
  }) {
    assert(
      normal.width == shiny.width && normal.height == shiny.height,
      'os dois sprites precisam ter o mesmo tamanho',
    );
    final a = normal.rgba;
    final b = shiny.rgba;
    final out = Uint8List(b.length);
    var shown = 0;
    var changed = 0;
    // Por grupo de cor: quantos pixels e a soma dos canais do normal e do
    // shiny.
    final groups = <int, List<int>>{};
    var opaque = 0;
    for (var i = 0; i + 3 < b.length; i += 4) {
      final alpha = a[i + 3] > b[i + 3] ? a[i + 3] : b[i + 3];
      if (alpha < 16) continue;
      shown++;
      final d =
          (a[i] - b[i]).abs() +
          (a[i + 1] - b[i + 1]).abs() +
          (a[i + 2] - b[i + 2]).abs() +
          (a[i + 3] - b[i + 3]).abs();
      if (d > visible) changed++;
      // O shiny em cinza claro; quanto maior a diferença, mais rosa.
      final gray =
          150 + (0.299 * b[i] + 0.587 * b[i + 1] + 0.114 * b[i + 2]) * 0.3;
      final k = ((d - 55) / 60).clamp(0.0, 1.0);
      out[i] = (gray * (1 - k) + (highlight >> 16 & 0xff) * k).round();
      out[i + 1] = (gray * (1 - k) + (highlight >> 8 & 0xff) * k).round();
      out[i + 2] = (gray * (1 - k) + (highlight & 0xff) * k).round();
      out[i + 3] = alpha;
      if (a[i + 3] < 200 || b[i + 3] < 200) continue;
      opaque++;
      final key = (a[i] >> 5) << 6 | (a[i + 1] >> 5) << 3 | a[i + 2] >> 5;
      final group = groups[key] ??= List.filled(7, 0);
      group[0]++;
      for (var c = 0; c < 3; c++) {
        group[1 + c] += a[i + c];
        group[4 + c] += b[i + c];
      }
    }
    int color(List<int> g, int from) =>
        (g[from] ~/ g[0]) << 16 |
        (g[from + 1] ~/ g[0]) << 8 |
        g[from + 2] ~/ g[0];
    final sorted = groups.values.toList()..sort((x, y) => y[0].compareTo(x[0]));
    return SpriteDiff(
      map: SpritePixels(width: shiny.width, height: shiny.height, rgba: out),
      changedShare: shown == 0 ? 0 : changed / shown,
      colors: [
        for (final g in sorted.take(maxColors))
          if (g[0] / opaque >= minShare)
            (share: g[0] / opaque, from: color(g, 1), to: color(g, 4)),
      ],
    );
  }

  final SpritePixels map;

  /// A parte dos pixels visíveis que muda de forma visível (0 a 1).
  final double changedShare;

  /// As cores principais, da que ocupa mais área à que ocupa menos.
  final List<ColorShift> colors;

  /// A diferença (soma dos canais RGBA) a partir da qual um pixel muda de
  /// forma visível. No Zapdos do HOME, só os olhos passam dela.
  static const visible = 60;

  /// Até esta diferença (soma dos canais RGB), duas cores ficam "quase
  /// iguais" (o amarelo do Zapdos: `#F9D44F` → `#F1C943`, 31; o azul do
  /// Phione, que vira verde-água, passa de 70).
  static const almostSame = 40;

  /// As duas cores de [shift] quase não mudam.
  static bool isAlmostSame(ColorShift shift) =>
      distance(shift.from, shift.to) <= almostSame;

  /// A cor do destaque no mapa.
  static const highlight = 0xD6006E;

  /// Cores com menos área que isto ficam de fora.
  static const minShare = 0.05;

  static int distance(int a, int b) =>
      ((a >> 16 & 0xff) - (b >> 16 & 0xff)).abs() +
      ((a >> 8 & 0xff) - (b >> 8 & 0xff)).abs() +
      ((a & 0xff) - (b & 0xff)).abs();
}
