import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/widgets/confirm_dialog.dart';
import 'package:ishinydex/features/local/local_data_providers.dart';
import 'package:ishinydex/features/sync/domain/sync_engine.dart';
import 'package:ishinydex/features/sync/sync_providers.dart';

/// "há 2 min", "hoje às 09:12", "03/10 às 21:40".
String describeLastSync(DateTime last, DateTime now) {
  final ago = now.difference(last);
  if (ago.inMinutes < 1) return 'agora há pouco';
  if (ago.inMinutes < 60) return 'há ${ago.inMinutes} min';
  final time = DateFormat('HH:mm').format(last);
  final sameDay =
      last.year == now.year && last.month == now.month && last.day == now.day;
  if (sameDay) return 'hoje às $time';
  return '${DateFormat('dd/MM').format(last)} às $time';
}

/// Uma linha sobre o estado, para Ajustes e para a tela de Sincronização.
String describeSync(SyncState state, {DateTime? now}) {
  if (!state.connected) return 'Desligada · os dados ficam só neste aparelho';
  return switch (state.phase) {
    SyncPhase.syncing => 'Sincronizando…',
    SyncPhase.offline => 'Sem conexão · sincroniza quando voltar',
    SyncPhase.error => 'Não foi possível sincronizar',
    _ => switch (state.lastSync) {
      final last? =>
        'Sincronizado ${describeLastSync(last, now ?? DateTime.now())}',
      null => 'Conectada',
    },
  };
}

/// Ajustes → Sincronização: ligar o Dropbox (opcional) e ver o estado.
class SyncPage extends ConsumerStatefulWidget {
  const SyncPage({super.key});

  @override
  ConsumerState<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends ConsumerState<SyncPage> {
  @override
  void initState() {
    super.initState();
    // Com fireImmediately: a pergunta da primeira conexão pode chegar antes
    // de a tela abrir (a volta do login abre o app e já consulta o Dropbox).
    ref.listenManual(syncControllerProvider.select((s) => s.firstSync), (
      _,
      next,
    ) {
      if (next != null) unawaited(_askFirstSync(next));
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(syncControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sincronização')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.error case final error?) ...[
            _Banner(offline: state.phase == SyncPhase.offline, message: error),
            const SizedBox(height: 16),
          ],
          if (state.connected)
            _Connected(state: state)
          else
            const _Disconnected(),
        ],
      ),
    );
  }

  Future<void> _askFirstSync(FirstSyncChoice choice) async {
    // O diálogo abre depois do quadro atual (initState não pode abrir).
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    final mode = await showDialog<FirstSync>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FirstSyncDialog(choice: choice),
    );
    await ref.read(syncControllerProvider.notifier).resolveFirstSync(mode);
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.offline, required this.message});

  final bool offline;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: offline ? scheme.surfaceContainerHigh : scheme.errorContainer,
      child: ListTile(
        leading: Icon(
          offline ? Icons.cloud_off_outlined : Icons.error_outline,
          color: offline ? null : scheme.onErrorContainer,
        ),
        title: Text(message),
        textColor: offline ? null : scheme.onErrorContainer,
      ),
    );
  }
}

