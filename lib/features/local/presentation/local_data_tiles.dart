import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/features/local/local_data_providers.dart';
import 'package:ishinydex/features/sync/presentation/sync_page.dart';
import 'package:ishinydex/features/sync/sync_providers.dart';

/// Ajustes → "Seus dados" (modo local): exportar e importar o arquivo de
/// dados. Fora do modo local, não aparece.
class LocalDataTiles extends ConsumerWidget {
  const LocalDataTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(localDataProvider) == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            context.l10n.yourData,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        if (ref.watch(envProvider).syncAvailable) const SyncTile(),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: Text(context.l10n.exportData),
          subtitle: Text(context.l10n.exportDataSubtitle),
          onTap: () => _export(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.upload_outlined),
          title: Text(context.l10n.importData),
          subtitle: Text(context.l10n.importDataSubtitle),
          onTap: () => _import(context, ref),
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final name = await ref.read(localDataActionsProvider).export();
    if (!context.mounted) return;
    _notify(context, context.l10n.exported(name));
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final actions = ref.read(localDataActionsProvider);
    final ({String name, Map<String, dynamic> file})? picked;
    try {
      picked = await actions.pick();
    } on DataFailure catch (failure) {
      if (context.mounted) _notify(context, context.failureText(failure));
      return;
    }
    if (picked == null || !context.mounted) return;
    final merge = await showDialog<bool>(
      context: context,
      builder: (_) => ImportDialog(
        name: picked!.name,
        summary: LocalData.summarize(picked.file),
        syncing: ref.read(syncControllerProvider).connected,
      ),
    );
    if (merge == null) return;
    await actions.import(picked.file, merge: merge);
    if (!context.mounted) return;
    _notify(context, context.l10n.dataImported);
    context.go(Routes.dexes);
  }

  void _notify(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
}

/// Confirma a importação, com o resumo do arquivo; devolve `true` para
/// juntar e `false` para substituir (`null`: cancelou).
class ImportDialog extends StatefulWidget {
  const ImportDialog({
    required this.name,
    required this.summary,
    this.syncing = false,
    super.key,
  });

  final String name;
  final DataFileSummary summary;

  /// Dropbox conectado: o resultado também vai para lá.
  final bool syncing;

  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  bool _merge = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.summary;
    final l10n = context.l10n;
    final when = DateFormat.yMd(l10n.localeName).add_Hm().format(s.savedAt);
    return AlertDialog(
      title: Text(l10n.importDataQuestion),
      // Rola em telas baixas (celular deitado).
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                title: Text(widget.name),
                subtitle: Text(
                  '${l10n.countDexes(s.dexes)} · '
                  '${l10n.countSpecimens(s.specimens)} · '
                  '${l10n.countSaves(s.saves)}\n'
                  '${l10n.exportedOn(when)}',
                ),
              ),
            ),
            const SizedBox(height: 8),
            RadioGroup<bool>(
              groupValue: _merge,
              onChanged: (value) => setState(() => _merge = value!),
              child: Column(
                children: [
                  RadioListTile(
                    value: false,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.importReplace),
                    subtitle: Text(l10n.importReplaceSubtitle),
                  ),
                  RadioListTile(
                    value: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.importMerge),
                    subtitle: Text(l10n.importMergeSubtitle),
                  ),
                ],
              ),
            ),
            if (widget.syncing)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  l10n.importSyncNote,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            Text(l10n.importTip, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _merge),
          child: Text(l10n.importAction),
        ),
      ],
    );
  }
}
