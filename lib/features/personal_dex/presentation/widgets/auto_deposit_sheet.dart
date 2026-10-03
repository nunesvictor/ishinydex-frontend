import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
              Text(
                'Depositar automaticamente',
                style: theme.textTheme.titleLarge,
              ),
              Text(
                'Preenche os slots vazios de ${_dex.name} com espécimes do '
                'inventário que ainda não estão em nenhum slot.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        SwitchListTile.adaptive(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          title: Text(
            _dex.isShinyDex ? 'Só espécimes shiny' : 'Só espécimes não shiny',
          ),
          subtitle: Text(
            _dex.isShinyDex
                ? 'Desligado: usa um não shiny quando não há shiny da forma.'
                : 'Desligado: usa um shiny quando não há outro da forma.',
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
            AsyncData(:final value) when value.linked == 0 => const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Nenhum espécime livre para os slots vazios deste dex.',
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
                  child: Text(linked == 0 ? 'Fechar' : 'Cancelar'),
                ),
              ),
              if (linked > 0)
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _confirm,
                    child: Text('Depositar $linked'),
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
        _error = failure.message;
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
              if (result.linked == 1)
                '1 espécime pode ser depositado'
              else
                '${result.linked} espécimes podem ser depositados',
              if (missing == 1)
                '1 slot vazio continua sem'
              else if (missing > 1)
                '$missing slots vazios continuam sem',
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
                    '${slot.box.name} · linha ${slot.row + 1}, '
                    'coluna ${slot.col + 1}',
                  ),
                  // A exceção à preferência do dex fica marcada.
                  trailing: slot.specimen?.isShiny == isShinyDex
                      ? null
                      : Chip(
                          label: Text(isShinyDex ? 'Não shiny' : 'Shiny'),
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
