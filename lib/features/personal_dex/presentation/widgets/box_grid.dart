import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/slot_tile.dart';
import 'package:ishinydex/features/shiny_hunts/shiny_hunt_providers.dart';

const boxRows = 5;
const boxCols = 6;

/// Tamanho máximo da célula: em telas grandes a grade ocupa o espaço livre,
/// até este limite.
const maxCellSize = 200.0;

/// Lado da célula e vão entre as células para a grade caber em [available].
///
/// O [BoxGrid] usa isto para se desenhar, e a página do dex para pôr a busca
/// logo abaixo da grade, sem precisar medir a tela depois de desenhada.
({double cell, double gap}) boxGridMetrics(Size available) {
  // Mais espaço, mais respiro entre as células.
  final gap = available.width >= 800 ? 8.0 : 4.0;
  final cell = [
    (available.width - gap * (boxCols - 1)) / boxCols,
    (available.height - gap * (boxRows - 1)) / boxRows,
  ].reduce((a, b) => a < b ? a : b).clamp(24.0, maxCellSize);
  return (cell: cell, gap: gap);
}

/// Tamanho que a grade ocupa (ela fica centralizada em [available]).
Size boxGridSize(Size available) {
  final (:cell, :gap) = boxGridMetrics(available);
  return Size(
    boxCols * cell + (boxCols - 1) * gap,
    boxRows * cell + (boxRows - 1) * gap,
  );
}

/// Grade 5×6 de uma box, no mesmo layout do Pokémon HOME.
///
/// A API só devolve os slots do dex; as posições que sobram (ex.: o fim da
/// última box de uma geração) viram [EmptySlotTile], para a box ter sempre
/// 30 células como no HOME.
class BoxGrid extends ConsumerWidget {
  const BoxGrid({
    required this.slots,
    required this.onSlotTap,
    this.selectedSlotId,
    this.onlyMissing = false,
    super.key,
  });

  final List<Slot> slots;
  final int? selectedSlotId;
  final bool onlyMissing;
  final ValueChanged<Slot> onSlotTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byPosition = {for (final s in slots) (s.row, s.col): s};
    final hunted = ref.watch(huntedFormsProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final (:cell, :gap) = boxGridMetrics(constraints.biggest);
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: gap,
            children: [
              for (var row = 0; row < boxRows; row++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: gap,
                  children: [
                    for (var col = 0; col < boxCols; col++)
                      SizedBox.square(
                        dimension: cell,
                        child: _cell(byPosition[(row, col)], hunted),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _cell(Slot? slot, Set<int> hunted) {
    if (slot == null || slot.isFree) return const EmptySlotTile();
    return SlotTile(
      slot: slot,
      // Caçada em andamento e o slot ainda precisa do Pokémon (faltante, ou
      // registrado sem ser shiny).
      hunting:
          hunted.contains(slot.form?.id) && !(slot.specimen?.isShiny ?? false),
      selected: slot.id == selectedSlotId,
      dimmed: onlyMissing && !slot.isMissing,
      onTap: () => onSlotTap(slot),
    );
  }
}
