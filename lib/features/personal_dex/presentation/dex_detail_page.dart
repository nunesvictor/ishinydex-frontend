import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/responsive/breakpoints.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/confirm_dialog.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/box_list_panel.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/box_navigator.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/box_view.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/dex_switcher.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/slot_detail_panel.dart';
import 'package:ishinydex/features/specimens/presentation/deposit_flow.dart';

/// Boxes de um PersonalDex.
///
/// - expandido: lista de boxes | grade | detalhe do slot
/// - médio: grade | detalhe do slot
/// - compacto: grade com swipe entre boxes; detalhe em bottom sheet
class DexDetailPage extends ConsumerStatefulWidget {
  const DexDetailPage({required this.dexId, super.key});

  final int dexId;

  @override
  ConsumerState<DexDetailPage> createState() => _DexDetailPageState();
}

class _DexDetailPageState extends ConsumerState<DexDetailPage> {
  int _boxIndex = 0;
  int? _selectedSlotId;
  bool _onlyMissing = false;
  PageController? _pageController;

  int get _dexId => widget.dexId;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(lastDexStorageProvider).write(_dexId));
  }

  bool get _preferShiny =>
      ref.read(dexProvider(_dexId)).value?.isShinyDex ?? false;

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dex = ref.watch(dexProvider(_dexId));
    final boxes = ref.watch(boxesProvider(_dexId));
    return Scaffold(
      appBar: AppBar(
        title: DexSwitcher(
          dexId: _dexId,
          title: dex.value?.name ?? 'PersonalDex',
        ),
        actions: [
          IconButton(
            tooltip: _onlyMissing ? 'Mostrar todos' : 'Destacar faltantes',
            isSelected: _onlyMissing,
            onPressed: () => setState(() => _onlyMissing = !_onlyMissing),
            icon: const Icon(Icons.filter_alt_outlined),
            selectedIcon: const Icon(Icons.filter_alt),
          ),
        ],
      ),
      body: switch (dex) {
        AsyncError(:final error) when !dex.hasValue => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(dexProvider(_dexId)),
        ),
        _ => boxes.when(
          skipLoadingOnRefresh: true,
          data: (items) => items.isEmpty
              ? const EmptyView(message: 'Este dex ainda não tem boxes.')
              : _buildLayout(context, items),
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(boxesProvider(_dexId)),
          ),
        ),
      },
    );
  }

  Widget _buildLayout(BuildContext context, List<BoxSummary> boxes) {
    final index = _boxIndex.clamp(0, boxes.length - 1);
    final box = boxes[index];
    final size = WindowSize.of(context);
    if (size.isCompact) return _buildCompact(boxes, index);
    _releasePageController();

    final grid = Column(
      children: [
        BoxNavigator(boxes: boxes, index: index, onChanged: _selectBox),
        Expanded(child: _boxView(box)),
      ],
    );
    final detail = SizedBox(
      width: size.isExpanded ? 320 : 280,
      child: SlotDetailPanel(
        slot: _selectedSlot(box),
        onDeposit: () => _deposit(_selectedSlot(box)!),
        onWithdraw: () => _withdraw(_selectedSlot(box)!),
      ),
    );
    return Row(
      children: [
        if (size.isExpanded) ...[
          SizedBox(
            width: 220,
            child: BoxListPanel(
              boxes: boxes,
              index: index,
              onSelected: _selectBox,
            ),
          ),
          const VerticalDivider(width: 1),
        ],
        Expanded(child: grid),
        const VerticalDivider(width: 1),
        detail,
      ],
    );
  }

  Widget _buildCompact(List<BoxSummary> boxes, int index) {
    final controller = _pageController ??= PageController(initialPage: index);
    return Column(
      children: [
        BoxNavigator(
          boxes: boxes,
          index: index,
          onChanged: (i) {
            _selectBox(i);
            controller.jumpToPage(i);
          },
        ),
        Expanded(
          child: PageView.builder(
            controller: controller,
            itemCount: boxes.length,
            onPageChanged: _selectBox,
            itemBuilder: (context, i) => _boxView(boxes[i], compact: true),
          ),
        ),
      ],
    );
  }

  Widget _boxView(BoxSummary box, {bool compact = false}) => BoxView(
    dexId: _dexId,
    boxId: box.id,
    selectedSlotId: _selectedSlotId,
    onlyMissing: _onlyMissing,
    onSlotTap: (slot) {
      setState(() => _selectedSlotId = slot.id);
      if (compact) unawaited(_showSlotSheet(box));
    },
  );

  void _selectBox(int index) => setState(() {
    _boxIndex = index;
    _selectedSlotId = null;
  });

  /// Slot selecionado, sempre na versão mais recente vinda da API.
  Slot? _selectedSlot(BoxSummary box) {
    final slots = ref
        .watch(slotsProvider((dexId: _dexId, boxId: box.id)))
        .value;
    if (slots == null) return null;
    for (final slot in slots) {
      if (slot.id == _selectedSlotId) return slot;
    }
    return null;
  }

  void _releasePageController() {
    final old = _pageController;
    if (old == null) return;
    _pageController = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  Future<void> _showSlotSheet(BoxSummary box) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final slot = _selectedSlot(box);
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: SlotDetailPanel(
            slot: slot,
            onDeposit: () {
              Navigator.of(sheetContext).pop();
              unawaited(_deposit(slot!));
            },
            onWithdraw: () {
              Navigator.of(sheetContext).pop();
              unawaited(_withdraw(slot!));
            },
          ),
        );
      },
    ),
  );

  Future<void> _deposit(Slot slot) async {
    final deposited = await showDepositFlow(
      context,
      slot: slot,
      preferShiny: _preferShiny,
    );
    if (deposited && mounted) _notify('Specimen depositado.');
  }

  Future<void> _withdraw(Slot slot) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Retirar specimen?',
      message:
          '${slot.specimen?.displayName ?? 'O specimen'} voltará a ficar '
          'disponível e o slot ficará faltante.',
      confirmLabel: 'Retirar',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(slotActionsProvider).withdraw(slot);
      _notify('Specimen retirado.');
    } on AppFailure catch (failure) {
      _notify(failure.message);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
