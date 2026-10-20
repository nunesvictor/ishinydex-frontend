import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/features/catalog/catalog_providers.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/dex_recipe_picker.dart';

/// A mudança do padrão que ainda vale para o dex (#308): `null` sem
/// mudança, ou quando o usuário escolheu "Não atualizar" para ela.
DexUpdatePreview? pendingUpdate(WidgetRef ref, PersonalDex dex) {
  final preview = ref
      .watch(dexUpdateProvider((dexId: dex.id, dropRemoved: true)))
      .value;
  if (preview == null || preview.signature == dex.updateIgnored) return null;
  return preview;
}

/// "+56" ou "+56 −2": o resumo da mudança, no menu.
String updateChange(DexUpdatePreview preview) => [
  if (preview.added.isNotEmpty) '+${preview.added.length}',
  if (preview.removed.isNotEmpty) '−${preview.removed.length}',
].join(' ');

/// O aviso no topo do dex (#308): o padrão mudou desde que ele foi criado.
/// Some com "Agora não" (fica no menu) e com a atualização.
class DexUpdateBanner extends ConsumerWidget {
  const DexUpdateBanner({required this.dex, super.key});

  final PersonalDex dex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = pendingUpdate(ref, dex);
    if (preview == null || preview.signature == dex.updateLater) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card.filled(
        key: const ValueKey('dex-update-banner'),
        margin: EdgeInsets.zero,
        color: theme.colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.update),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Text(
                      l10n.dexUpdateTitle,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      l10n.dexUpdateBody(_changes(l10n, preview)),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Wrap(
                      children: [
                        TextButton(
                          onPressed: () => showDexUpdateSheet(context, dex),
                          child: Text(l10n.dexUpdateSee),
                        ),
                        TextButton(
                          onPressed: () => _later(context, ref, preview),
                          child: Text(l10n.dexUpdateLater),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _later(
    BuildContext context,
    WidgetRef ref,
    DexUpdatePreview preview,
  ) async {
    try {
      await ref
          .read(dexActionsProvider)
          .snoozeUpdate(dex.id, signature: preview.signature, ignore: false);
    } on AppFailure catch (failure) {
      if (context.mounted) _notify(context, context.failureText(failure));
    }
  }
}

/// "entraram 56 formas e saíram 2".
String _changes(AppLocalizations l10n, DexUpdatePreview preview) => [
  if (preview.added.isNotEmpty) l10n.dexUpdateAdded(preview.added.length),
  if (preview.removed.isNotEmpty) l10n.dexUpdateRemoved(preview.removed.length),
].join(l10n.dexUpdateAnd);

/// A prévia da atualização (#308): o que entra e sai e as três escolhas,
/// cada uma com o que faz nas boxes do HOME.
Future<void> showDexUpdateSheet(BuildContext context, PersonalDex dex) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DexUpdateSheet(dex: dex),
    );

enum _Choice { inOrder, atEnd, skip }

class DexUpdateSheet extends ConsumerStatefulWidget {
  const DexUpdateSheet({required this.dex, super.key});

  final PersonalDex dex;

  @override
  ConsumerState<DexUpdateSheet> createState() => _DexUpdateSheetState();
}

class _DexUpdateSheetState extends ConsumerState<DexUpdateSheet> {
  _Choice _choice = _Choice.inOrder;
  bool _dropRemoved = true;
  bool _saving = false;

  /// Quantos nomes de forma a lista mostra antes do "e mais".
  static const _listed = 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final preview = ref
        .watch(
          dexUpdateProvider((dexId: widget.dex.id, dropRemoved: _dropRemoved)),
        )
        .value;
    final hint = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    if (preview == null) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    String names(List<FormRef> forms) {
      final shown = [for (final f in forms.take(_listed)) f.displayName];
      return [
        shown.join(', '),
        if (forms.length > _listed) l10n.dexUpdateMore(forms.length - _listed),
      ].join(' ');
    }

    final fits = switch (_choice) {
      _Choice.inOrder => preview.inOrderFits,
      _Choice.atEnd => preview.atEndFits,
      _Choice.skip => true,
    };
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Text(
              l10n.dexUpdateSheetTitle(widget.dex.name),
              style: theme.textTheme.titleLarge,
            ),
            Text(
              l10n.dexUpdateCreatedAs(_recipeLabel(preview.recipe)),
              style: hint,
            ),
            Card.filled(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    if (preview.added.isNotEmpty) ...[
                      Text(
                        l10n.dexUpdatePlus(preview.added.length),
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(names(preview.added), style: hint),
                    ],
                    if (preview.removed.isNotEmpty) ...[
                      Text(
                        l10n.dexUpdateMinus(preview.removed.length),
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(names(preview.removed), style: hint),
                    ],
                  ],
                ),
              ),
            ),
            if (preview.removed.isNotEmpty)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.dexUpdateDropRemoved),
                subtitle: Text(
                  l10n.dexUpdateDropRemovedHint(preview.removedWithSpecimen),
                ),
                value: _dropRemoved,
                onChanged: (v) => setState(() => _dropRemoved = v),
              ),
            Text(l10n.dexUpdateWhere, style: theme.textTheme.titleSmall),
            RadioGroup<_Choice>(
              groupValue: _choice,
              onChanged: (choice) => setState(() => _choice = choice!),
              child: Column(
                children: [
                  _option(
                    _Choice.inOrder,
                    l10n.dexUpdateInOrder,
                    l10n.dexUpdateInOrderHint,
                    [
                      if (preview.changedBoxes.isNotEmpty)
                        l10n.dexUpdateInOrderImpact(
                          _range(l10n, preview.changedBoxes),
                          preview.boxesBefore,
                          preview.boxesAfter,
                        ),
                      l10n.dexUpdateMoved(preview.movedSpecimens),
                      if (!preview.inOrderFits) l10n.dexUpdateNoSpace,
                    ],
                  ),
                  _option(
                    _Choice.atEnd,
                    l10n.dexUpdateAtEnd,
                    l10n.dexUpdateAtEndHint,
                    [
                      if (preview.atEndBoxes.isEmpty)
                        l10n.dexUpdateNothingNew
                      else
                        l10n.dexUpdateAtEndImpact(
                          preview.atEndBoxes
                              .map((b) => '${b.name} (${b.forms})')
                              .join(', '),
                        ),
                      if (!preview.atEndFits) l10n.dexUpdateNoSpace,
                    ],
                  ),
                  _option(
                    _Choice.skip,
                    l10n.dexUpdateSkip,
                    l10n.dexUpdateSkipHint,
                    const [],
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: _saving || !fits ? null : () => _confirm(preview),
              child: Text(switch (_choice) {
                _Choice.inOrder => l10n.dexUpdateConfirmInOrder,
                _Choice.atEnd => l10n.dexUpdateConfirmAtEnd,
                _Choice.skip => l10n.dexUpdateConfirmSkip,
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _option(
    _Choice value,
    String title,
    String hint,
    List<String> impact,
  ) {
    final theme = Theme.of(context);
    return RadioListTile<_Choice>(
      key: ValueKey('dex-update-${value.name}'),
      value: value,
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Text(hint),
          for (final line in impact)
            Text(
              line,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  /// "Nacional · Living Form Lite · o padrão" ou "Scarlet / Violet · Living".
  String _recipeLabel(DexRecipe recipe) {
    final l10n = context.l10n;
    final catalog = ref.read(catalogLoadProvider)?.catalog;
    final base = switch (recipe.versionGroup) {
      final group? when catalog != null => gameLabel(catalog, group),
      _ => l10n.dexNational,
    };
    return '$base · ${presetLabel(l10n, recipe.preset)}';
  }

  Future<void> _confirm(DexUpdatePreview preview) async {
    setState(() => _saving = true);
    final actions = ref.read(dexActionsProvider);
    final l10n = context.l10n;
    try {
      if (_choice == _Choice.skip) {
        await actions.snoozeUpdate(
          widget.dex.id,
          signature: preview.signature,
          ignore: true,
        );
      } else {
        await actions.applyUpdate(
          widget.dex.id,
          mode: _choice == _Choice.inOrder
              ? DexUpdateMode.inOrder
              : DexUpdateMode.atEnd,
          dropRemoved: _dropRemoved,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      if (_choice != _Choice.skip) _notify(context, l10n.dexUpdated);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() => _saving = false);
      _notify(context, context.failureText(failure));
    }
  }
}

/// "HOME 39 a HOME 47" (ou só uma box).
String _range(AppLocalizations l10n, List<String> boxes) => boxes.length == 1
    ? boxes.single
    : l10n.dexUpdateBoxRange(boxes.first, boxes.last);

void _notify(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
