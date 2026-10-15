import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/web/share_outcome.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/hunt_share_card.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// O que o card mostra do [specimen], com o método no idioma da tela e o
/// OT; `null` se ele não tiver o que compartilhar (ver [HuntShareData.of]).
HuntShareData? huntShareDataOf(
  BuildContext context,
  WidgetRef ref,
  Specimen specimen,
) {
  final method = ref
      .watch(shinyMethodsProvider)(null)
      .where((m) => m.id == specimen.hunt?.method)
      .firstOrNull;
  final ot = ref
      .watch(trainersProvider)
      .value
      ?.where((t) => t.id == specimen.ot)
      .firstOrNull;
  return HuntShareData.of(
    specimen,
    method: method == null
        ? null
        : context.catalogText(method.label, method.labels),
    ot: ot,
  );
}

/// Abre a folha do card da caçada (#243). [found]: logo depois do
/// "Encontrei!" ("Shiny registrado!", com "Agora não").
Future<void> showHuntShareSheet(
  BuildContext context,
  Specimen specimen, {
  bool found = false,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (_) => HuntShareSheet(specimen: specimen, found: found),
);

/// A folha com a prévia do card, a chave do ID do treinador e o botão
/// "Compartilhar".
///
/// O PNG é gerado assim que a folha abre (e de novo se os dados ou a chave
/// mudarem), e não no toque: o Safari do iOS só abre a folha de
/// compartilhar se a chamada vier logo depois do toque, sem nada
/// assíncrono antes (provado no iPhone na v2.12.0-beta.1). O botão fica
/// desligado enquanto a imagem não está pronta.
class HuntShareSheet extends ConsumerStatefulWidget {
  const HuntShareSheet({required this.specimen, this.found = false, super.key});

  final Specimen specimen;
  final bool found;

  @override
  ConsumerState<HuntShareSheet> createState() => _HuntShareSheetState();
}

class _HuntShareSheetState extends ConsumerState<HuntShareSheet> {
  final GlobalKey _boundary = GlobalKey();
  bool _showTrainerId = false;

  /// A imagem pronta e de quê ela é (os dados e a chave do ID).
  Uint8List? _png;
  Object? _captured;
  Object? _capturing;
  bool _failed = false;

  /// Gera a imagem de [key] depois deste quadro, se ainda não for a dela.
  void _scheduleCapture(Object key, String? spriteUrl) {
    if (key == _captured || key == _capturing) return;
    _capturing = key;
    _failed = false;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_capture(key, spriteUrl)),
    );
  }

  Future<void> _capture(Object key, String? spriteUrl) async {
    try {
      // O sprite precisa ter chegado, senão sai o ícone de reserva.
      if (spriteUrl != null) {
        await precacheImage(
          NetworkImage(
            spriteUrl,
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
          ),
          context,
          onError: (_, _) {},
        );
      }
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || key != _capturing) return;
      final boundary =
          _boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final png = await ref.read(pngCapturerProvider)(
        boundary,
        HuntShareCard.pixelRatio,
      );
      if (!mounted || key != _capturing) return;
      setState(() {
        _png = png;
        _captured = key;
        _failed = false;
      });
    } on Object {
      if (mounted && key == _capturing) setState(() => _failed = true);
    }
  }

  /// Compartilha na hora do toque: o PNG já está pronto.
  Future<void> _share(Uint8List png, String name) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final outcome = await ref.read(fileSharerProvider)(
      png,
      name: 'ishinydex-${name.toLowerCase()}.png',
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
    final l10n = context.l10n;
    final data = huntShareDataOf(context, ref, widget.specimen);
    if (data == null) return const SizedBox.shrink();
    final key = (data, _showTrainerId);
    _scheduleCapture(key, data.spriteUrl);
    final png = key == _captured ? _png : null;
    final preparing = png == null && !_failed;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          if (widget.found) ...[
            Text(
              l10n.shareFoundTitle,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            Text(l10n.shareFoundText(data.name), textAlign: TextAlign.center),
          ] else
            Text(l10n.shareHuntTitle, style: theme.textTheme.titleLarge),
          // A prévia encolhe para caber; a imagem sai do tamanho cheio.
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: HuntShareCard.size.width,
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: FittedBox(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: RepaintBoundary(
                    key: _boundary,
                    child: HuntShareCard(
                      data: data,
                      showTrainerId: _showTrainerId,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // A única opção do card (v3): o ID fica de fora por padrão.
          if (data.trainerId != null)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.shareShowTrainerId),
              value: _showTrainerId,
              onChanged: (on) => setState(() => _showTrainerId = on),
            ),
          if (_failed)
            Text(
              l10n.shareFailed,
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          Row(
            spacing: 12,
            children: [
              if (widget.found)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.shareNotNow),
                  ),
                ),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('share-hunt'),
                  onPressed: png == null
                      ? null
                      : () => unawaited(_share(png, data.name)),
                  icon: preparing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.ios_share),
                  label: Text(preparing ? l10n.sharePreparing : l10n.shareHunt),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
