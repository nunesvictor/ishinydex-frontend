import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/web/browser.dart' as browser;

/// Versões novas do app com ele aberto (#228): avisa quando a nova está
/// pronta e recarrega a página. No navegador, vem do `index.html` e do
/// service worker; nos testes, é trocado.
abstract interface class AppUpdates {
  void onReady(VoidCallback callback);
  void reload();
}

class BrowserAppUpdates implements AppUpdates {
  const BrowserAppUpdates();

  @override
  void onReady(VoidCallback callback) => browser.onAppUpdateReady(callback);

  @override
  void reload() => browser.reloadPage();
}

final appUpdatesProvider = Provider<AppUpdates>(
  (ref) => const BrowserAppUpdates(),
);

/// Mostra "Nova versão disponível" com "Recarregar" quando o app recebe uma
/// versão nova aberto. O aviso fica até a pessoa recarregar ou dispensar:
/// a versão nova só roda depois de recarregar.
class UpdateNotice extends ConsumerStatefulWidget {
  const UpdateNotice({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<UpdateNotice> createState() => _UpdateNoticeState();
}

class _UpdateNoticeState extends ConsumerState<UpdateNotice> {
  @override
  void initState() {
    super.initState();
    final updates = ref.read(appUpdatesProvider);
    updates.onReady(() {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.updateAvailable),
          // Até a pessoa decidir: a versão nova só roda ao recarregar.
          duration: const Duration(days: 1),
          showCloseIcon: true,
          action: SnackBarAction(
            label: context.l10n.reload,
            onPressed: updates.reload,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
