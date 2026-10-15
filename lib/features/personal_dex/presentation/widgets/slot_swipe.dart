import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:ishinydex/core/l10n/l10n.dart';

/// O deslizar entre slots no painel (#256): o conteúdo acompanha o dedo e,
/// ao soltar, completa a troca ou volta com uma mola, como as fotos do
/// iPhone.
///
/// Durante o gesto, o vizinho entra junto pelo lado oposto (#267): o slot
/// ao lado, na mesma box, ou a prévia da box vizinha ([previous], [next]).
/// No começo e no fim do dex não há vizinho: o conteúdo resiste e aparece
/// "Início do dex" ou "Fim do dex".
///
/// Não é um `PageView`: o vizinho só é montado durante o gesto, e o da box
/// seguinte nem precisa ter carregado. Ao completar, o atual termina de
/// sair e chama [onNext] ou [onPrevious]; quando o [child] novo chega
/// (outra `key`), ele toma o lugar da prévia, que já estava no centro. Uma
/// troca pelas setas ([direction] 1 ou -1) entra pelo lado do passo; um
/// toque na grade ([direction] 0) troca na hora.
class SlotSwipe extends StatefulWidget {
  const SlotSwipe({
    required this.child,
    required this.direction,
    this.onPrevious,
    this.onNext,
    this.previous,
    this.next,
    super.key,
  });

  /// O conteúdo do slot, com uma `key` por slot.
  final Widget child;

  /// Para onde foi o último passo: 1 (seguinte), -1 (anterior) ou 0.
  final int direction;

  /// `null` no começo (ou no fim) do dex: o gesto resiste e não troca.
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// O que aparece de cada lado durante o gesto (#267).
  final Widget? previous;
  final Widget? next;

  /// Velocidade mínima (px/s) para soltar no meio e ainda completar.
  static const flingVelocity = 200.0;

  /// Fração da largura que, arrastada, completa a troca mesmo devagar.
  static const double completeFraction = 1 / 3;

  /// Quanto o conteúdo anda, por px do dedo, quando não há para onde ir.
  static const resistance = 0.3;

  /// Duração da entrada do slot novo.
  static const enterDuration = Duration(milliseconds: 250);

  /// Se o slot novo não chegar nesse tempo (não havia para onde ir), o
  /// antigo volta.
  static const giveUp = Duration(milliseconds: 800);

  @override
  State<SlotSwipe> createState() => _SlotSwipeState();
}

