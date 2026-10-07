import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/features/sync/sync_providers.dart';

/// Liga o sync à vida do app: ao abrir (que também conclui um login que
/// voltou do Dropbox) e ao voltar para o app depois de usar outro (no
/// iPhone, o app da Tela de Início fica em segundo plano, sem reabrir).
/// Quando um sync traz mudanças de outro aparelho, avisa com um SnackBar
/// curto (a tela já se atualizou sozinha).
class SyncLifecycle extends ConsumerStatefulWidget {
  const SyncLifecycle({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SyncLifecycle> createState() => _SyncLifecycleState();
}

class _SyncLifecycleState extends ConsumerState<SyncLifecycle> {
  static const pulledMessage = 'Atualizado com as mudanças de outro aparelho.';

  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    final controller = ref.read(syncControllerProvider.notifier);
    unawaited(Future.microtask(controller.start));
    _listener = AppLifecycleListener(
      onResume: () => unawaited(controller.sync()),
    );
    ref.listenManual(syncControllerProvider.select((s) => s.pulls), (
      before,
      after,
    ) {
      if (after > (before ?? 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(pulledMessage),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
