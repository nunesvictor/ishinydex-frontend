import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/features/local/local_data_providers.dart';

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
            'Seus dados',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: const Text('Exportar dados'),
          subtitle: const Text('Baixa um arquivo .json com tudo (backup)'),
          onTap: () => _export(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.upload_outlined),
          title: const Text('Importar dados'),
          subtitle: const Text('Restaura de um arquivo exportado'),
          onTap: () => _import(context, ref),
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final name = await ref.read(localDataActionsProvider).export();
    if (!context.mounted) return;
    _notify(context, 'Exportado: $name');
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final actions = ref.read(localDataActionsProvider);
    final ({String name, Map<String, dynamic> file})? picked;
    try {
      picked = await actions.pick();
    } on FormatException catch (error) {
      if (context.mounted) _notify(context, error.message);
      return;
    }
    if (picked == null || !context.mounted) return;
    final merge = await showDialog<bool>(
      context: context,
      builder: (_) => ImportDialog(
        name: picked!.name,
        summary: LocalData.summarize(picked.file),
      ),
    );
    if (merge == null) return;
    await actions.import(picked.file, merge: merge);
    if (!context.mounted) return;
    _notify(context, 'Dados importados.');
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
  const ImportDialog({required this.name, required this.summary, super.key});

  final String name;
  final DataFileSummary summary;

  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  bool _merge = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.summary;
    final when = DateFormat('dd/MM/yyyy HH:mm').format(s.savedAt);
    String plural(int n, String one, String many) =>
        '$n ${n == 1 ? one : many}';
    return AlertDialog(
      title: const Text('Importar dados?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              title: Text(widget.name),
              subtitle: Text(
                '${plural(s.dexes, 'dex', 'dexes')} · '
                '${plural(s.specimens, 'espécime', 'espécimes')} · '
                '${plural(s.saves, 'save', 'saves')}\n'
                'Exportado em $when',
              ),
            ),
          ),
          const SizedBox(height: 8),
          RadioGroup<bool>(
            groupValue: _merge,
            onChanged: (value) => setState(() => _merge = value!),
            child: const Column(
              children: [
                RadioListTile(
                  value: false,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Substituir os dados deste aparelho'),
                  subtitle: Text('O aparelho fica exatamente como o arquivo.'),
                ),
                RadioListTile(
                  value: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Juntar com os dados deste aparelho'),
                  subtitle: Text(
                    'Registro a registro, vale a mudança mais recente.',
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Dica: exporte antes, para ter como voltar.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _merge),
          child: const Text('Importar'),
        ),
      ],
    );
  }
}
