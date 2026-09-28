import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/responsive/breakpoints.dart';
import 'package:ishinydex/core/theme/app_theme.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/confirm_dialog.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_form_page.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Abre o seletor de specimen para [slot]: bottom sheet no compacto,
/// diálogo nos demais. Retorna `true` se algo foi depositado.
Future<bool> showDepositFlow(
  BuildContext context, {
  required Slot slot,
  required bool preferShiny,
}) async {
  final picker = DepositPicker(slot: slot, preferShiny: preferShiny);
  final bool? result;
  if (WindowSize.of(context).isCompact) {
    result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: picker,
      ),
    );
  } else {
    result = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
          child: picker,
        ),
      ),
    );
  }
  return result ?? false;
}

/// Lista specimens disponíveis da forma do slot e deposita o escolhido.
class DepositPicker extends ConsumerStatefulWidget {
  const DepositPicker({
    required this.slot,
    required this.preferShiny,
    super.key,
  });

  final Slot slot;
  final bool preferShiny;

  @override
  ConsumerState<DepositPicker> createState() => _DepositPickerState();
}

class _DepositPickerState extends ConsumerState<DepositPicker> {
  bool _busy = false;
  String? _error;

  FormRef get _form => widget.slot.form!;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final available = ref.watch(availableSpecimensProvider(_form.id));
    final current = widget.slot.specimen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Depositar ${_form.displayName}',
            style: theme.textTheme.titleLarge,
          ),
        ),
        if (current != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${current.displayName} será substituído e voltará a ficar '
              'disponível.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        if (_busy) const LinearProgressIndicator(),
        Expanded(
          child: available.when(
            data: (items) {
              if (items.isEmpty) {
                return const EmptyView(
                  message: 'Nenhum specimen disponível desta forma.',
                );
              }
              final sorted = sortForDeposit(
                items,
                preferShiny: widget.preferShiny,
              );
              return ListView.builder(
                itemCount: sorted.length,
                itemBuilder: (context, i) => _SpecimenTile(
                  specimen: sorted[i],
                  enabled: !_busy,
                  onTap: () => _choose(sorted[i]),
                ),
              );
            },
            loading: () => const LoadingView(),
            error: (error, _) => ErrorView(
              error: error,
              onRetry: () =>
                  ref.invalidate(availableSpecimensProvider(_form.id)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.tonalIcon(
            onPressed: _busy ? null : _createAndDeposit,
            icon: const Icon(Icons.add),
            label: const Text('Cadastrar novo specimen'),
          ),
        ),
      ],
    );
  }

  Future<void> _choose(Specimen specimen) async {
    if (specimen.isShiny != widget.preferShiny) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Confirmar depósito',
        message: widget.preferShiny
            ? 'Este specimen não é shiny, mas o dex é shiny. Depositar mesmo assim?'
            : 'Este specimen é shiny, mas o dex não é shiny. Depositar mesmo assim?',
        confirmLabel: 'Depositar',
      );
      if (!confirmed) return;
    }
    await _deposit(specimen.id);
  }

  Future<void> _createAndDeposit() async {
    final created = await Navigator.of(context).push<Specimen>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            SpecimenFormPage(form: _form, initialShiny: widget.preferShiny),
      ),
    );
    if (created == null) return;
    await _deposit(created.id);
  }

  Future<void> _deposit(int specimenId) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(slotActionsProvider)
          .deposit(widget.slot, specimenId: specimenId);
      if (mounted) Navigator.of(context).pop(true);
    } on AppFailure catch (failure) {
      ref.invalidate(availableSpecimensProvider(_form.id));
      setState(() {
        _busy = false;
        _error = failure.message;
      });
    }
  }
}

class _SpecimenTile extends StatelessWidget {
  const _SpecimenTile({
    required this.specimen,
    required this.enabled,
    required this.onTap,
  });

  final Specimen specimen;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (specimen.isShiny) 'Shiny',
      if (specimen.isAlpha) 'Alfa',
      if (specimen.pokeball != null) prettifyName(specimen.pokeball!),
      if (specimen.capturedAt != null)
        MaterialLocalizations.of(context)
            .formatCompactDate(specimen.capturedAt!),
    ];
    return ListTile(
      key: ValueKey('specimen-${specimen.id}'),
      enabled: enabled,
      leading: PokemonSprite(url: specimen.spriteUrl, size: 48),
      title: Text(specimen.displayName),
      subtitle: details.isEmpty ? null : Text(details.join(' · ')),
      trailing: specimen.isShiny
          ? const Icon(Icons.auto_awesome, color: AppTheme.shinyGold)
          : null,
      onTap: onTap,
    );
  }
}
