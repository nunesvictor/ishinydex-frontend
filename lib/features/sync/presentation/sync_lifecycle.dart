import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/features/sync/sync_providers.dart';

/// Liga o sync à vida do app: ao abrir (que também conclui um login que
/// voltou do Dropbox) e ao voltar para o app depois de usar outro (no
/// iPhone, o app da Tela de Início fica em segundo plano, sem reabrir).
class SyncLifecycle extends ConsumerStatefulWidget {
  const SyncLifecycle({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SyncLifecycle> createState() => _SyncLifecycleState();
}

class _SyncLifecycleState extends ConsumerState<SyncLifecycle> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    final controller = ref.read(syncControllerProvider.notifier);
    unawaited(Future.microtask(controller.start));
    _listener = AppLifecycleListener(
      onResume: () => unawaited(controller.sync()),
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
