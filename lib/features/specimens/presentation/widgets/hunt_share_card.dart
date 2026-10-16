import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/game_icon.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_labels.dart';

/// As cores do card: fundo escuro sempre, mesmo com o app no tema claro (o
/// sprite shiny e o dourado se destacam, e a imagem sai igual para todo
/// mundo). Fixas de propósito: o card não segue o tema.
abstract final class _CardColors {
  static const background = Color(0xFF161515);
  static const foreground = Color(0xFFF4F0F0);
  static const muted = Color(0xFFA9A3A3);
  static const gold = Color(0xFFE8B923);
  static const line = Color(0xFF2E2B2B);
  static const disc = Color(0xFF201E1E);
  static const logo = Color(0xFF26232A);
  static const logoRed = Color(0xFFE53935);
  static const logoDot = Color(0xFFFFCB05);
}

/// O que o card mostra de uma caçada terminada (#243).
@immutable
class HuntShareData {
  const HuntShareData({
    required this.name,
    required this.dexNumber,
    required this.spriteUrl,
    this.version,
    this.capturedAt,
    this.startedAt,
    this.method,
    this.count,
    this.unit,
    this.odds,
    this.multiple,
    this.bestChain,
    this.trainerName,
    this.trainerId,
  });

  /// Os dados de um espécime shiny com registro da caçada; `null` se faltar
  /// algum (não é shiny, não tem forma ou registro). [method] é o nome do
  /// método já no idioma da tela, e [ot], o treinador original.
  static HuntShareData? of(Specimen specimen, {String? method, Trainer? ot}) {
    final form = specimen.formRef;
    final hunt = specimen.hunt;
    if (!specimen.isShiny || form == null || hunt == null) return null;
    return HuntShareData(
      name: form.displayName,
      dexNumber: form.dexNumber,
      spriteUrl: form.spriteFor(shiny: true),
      version: ot?.version,
      capturedAt: specimen.capturedAt,
      startedAt: hunt.startedAt,
      method: method,
      count: hunt.count,
      unit: hunt.unit,
      odds: hunt.odds,
      multiple: hunt.multiple,
      bestChain: hunt.bestChain,
      trainerName: ot?.name,
      trainerId: ot?.trainerId,
    );
  }

  final String name;

  /// "#0782".
  final String dexNumber;

  /// O sprite shiny da forma.
  final String? spriteUrl;

  /// O jogo da caçada (o do OT).
  final String? version;
  final DateTime? capturedAt;
  final DateTime? startedAt;

  /// O nome do método, já no idioma da tela.
  final String? method;
  final int? count;
  final String? unit;
  final double? odds;
  final double? multiple;
  final int? bestChain;

  /// O OT: o nome aparece sempre; o ID, só se a pessoa ligar a chave.
  final String? trainerName;
  final String? trainerId;

  List<Object?> get _fields => [
    name,
    dexNumber,
    spriteUrl,
    version,
    capturedAt,
    startedAt,
    method,
    count,
    unit,
    odds,
    multiple,
    bestChain,
    trainerName,
    trainerId,
  ];

  // Igualdade por valor: a folha gera a imagem de novo quando os dados
  // mudam (o OT, por exemplo, chega depois de abrir).
  @override
  bool operator ==(Object other) =>
      other is HuntShareData && listEquals(other._fields, _fields);

  @override
  int get hashCode => Object.hashAll(_fields);
}

/// O card da caçada para compartilhar (#243, v3 aprovada em 2026-10-14):
/// 4:5, fundo escuro, o sprite shiny no centro, os números com espaços
/// iguais e o nome e a logo do app no rodapé. Desenhado em 432×540; a
/// imagem sai em 1080×1350 ([pixelRatio]).
class HuntShareCard extends StatelessWidget {
  const HuntShareCard({
    required this.data,
    this.showTrainerId = false,
    super.key,
  });

  final HuntShareData data;

  /// O ID do treinador no rodapé (desligado por padrão: o card é para
  /// postar).
  final bool showTrainerId;

