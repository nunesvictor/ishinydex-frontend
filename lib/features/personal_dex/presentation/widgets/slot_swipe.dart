import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// O deslizar entre slots no painel (#256): o conteúdo acompanha o dedo e,
/// ao soltar, completa a troca ou volta com uma mola, como as fotos do
/// iPhone.
///
/// Não é um `PageView` porque o vizinho não precisa estar pronto antes (o da
/// box seguinte nem carregou): só o slot atual se move com o dedo. Ao
/// completar, ele termina de sair pelo lado do gesto e chama [onNext] ou
/// [onPrevious]; quando o [child] novo chega (outra `key`), ele entra
/// inteiro pelo lado oposto. Uma troca pelas setas ([direction] 1 ou -1)
/// entra do mesmo jeito; um toque na grade ([direction] 0) troca na hora.
class SlotSwipe extends StatefulWidget {
  const SlotSwipe({
    required this.child,
    required this.direction,
    this.onPrevious,
    this.onNext,
    super.key,
  });

  /// O conteúdo do slot, com uma `key` por slot.
  final Widget child;

  /// Para onde foi o último passo: 1 (seguinte), -1 (anterior) ou 0.
  final int direction;

  /// `null` no começo (ou no fim) do dex: o gesto resiste e não troca.
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

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
  /// (1: pela direita; -1: pela esquerda); `null` sem gesto pendente.
  int? _pendingEnter;
  Timer? _giveUp;

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void didUpdateWidget(SlotSwipe old) {
    super.didUpdateWidget(old);
    if (widget.child.key == old.child.key) return;
    _giveUp?.cancel();
    // O slot mudou: pelo gesto (entra do lado oposto ao que saiu), pelas
    // setas (entra do lado do passo) ou pela grade (na hora).
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
      _complete(target, dx.sign.toInt(), velocity);
    } else {
      _settle(velocity);
    }
  }

  /// Termina de sair pelo lado do gesto e chama [target].
  void _complete(VoidCallback target, int sign, double velocity) {
    // O novo entra pelo lado oposto ao que o atual saiu.
    _pendingEnter = -sign;
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
            builder: (context, child) => Transform.translate(
              offset: Offset(_offset.value, 0),
              child: child,
            ),
            child: widget.child,
          ),
        ),
      );
    },
  );
}
