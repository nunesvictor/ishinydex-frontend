import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/web/share_outcome.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/hunt_share_card.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// Abre a folha "Compartilhar a caçada" (#243) com a prévia do card.
Future<void> showHuntShareSheet(BuildContext context, HuntShareData data) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => HuntShareSheet(data: data),
    );

/// A folha com a prévia do card e o botão "Compartilhar".
///
/// O PNG é gerado assim que a folha abre, e não no toque: o Safari do iOS só
/// abre a folha de compartilhar se a chamada vier logo depois do toque, sem
/// nada assíncrono antes. O botão fica desligado até a imagem ficar pronta.
class HuntShareSheet extends ConsumerStatefulWidget {
  const HuntShareSheet({required this.data, super.key});

  final HuntShareData data;

  @override
  ConsumerState<HuntShareSheet> createState() => _HuntShareSheetState();
}

class _HuntShareSheetState extends ConsumerState<HuntShareSheet> {
  final GlobalKey _boundary = GlobalKey();
  Uint8List? _png;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_capture()));
  }

  Future<void> _capture() async {
    try {
      // O sprite precisa ter chegado, senão sai o ícone de reserva.
      if (widget.data.spriteUrl case final url?) {
        await precacheImage(
          NetworkImage(
            url,
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
          ),
          context,
          onError: (_, _) {},
        );
      }
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final boundary =
          _boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final png = await ref.read(pngCapturerProvider)(
        boundary,
        HuntShareCard.pixelRatio,
      );
      if (mounted) setState(() => _png = png);
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// Compartilha na hora do toque: o PNG já está pronto.
  Future<void> _share(Uint8List png) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final outcome = await ref.read(fileSharerProvider)(
      png,
      name: 'ishinydex-${widget.data.name.toLowerCase()}.png',
      type: 'image/png',
    );
    if (!outcome.silent) {
      final message = switch (outcome) {
        ShareOutcome.downloaded => l10n.shareDownloaded,
        ShareOutcome.notAllowed => l10n.shareNotAllowed,
        _ => l10n.shareFailed,
      };
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
    if (outcome == ShareOutcome.shared && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final png = _png;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Text(context.l10n.shareHuntTitle, style: theme.textTheme.titleLarge),
          // A prévia encolhe para caber; a imagem sai do tamanho cheio.
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: HuntShareCard.size.width,
                maxHeight: MediaQuery.sizeOf(context).height * 0.55,
              ),
              child: FittedBox(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: RepaintBoundary(
                    key: _boundary,
                    child: HuntShareCard(data: widget.data),
                  ),
                ),
              ),
            ),
          ),
          if (_failed)
            Text(
              context.l10n.shareFailed,
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          FilledButton.icon(
            key: const ValueKey('share-hunt'),
            onPressed: png == null ? null : () => unawaited(_share(png)),
            icon: png == null && !_failed
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share),
            label: Text(
              png == null && !_failed
                  ? context.l10n.sharePreparing
                  : context.l10n.shareHunt,
            ),
          ),
        ],
      ),
    );
  }
}
