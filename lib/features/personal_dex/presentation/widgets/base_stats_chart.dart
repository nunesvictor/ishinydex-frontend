import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';

/// Status base num hexágono, como nos jogos: HP no topo e, no sentido
/// horário, Ataque, Defesa, Velocidade, Def. Esp. e Atq. Esp. Embaixo, o
/// total e o EV que o Pokémon dá ao ser derrotado.
///
/// O desenho é um `CustomPainter`: o Flutter entrega um `Canvas` e a gente
/// traça os polígonos com coordenadas calculadas (seno e cosseno de cada
/// vértice), sem biblioteca de gráficos.
class BaseStatsChart extends StatelessWidget {
  const BaseStatsChart({required this.stats, super.key});

  final List<FormStat> stats;

  /// Escala fixa: dá para comparar o hexágono de Pokémon diferentes. Quase
  /// nenhum status base passa disso (os que passam encostam na borda).
  static const maxValue = 200;

  /// Ordem dos vértices, a partir do topo, no sentido horário.
  static const order = [
    'hp',
    'attack',
    'defense',
    'speed',
    'special-defense',
    'special-attack',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (stats.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Sem status base para esta forma.',
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      );
    }
    final byName = {for (final stat in stats) stat.stat: stat};
    final vertices = [
      for (final name in order)
        byName[name] ?? FormStat(stat: name, baseStat: 0),
    ];
    final total = stats.fold(0, (sum, stat) => sum + stat.baseStat);
    final ev = [
      for (final stat in stats)
        if (stat.effort > 0) '${stat.effort} EV de ${stat.label}',
    ];
    return Column(
      spacing: 4,
      children: [
        Semantics(
          label: [for (final stat in vertices) '${stat.label} ${stat.baseStat}']
              .join(', '),
          child: CustomPaint(
            size: const Size(300, 252),
            painter: _HexagonPainter(
              stats: vertices,
              grid: theme.colorScheme.outlineVariant,
              fill: theme.colorScheme.primary,
              label: theme.textTheme.labelSmall!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              value: theme.textTheme.labelLarge!,
            ),
          ),
        ),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Total '),
              TextSpan(
                text: '$total',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (ev.isNotEmpty) TextSpan(text: ' · dá ${ev.join(' e ')}'),
            ],
          ),
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _HexagonPainter extends CustomPainter {
  _HexagonPainter({
    required this.stats,
    required this.grid,
    required this.fill,
    required this.label,
    required this.value,
  });

  final List<FormStat> stats;
  final Color grid;
  final Color fill;
  final TextStyle label;
  final TextStyle value;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Sobra espaço em volta para os rótulos.
    final radius = size.height / 2 - 32;
    Offset vertex(int i, double r) {
      final angle = (-90 + 60 * i) * math.pi / 180;
      return center + Offset(r * math.cos(angle), r * math.sin(angle));
    }

    Path polygon(double Function(int i) r) {
      final path = Path()..moveTo(vertex(0, r(0)).dx, vertex(0, r(0)).dy);
      for (var i = 1; i < 6; i++) {
        final p = vertex(i, r(i));
        path.lineTo(p.dx, p.dy);
      }
      return path..close();
    }

    final gridPaint = Paint()
      ..color = grid
      ..style = PaintingStyle.stroke;
    for (final fraction in [1 / 3, 2 / 3, 1.0]) {
      canvas.drawPath(polygon((_) => radius * fraction), gridPaint);
    }
    for (var i = 0; i < 6; i++) {
      canvas.drawLine(center, vertex(i, radius), gridPaint);
    }

    final values = polygon(
      (i) =>
          radius *
          math.min(stats[i].baseStat, BaseStatsChart.maxValue) /
          BaseStatsChart.maxValue,
    );
    canvas
      ..drawPath(values, Paint()..color = fill.withValues(alpha: 0.3))
      ..drawPath(
        values,
        Paint()
          ..color = fill
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

    for (var i = 0; i < 6; i++) {
      final text = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(text: '${stats[i].label}\n', style: label),
            TextSpan(text: '${stats[i].baseStat}', style: value),
          ],
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      final anchor = vertex(i, radius + 18);
      text.paint(canvas, anchor - Offset(text.width / 2, text.height / 2));
    }
  }

  @override
  bool shouldRepaint(_HexagonPainter old) =>
      old.stats != stats || old.fill != fill || old.grid != grid;
}