  static const size = Size(432, 540);
  static const pixelRatio = 2.5;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = MaterialLocalizations.of(context).formatCompactDate;
    final number = NumberFormat.decimalPattern(l10n.localeName);
    final decimal = NumberFormat('0.0', l10n.localeName);
    final (start, end) = (data.startedAt, data.capturedAt);
    final stats = [
      if (data.count case final count?)
        if (data.unit == 'hours')
          (l10n.huntCount(count, data.unit), l10n.unitHours)
        else
          (
            number.format(count),
            switch (data.unit) {
              final unit? => l10n.huntUnit(unit),
              null => '',
            },
          ),
      if ((start, end) case (final s?, final e?))
        (l10n.huntDuration(s, e), l10n.shareCardHunting),
      if (data.odds case final x?)
        (
          '1/${x < 10 ? decimal.format(x) : number.format(x.round())}',
          l10n.shareCardOdds,
        ),
    ];
    final detail = [
      ?data.method,
      if (data.bestChain case final best?) l10n.longestChain(best),
      if (data.multiple case final m?) l10n.foundAtOdds(decimal.format(m)),
    ].join(' · ');
    final subtitle = [
      data.dexNumber,
      if (data.version case final v?) versionLabel(v),
      if (end != null) format(end),
    ].join(' · ');
    const muted = TextStyle(color: _CardColors.muted, fontSize: 13);
    return SizedBox.fromSize(
      size: size,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: _CardColors.background),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: _CardColors.foreground,
            fontFamily: 'Roboto',
            fontSize: 14,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 24, 26, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 14,
              children: [
                Row(
                  spacing: 8,
                  children: [
                    const _Sparkle(size: 14, color: _CardColors.gold),
                    Expanded(
                      child: Text(
                        l10n.shareCardBanner,
                        style: const TextStyle(
                          color: _CardColors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.2,
                        ),
                      ),
                    ),
                    if (data.version case final v?) GameIcon(v, size: 28),
                  ],
                ),
                // O disco ocupa o que sobra (e encolhe se um nome ou uma
                // fonte maior pedirem espaço): o card cabe sempre em 4:5.
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      width: 236,
                      height: 236,
                      decoration: BoxDecoration(
                        color: _CardColors.disc,
                        shape: BoxShape.circle,
                        border: Border.all(color: _CardColors.line),
                      ),
                      alignment: Alignment.center,
                      child: PokemonSprite(
                        url: data.spriteUrl,
                        size: 210,
                        semanticLabel: data.name,
                      ),
                    ),
                  ),
                ),
                Column(
                  spacing: 3,
                  children: [
                    Text(
                      data.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(subtitle, textAlign: TextAlign.center, style: muted),
                  ],
                ),
                const Divider(height: 1, color: _CardColors.line),
                // A fileira se ajusta a quantos números há (#295): com um,
                // centralizado e maior, com a unidade e o método embaixo;
                // com dois ou três, espaços iguais também nas bordas; sem
                // nenhum, o método no lugar dela.
                ...switch (stats) {
                  [] when detail.isNotEmpty => [
                    Text(
                      detail,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                  [] => const <Widget>[],
                  [(final value, final label)] => [
                    Column(
                      spacing: 2,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(value, style: _value(30)),
                        ),
                        Text(
                          [
                            if (label.isNotEmpty) label,
                            if (detail.isNotEmpty) detail,
                          ].join(' · '),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _CardColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                  _ => [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final (value, label) in stats)
                          // Um número comprido encolhe, em vez de vazar.
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                children: [
                                  Text(value, style: _value(24)),
                                  Text(
                                    label,
                                    style: const TextStyle(
                                      color: _CardColors.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (detail.isNotEmpty)
                      Text(detail, textAlign: TextAlign.center, style: muted),
                  ],
                },
                Row(
                  spacing: 7,
                  children: [
                    Expanded(
                      child: Text(
                        switch ((data.trainerName, data.trainerId)) {
                          (final name?, final id?) when showTrainerId =>
                            l10n.shareCardTrainer('$name ($id)'),
                          (final name?, _) => l10n.shareCardTrainer(name),
                          _ => '',
                        },
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _CardColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const _Logo(),
                    const Text('iShinyDex', style: _logoText),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Um número da fileira, em [size] px.
  static TextStyle _value(double size) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w700,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

const _logoText = TextStyle(fontSize: 14, fontWeight: FontWeight.w700);

/// O ícone do app em miniatura: o brilho vermelho e o ponto amarelo.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      color: _CardColors.logo,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: _CardColors.line),
    ),
    alignment: Alignment.center,
    child: const _Sparkle(size: 14, color: _CardColors.logoRed, dot: true),
  );
}

/// O brilho de 4 pontas (o mesmo do ícone do app).
class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.size, required this.color, this.dot = false});

  final double size;
  final Color color;
  final bool dot;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: SparklePainter(color: color, dot: dot),
  );
}

/// O desenho do brilho (público só para os testes).
@visibleForTesting
class SparklePainter extends CustomPainter {
  const SparklePainter({required this.color, required this.dot});

  final Color color;
  final bool dot;

  @override
  void paint(Canvas canvas, Size size) {
    // O desenho do viewBox 24×24 do mock.
    final u = size.width / 24;
    final path = Path()
      ..moveTo(12 * u, 2 * u)
      ..lineTo(14.2 * u, 9.8 * u)
      ..lineTo(22 * u, 12 * u)
      ..lineTo(14.2 * u, 14.2 * u)
      ..lineTo(12 * u, 22 * u)
      ..lineTo(9.8 * u, 14.2 * u)
      ..lineTo(2 * u, 12 * u)
      ..lineTo(9.8 * u, 9.8 * u)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    if (dot) {
      canvas.drawCircle(
        Offset(19 * u, 5 * u),
        1.8 * u,
        Paint()..color = _CardColors.logoDot,
      );
    }
  }

  @override
  bool shouldRepaint(SparklePainter old) =>
      old.color != color || old.dot != dot;
}