class _SlotSwipeState extends State<SlotSwipe>
    with SingleTickerProviderStateMixin {
  /// O deslocamento horizontal do conteúdo, em px (sem limites: vai de
  /// -largura a +largura).
  late final AnimationController _offset = AnimationController.unbounded(
    vsync: this,
  );

  double _width = 0;

  /// Lado de onde o próximo slot deve entrar, depois de um gesto completo
  /// (1: pela direita; -1: pela esquerda; 0: já está no lugar, porque a
  /// prévia entrou junto); `null` sem gesto pendente.
  int? _pendingEnter;
  Timer? _giveUp;

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void didUpdateWidget(SlotSwipe old) {
    super.didUpdateWidget(old);
    if (widget.child.key == old.child.key) return;
    _giveUp?.cancel();
    // O slot mudou: pelo gesto (a prévia já estava no lugar), pelas setas
    // (entra do lado do passo) ou pela grade (na hora).
    final side = _pendingEnter ?? widget.direction.sign;
    _pendingEnter = null;
    if (side == 0 || _reduceMotion || _width == 0) {
      _offset.value = 0;
      return;
    }
    _offset
      ..value = side * _width
      ..animateTo(0, duration: SlotSwipe.enterDuration, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _giveUp?.cancel();
    _offset.dispose();
    super.dispose();
  }

  /// O vizinho do lado para onde o dedo vai: arrastar para a esquerda (dx
  /// negativo) traz o seguinte.
  VoidCallback? _target(double dx) => dx < 0
      ? widget.onNext
      : dx > 0
      ? widget.onPrevious
      : null;

  /// A prévia do lado para onde o dedo vai.
  Widget? _preview(double dx) => dx < 0
      ? widget.next
      : dx > 0
      ? widget.previous
      : null;

  void _onUpdate(DragUpdateDetails details) {
    if (_pendingEnter != null) return;
    _offset.stop();
    final delta = details.primaryDelta ?? 0;
    final next = _offset.value + delta;
    // Sem vizinho, o conteúdo anda menos que o dedo.
    _offset.value = _target(next) == null
        ? _offset.value + delta * SlotSwipe.resistance
        : next;
  }

  void _onEnd(DragEndDetails details) {
    if (_pendingEnter != null) return;
    final x = _offset.value;
    final velocity = details.primaryVelocity ?? 0;
    final fling = velocity.abs() > SlotSwipe.flingVelocity;
    // A direção vem da velocidade num gesto rápido; senão, da posição.
    final dx = fling ? velocity : x;
    final target = _target(dx);
    final far = x.abs() > _width * SlotSwipe.completeFraction;
    if (target != null && (fling || far) && x.sign != -dx.sign) {
      _complete(target, dx.sign.toInt(), velocity, preview: _preview(dx));
    } else {
      _settle(velocity);
    }
  }

  /// Termina de sair pelo lado do gesto e chama [target].
  void _complete(
    VoidCallback target,
    int sign,
    double velocity, {
    Widget? preview,
  }) {
    // Com a prévia, o novo já está no lugar quando chega; sem ela, entra
    // pelo lado oposto ao que o atual saiu.
    _pendingEnter = preview == null ? -sign : 0;
    _giveUp = Timer(SlotSwipe.giveUp, () {
      if (!mounted || _pendingEnter == null) return;
      _pendingEnter = null;
      _settle(0);
    });
    if (_reduceMotion) {
      _offset.value = 0;
      target();
      return;
    }
    final end = sign * _width;
    // Continua na velocidade do dedo (com um mínimo, para não arrastar).
    final speed = velocity.abs().clamp(1200.0, 6000.0);
    final ms = ((end - _offset.value).abs() / speed * 1000).clamp(80, 250);
    unawaited(
      _offset
          .animateTo(
            end,
            duration: Duration(milliseconds: ms.round()),
            curve: Curves.easeOut,
          )
          .then((_) => target()),
    );
  }

  /// Volta ao lugar com uma mola.
  void _settle(double velocity) {
    if (_reduceMotion) {
      _offset.value = 0;
      return;
    }
    unawaited(
      _offset
          .animateWith(
            SpringSimulation(
              const SpringDescription(mass: 1, stiffness: 500, damping: 35),
              _offset.value,
              0,
              velocity,
            ),
          )
          // A mola para "quase" no zero (tolerância da simulação).
          .then((_) => _offset.value = 0),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _width = constraints.maxWidth;
      return GestureDetector(
        onHorizontalDragUpdate: _onUpdate,
        onHorizontalDragEnd: _onEnd,
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _offset,
            builder: (context, child) {
              final x = _offset.value;
              // O lado que aparece: à direita ao arrastar para a esquerda.
              final side = x < 0 ? 1 : -1;
              final preview = _preview(x);
              return Stack(
                children: [
                  if (x != 0 && preview != null)
                    Positioned.fill(
                      child: Transform.translate(
                        offset: Offset(x + side * _width, 0),
                        // Só para ver: os toques ficam com o slot atual.
                        child: IgnorePointer(
                          key: ValueKey('swipe-preview-$side'),
                          child: preview,
                        ),
                      ),
                    )
                  else if (x != 0 && _target(x) == null)
                    // Começo ou fim do dex, no espaço que o conteúdo abriu.
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: x > 0 ? 0 : null,
                      right: x < 0 ? 0 : null,
                      width: x.abs(),
                      child: _DexEdge(end: x < 0),
                    ),
                  // Com chave: a prévia entra antes na lista e o slot atual
                  // não é recriado (perderia a rolagem e a aba).
                  Transform.translate(
                    key: const ValueKey('swipe-current'),
                    offset: Offset(x, 0),
                    child: child,
                  ),
                ],
              );
            },
            child: widget.child,
          ),
        ),
      );
    },
  );
}

/// "Início do dex" ou "Fim do dex", no espaço que o gesto abriu.
class _DexEdge extends StatelessWidget {
  const _DexEdge({required this.end});

  final bool end;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: OverflowBox(
        maxWidth: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            Icon(Icons.pause, color: color),
            Text(
              end ? context.l10n.swipeDexEnd : context.l10n.swipeDexStart,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// A prévia da box vizinha (#267): ela pode não ter carregado, então
/// mostra só o nome, e ao soltar vai para o primeiro slot dela (ou o
/// último, voltando).
class BoxPreview extends StatelessWidget {
  const BoxPreview({required this.boxName, required this.forward, super.key});

  final String boxName;

  /// Para a box seguinte (`false`: a anterior).
  final bool forward;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 64, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.grid_view,
                size: 34,
                color: scheme.onSecondaryContainer,
              ),
            ),
            Text(
              (forward ? l10n.swipeNextBox : l10n.swipePreviousBox)
                  .toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              boxName,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              forward ? l10n.swipeNextBoxHint : l10n.swipePreviousBoxHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
