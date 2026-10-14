import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';

/// Menu ⋮ do dex → Depositar automaticamente: espécimes do inventário que
/// estão sem slot vão para os slots vazios do [dex] (a regra é do backend,
/// a mesma do comando `link_specimens`).
///
/// Antes de depositar, a folha mostra a prévia (`dry_run`): quantos e onde,
/// com o selo "Não shiny" nas exceções de um shiny dex. Devolve o resultado
/// do depósito, ou `null` se desistiu.
Future<LinkResult?> showAutoDepositSheet(
  BuildContext context, {
  required PersonalDex dex,
}) => showModalBottomSheet<LinkResult>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
    ),
    child: AutoDepositSheet(dex: dex),
  ),
);

class AutoDepositSheet extends ConsumerStatefulWidget {
  const AutoDepositSheet({required this.dex, super.key});

  final PersonalDex dex;

  @override
  ConsumerState<AutoDepositSheet> createState() => _AutoDepositSheetState();
}

class _AutoDepositSheetState extends ConsumerState<AutoDepositSheet> {
  /// "Só espécimes shiny" (só o brilho do dex).
  bool _strict = false;
  bool _busy = false;
  String? _error;

  PersonalDex get _dex => widget.dex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = ref.watch(
      linkPreviewProvider((dexId: _dex.id, strict: _strict)),
    );
    final linked = preview.value?.linked ?? 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Text(context.l10n.autoDeposit, style: theme.textTheme.titleLarge),
              Text(
                context.l10n.autoDepositIntro(_dex.name),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        SwitchListTile.adaptive(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          title: Text(
            _dex.isShinyDex
                ? context.l10n.onlyShinySpecimens
                : context.l10n.onlyNonShinySpecimens,
          ),
          subtitle: Text(
            _dex.isShinyDex
                ? context.l10n.autoDepositOffShiny
                : context.l10n.autoDepositOffNonShiny,
          ),
          value: _strict,
          onChanged: _busy ? null : (value) => setState(() => _strict = value),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        Flexible(
          child: switch (preview) {
            AsyncData(:final value) when value.linked == 0 => Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.l10n.autoDepositNone,
                textAlign: TextAlign.center,
              ),
            ),
            AsyncData(:final value) => _PreviewList(
              result: value,
              isShinyDex: _dex.isShinyDex,
            ),
            AsyncError(:final error) => ErrorView(
              error: error,
              onRetry: () => ref.invalidate(
                linkPreviewProvider((dexId: _dex.id, strict: _strict)),
              ),
            ),
            _ => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            spacing: 8,
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    linked == 0 ? context.l10n.close : context.l10n.cancel,
                  ),
                ),
              ),
              if (linked > 0)
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _confirm,
                    child: Text(context.l10n.depositCount(linked)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(slotActionsProvider)
          .linkSpecimens(_dex.id, strict: _strict);
      if (mounted) Navigator.of(context).pop(result);
    } on AppFailure catch (failure) {
      setState(() {
        _busy = false;
        _error = context.failureText(failure);
      });
    }
  }
}

class _PreviewList extends StatelessWidget {
  const _PreviewList({required this.result, required this.isShinyDex});

  final LinkResult result;
  final bool isShinyDex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missing = result.missing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
          child: Text(
            [
              context.l10n.autoDepositCanDeposit(result.linked),
              if (missing > 0) context.l10n.autoDepositStillEmpty(missing),
            ].join(' · '),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final slot in result.slots)
                ListTile(
                  key: ValueKey('link-${slot.id}'),
                  leading: PokemonSprite(url: slot.spriteUrl, size: 40),
                  title: Text(
                    slot.specimen?.displayName ?? slot.form!.displayName,
                  ),
                  subtitle: Text(
                    context.l10n.slotPosition(
                      slot.box.name,
                      slot.row + 1,
                      slot.col + 1,
                    ),
                  ),
                  // A exceção à preferência do dex fica marcada.
                  trailing: slot.specimen?.isShiny == isShinyDex
                      ? null
                      : Chip(
                          label: Text(
                            isShinyDex
                                ? context.l10n.notShiny
                                : context.l10n.markShiny,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
