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
  const BaseStatsChart({required this.stats, this.nature, super.key});

  final List<FormStat> stats;

  /// Natureza do espécime registrado: o stat que ela aumenta fica vermelho
  /// com ↑ e o que diminui, azul com ↓, como nos jogos. Sem espécime (ou
  /// natureza), o hexágono é só o da forma.
  final Choice? nature;

  /// Cores dos jogos para os stats da natureza, mais claras no tema escuro.
  static Color increasedColor(Brightness brightness) =>
      brightness == Brightness.dark
      ? const Color(0xFFEF9A9A)
      : const Color(0xFFC62828);

  static Color decreasedColor(Brightness brightness) =>
      brightness == Brightness.dark
      ? const Color(0xFF90CAF9)
      : const Color(0xFF1565C0);

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
    final upColor = increasedColor(theme.brightness);
    final downColor = decreasedColor(theme.brightness);
    if (stats.isEmpty) {
      // Sem hexágono, a natureza continua à vista (ela só mora aqui).
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          spacing: 8,
          children: [
            Text(
              'Sem status base para esta forma.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (this.nature case final choice?)
              _NatureCaption(
                nature: choice,
                byName: const {},
                upColor: upColor,
                downColor: downColor,
              ),
          ],
        ),
      );
    }
    final byName = {for (final stat in stats) stat.stat: stat};
    final vertices = [
      for (final name in order)
        byName[name] ?? FormStat(stat: name, baseStat: 0),
    ];
    final total = stats.fold(0, (sum, stat) => sum + stat.baseStat);
    final nature = this.nature;
    final up = nature?.increased;
    final down = nature?.decreased;
    String effect(String stat) => stat == up
        ? ', aumentado pela natureza'
        : stat == down
        ? ', diminuído pela natureza'
        : '';
    final ev = [
      for (final stat in stats)
        if (stat.effort > 0) '${stat.effort} EV de ${stat.label}',
    ];
    return Column(
      spacing: 4,
      children: [
        Semantics(
          label: [
            for (final stat in vertices)
              '${stat.label} ${stat.baseStat}${effect(stat.stat)}',
          ].join('; '),
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
              increased: up,
              decreased: down,
              increasedColor: upColor,
              decreasedColor: downColor,
            ),
          ),
        ),
        if (nature != null)
          _NatureCaption(
            nature: nature,
            byName: byName,
            upColor: upColor,
            downColor: downColor,
          ),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Total '),
              TextSpan(
                text: '$total',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (ev.isNotEmpty)
                TextSpan(text: ' · derrotado, dá ${ev.join(' e ')}'),
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
    required this.increased,
    required this.decreased,
    required this.increasedColor,
    required this.decreasedColor,
  });

  final List<FormStat> stats;
  final Color grid;
  final Color fill;
  final TextStyle label;
  final TextStyle value;
  final String? increased;
  final String? decreased;
  final Color increasedColor;
  final Color decreasedColor;

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
      final stat = stats[i];
      final (arrow, color) = stat.stat == increased
          ? (' ↑', increasedColor)
          : stat.stat == decreased
          ? (' ↓', decreasedColor)
          : ('', null);
      // O stat afetado ganha a cor e o peso do valor, para saltar à vista.
      final bold = color == null
          ? null
          : TextStyle(color: color, fontWeight: FontWeight.bold);
      final text = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(text: '${stat.label}$arrow\n', style: label.merge(bold)),
            TextSpan(text: '${stat.baseStat}', style: value.merge(bold)),
          ],
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      final anchor = vertex(i, radius + 18);
      text.paint(canvas, anchor - Offset(text.width / 2, text.height / 2));
    }
  }

  // A lista de vértices é nova a cada build e o desenho é barato: sempre
  // repinta, em vez de comparar campo a campo.
  @override
  bool shouldRepaint(_HexagonPainter old) => true;
}

/// "Natureza Modest  ↑ Atq. Esp.  ↓ Ataque"; nas neutras, "(neutra)".
class _NatureCaption extends StatelessWidget {
  const _NatureCaption({
    required this.nature,
    required this.byName,
    required this.upColor,
    required this.downColor,
  });

  final Choice nature;
  final Map<String, FormStat> byName;
  final Color upColor;
  final Color downColor;

  String _label(String stat) =>
      (byName[stat] ?? FormStat(stat: stat, baseStat: 0)).label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final up = nature.increased;
    final down = nature.decreased;
    TextStyle colored(Color color) =>
        TextStyle(color: color, fontWeight: FontWeight.w500);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Natureza ',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          TextSpan(
            text: nature.label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (up != null)
            TextSpan(text: '   ↑ ${_label(up)}', style: colored(upColor)),
          if (down != null)
            TextSpan(text: '   ↓ ${_label(down)}', style: colored(downColor)),
          if (up == null && down == null) const TextSpan(text: ' (neutra)'),
        ],
      ),
      style: theme.textTheme.bodyMedium,
      textAlign: TextAlign.center,
    );
  }
}