class _Disconnected extends ConsumerWidget {
  const _Disconnected();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: Icon(Icons.smartphone_outlined),
            title: Text(
              'Seus dados estão só neste aparelho. Faça backups em '
              '"Exportar dados", ou ligue a sincronização.',
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card.outlined(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Sincronizar com o Dropbox',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const Chip(label: Text('opcional')),
                  ],
                ),
                const SizedBox(height: 8),
                for (final line in const [
                  'Os mesmos dados no PC, no iPhone e no iPad.',
                  'Backup automático, na sua conta do Dropbox.',
                  'O app só acessa a pasta dele, em Apps; sem intermediários.',
                  'Funciona sem internet: sincroniza quando a conexão voltar.',
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('• $line', style: theme.textTheme.bodyMedium),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      ref.read(syncControllerProvider.notifier).connect(),
                  child: const Text('Conectar ao Dropbox'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Dá para desligar quando quiser: os dados continuam neste aparelho '
          'e no Dropbox.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Connected extends ConsumerWidget {
  const _Connected({required this.state});

  final SyncState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(syncControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        state.account == null
                            ? 'Dropbox'
                            : 'Dropbox de ${state.account}',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SyncStatusIcon(phase: state.phase),
                    const SizedBox(width: 8),
                    Expanded(child: Text(describeSync(state))),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Sincroniza ao abrir o app, alguns segundos depois de cada '
                  'mudança e quando você puxa a lista de dexes para '
                  'atualizar.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: state.phase == SyncPhase.syncing
                      ? null
                      : controller.sync,
                  child: const Text('Sincronizar agora'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'No Dropbox',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        const Text('Arquivo ishinydex.json, na pasta do app (dentro de Apps).'),
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error),
            ),
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: 'Desconectar do Dropbox?',
                message:
                    'Os dados continuam neste aparelho e no Dropbox; só a '
                    'sincronização para.',
                confirmLabel: 'Desconectar',
                destructive: true,
              );
              if (confirmed) await controller.disconnect();
            },
            child: const Text('Desconectar'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Desconectar só desliga a sincronização: os dados continuam neste '
          'aparelho e no Dropbox.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// O estado do sync num ícone pequeno.
class SyncStatusIcon extends StatelessWidget {
  const SyncStatusIcon({required this.phase, super.key});

  final SyncPhase phase;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (phase) {
      SyncPhase.syncing => const SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
      SyncPhase.offline => const Icon(Icons.cloud_off_outlined, size: 22),
      SyncPhase.error => Icon(Icons.error_outline, color: scheme.error),
      _ => const Icon(Icons.cloud_done_outlined, size: 22),
    };
  }
}

/// Sync em andamento: uma faixa fina e indeterminada, colada na navegação
/// (ver `AdaptiveShell.activity`). Só aparece se o sync passar de
/// [showDelay]: o sync roda alguns segundos depois de cada mudança e costuma
/// ser rápido, e a faixa não deve piscar a cada toque.
class SyncActivityBar extends ConsumerStatefulWidget {
  const SyncActivityBar({super.key});

  static const showDelay = Duration(milliseconds: 500);

  @override
  ConsumerState<SyncActivityBar> createState() => _SyncActivityBarState();
}

class _SyncActivityBarState extends ConsumerState<SyncActivityBar> {
  Timer? _timer;
  bool _visible = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(syncControllerProvider.select((s) => s.phase), (_, phase) {
      _timer?.cancel();
      if (phase == SyncPhase.syncing) {
        _timer = Timer(
          SyncActivityBar.showDelay,
          () => setState(() => _visible = true),
        );
      } else if (_visible) {
        setState(() => _visible = false);
      }
    });
    if (!_visible) return const SizedBox.shrink();
    return const LinearProgressIndicator(
      minHeight: 3,
      semanticsLabel: 'Sincronizando',
    );
  }
}

/// Selo no ícone de Ajustes quando o sync tem problema: um ponto neutro sem
/// conexão (as mudanças ficam guardadas) e um "!" vermelho com erro (ex.: o
/// acesso ao Dropbox expirou). Em dia, ou sem Dropbox, só o ícone.
class SyncBadge extends ConsumerWidget {
  const SyncBadge({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(syncControllerProvider.select((s) => s.phase));
    return switch (phase) {
      SyncPhase.offline => Badge(
        backgroundColor: Theme.of(context).colorScheme.outline,
        child: Semantics(label: 'Sincronização sem conexão', child: child),
      ),
      SyncPhase.error => Badge(
        label: const Text('!'),
        child: Semantics(label: 'Sincronização com erro', child: child),
      ),
      _ => child,
    };
  }
}

/// Ajustes → Seus dados → Sincronização.
class SyncTile extends ConsumerWidget {
  const SyncTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncControllerProvider);
    final error = state.connected && state.phase == SyncPhase.error;
    return ListTile(
      // Ligada, o ícone mostra o estado (o selo de Ajustes leva até aqui).
      leading: state.connected
          ? SyncStatusIcon(phase: state.phase)
          : const Icon(Icons.cloud_outlined),
      tileColor: error ? Theme.of(context).colorScheme.errorContainer : null,
      title: const Text('Sincronização'),
      subtitle: Text(describeSync(state)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.go(Routes.sync),
    );
  }
}

/// Primeira conexão com dados nos dois lados: juntar (recomendado), usar só
/// os do Dropbox ou só os deste aparelho. Devolve a escolha (`null`:
/// cancelou).
class FirstSyncDialog extends StatefulWidget {
  const FirstSyncDialog({required this.choice, super.key});

  final FirstSyncChoice choice;

  @override
  State<FirstSyncDialog> createState() => _FirstSyncDialogState();
}

class _FirstSyncDialogState extends State<FirstSyncDialog> {
  FirstSync _mode = FirstSync.merge;

  @override
  Widget build(BuildContext context) {
    String side(DataFileSummary s) {
      String plural(int n, String one, String many) =>
          '$n ${n == 1 ? one : many}';
      return '${plural(s.dexes, 'dex', 'dexes')} · '
          '${plural(s.specimens, 'espécime', 'espécimes')}\n'
          '${DateFormat('dd/MM/yyyy HH:mm').format(s.savedAt)}';
    }

    return AlertDialog(
      title: const Text('Já há dados no Dropbox'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Side(
                    title: 'No Dropbox',
                    text: side(widget.choice.remote),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Side(
                    title: 'Neste aparelho',
                    text: side(widget.choice.local),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            RadioGroup<FirstSync>(
              groupValue: _mode,
              onChanged: (mode) => setState(() => _mode = mode!),
              child: const Column(
                children: [
                  RadioListTile(
                    value: FirstSync.merge,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Juntar os dois (recomendado)'),
                    subtitle: Text(
                      'Nada se perde. Se o mesmo registro mudou nos dois, '
                      'vale a mudança mais recente.',
                    ),
                  ),
                  RadioListTile(
                    value: FirstSync.useRemote,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Usar só os do Dropbox'),
                    subtitle: Text('Os dados deste aparelho são substituídos.'),
                  ),
                  RadioListTile(
                    value: FirstSync.useLocal,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Usar só os deste aparelho'),
                    subtitle: Text('O que está no Dropbox é substituído.'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _mode),
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.labelLarge),
            const SizedBox(height: 2),
            Text(text, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
