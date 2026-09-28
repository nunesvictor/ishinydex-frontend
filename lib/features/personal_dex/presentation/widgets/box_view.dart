import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/box_grid.dart';

/// Carrega os slots de uma box e exibe a grade.
class BoxView extends ConsumerWidget {
  const BoxView({
    required this.dexId,
    required this.boxId,
    required this.onSlotTap,
    this.selectedSlotId,
    this.onlyMissing = false,
    super.key,
  });

  final int dexId;
  final int boxId;
  final int? selectedSlotId;
  final bool onlyMissing;
  final ValueChanged<Slot> onSlotTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (dexId: dexId, boxId: boxId);
    return ref
        .watch(slotsProvider(key))
        .when(
          skipLoadingOnRefresh: true,
          data: (slots) => Padding(
            padding: const EdgeInsets.all(8),
            child: BoxGrid(
              slots: slots,
              selectedSlotId: selectedSlotId,
              onlyMissing: onlyMissing,
              onSlotTap: onSlotTap,
            ),
          ),
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(slotsProvider(key)),
          ),
        );
  }
}
