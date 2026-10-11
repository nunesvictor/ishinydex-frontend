import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';

/// Os slots por onde o painel navega, na ordem da grade (linha a linha).
///
/// Ficam de fora os slots livres (sem forma) e, com o filtro de faltantes,
/// os registrados, que aparecem apagados na grade. [keep] é o slot
/// selecionado: ele entra mesmo assim (dá para tocar num slot apagado), para
/// a posição "n de N" e as setas partirem dele.
List<Slot> navigableSlots(
  List<Slot> slots, {
  required bool onlyMissing,
  int? keep,
}) => [
  for (final slot in slots)
    if (!slot.isFree && (!onlyMissing || slot.isMissing || slot.id == keep))
      slot,
]..sort((a, b) => a.row != b.row ? a.row.compareTo(b.row) : a.col - b.col);

/// A navegação do painel do slot: a posição na box e as setas, que fazem o
/// mesmo que deslizar. Uma seta `null` fica desligada (início ou fim do dex).
class SlotNavigation {
  const SlotNavigation({
    required this.label,
    this.onPrevious,
    this.onNext,
    this.notice,
    this.direction = 0,
  });

  /// "HOME 1 · L1 C2 · 2 de 30".
  final String label;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// A última troca de box pela navegação, para o balão; `null` se a seleção
  /// não veio de uma troca de box.
  final BoxNotice? notice;

  /// Para onde foi o último passo: 1 (seguinte), -1 (anterior) ou 0 (um
  /// toque na grade). Decide de que lado o slot novo entra.
  final int direction;
}

/// Uma troca de box. O [id] muda a cada troca, então duas trocas seguidas
/// para a mesma box mostram o balão de novo.
@immutable
class BoxNotice {
  const BoxNotice(this.id, this.boxName);

  final int id;
  final String boxName;
}

/// A linha com a posição do slot entre as setas "Slot anterior" e "Próximo
/// slot". No PC, onde não se desliza, as setas fazem o papel do gesto.
class SlotNavigationBar extends StatelessWidget {
  const SlotNavigationBar(this.navigation, {super.key});

  final SlotNavigation navigation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Slot anterior',
          visualDensity: VisualDensity.compact,
          onPressed: navigation.onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Flexible(
          child: Text(
            navigation.label,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
        IconButton(
          tooltip: 'Próximo slot',
          visualDensity: VisualDensity.compact,
          onPressed: navigation.onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

/// O balão da troca de box: uma pílula com o nome da box no topo do painel,
/// que some sozinha depois de [visibleFor]. Não é um `SnackBar` porque, no
/// celular, ele ficaria atrás do bottom sheet.
class BoxNoticeBalloon extends StatefulWidget {
  const BoxNoticeBalloon(this.notice, {super.key});

  final BoxNotice notice;

  static const visibleFor = Duration(milliseconds: 1500);

  @override
  State<BoxNoticeBalloon> createState() => _BoxNoticeBalloonState();
}

class _BoxNoticeBalloonState extends State<BoxNoticeBalloon> {
  bool _visible = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(BoxNoticeBalloon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notice.id != widget.notice.id) {
      _visible = true;
      _schedule();
    }
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(BoxNoticeBalloon.visibleFor, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: _visible ? 1 : 0,
        child: Material(
          color: scheme.surfaceContainerHighest,
          elevation: 1,
          shape: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                const Icon(Icons.swap_horiz, size: 18),
                Text(
                  widget.notice.boxName,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
