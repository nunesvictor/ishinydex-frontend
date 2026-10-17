import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:ishinydex/core/web/browser.dart' as browser;

/// Põe a altura da barra de status do iPhone no `MediaQuery` (#290).
///
/// No PWA, a barra de status é transparente (`black-translucent` no
/// `index.html`) e o app desenha por baixo dela: a faixa grafite do topo
/// pinta a barra, nos dois temas, e o bug do WebKit (a barra não troca de
/// cor com o app aberto) deixa de importar. O Flutter web não sabe a altura
/// dessa barra (o `viewPadding` dele é sempre zero); este widget a lê da
/// página e a soma ao `padding` e ao `viewPadding`, então a `AppBar` e o
/// `SafeArea` descem o conteúdo, e o fundo da `AppBar` sobe até o topo.
class WebSafeArea extends StatelessWidget {
  const WebSafeArea({
    required this.child,
    this.readTop = browser.safeAreaTop,
    super.key,
  });

  final Widget child;

  /// A altura da barra, lida a cada mudança da tela (girar o iPad, por
  /// exemplo). Fora do navegador, 0.
  final double Function() readTop;

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.of(context);
    final top = readTop();
    if (top <= data.padding.top) return child;
    return MediaQuery(
      data: data.copyWith(
        padding: data.padding.copyWith(top: top),
        viewPadding: data.viewPadding.copyWith(
          top: math.max(top, data.viewPadding.top),
        ),
      ),
      child: child,
    );
  }
}
