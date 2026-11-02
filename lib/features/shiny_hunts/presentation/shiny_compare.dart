import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/responsive/breakpoints.dart';
import 'package:ishinydex/core/widgets/mark_icons.dart';
import 'package:ishinydex/core/widgets/pokemon_sprite.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/domain/sprite_diff.dart';
import 'package:ishinydex/features/shiny_hunts/shiny_hunt_providers.dart';

/// Compara o shiny com o normal da [form] (#381): uma folha no compacto e
/// um diálogo nos demais.
Future<void> showShinyCompare(BuildContext context, FormRef form) {
  final content = ShinyCompare(form: form);
  if (WindowSize.of(context).isCompact) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => content,
    );
  }
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: content,
      ),
    ),
  );
}

/// O sprite shiny que abre a comparação: a marca de "comparar" no canto
/// avisa que dá para tocar.
class ShinyCompareButton extends StatelessWidget {
  const ShinyCompareButton({required this.form, this.size = 48, super.key});

  final FormRef? form;
  final double size;

  @override
  Widget build(BuildContext context) {
    final form = this.form;
    final sprite = PokemonSprite(url: form?.spriteFor(shiny: true), size: size);
    if (form == null) return sprite;
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: context.l10n.compareButton(form.displayName),
      child: InkWell(
        key: ValueKey('compare-${form.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => showShinyCompare(context, form),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(padding: const EdgeInsets.all(4), child: sprite),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 2),
                ),
                child: Icon(Icons.compare, size: 12, color: scheme.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Mode { hold, diff }

class ShinyCompare extends ConsumerStatefulWidget {
  const ShinyCompare({required this.form, super.key});

  final FormRef form;

  @override
  ConsumerState<ShinyCompare> createState() => _ShinyCompareState();
}

class _ShinyCompareState extends ConsumerState<ShinyCompare> {
  _Mode _mode = _Mode.hold;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final compact = WindowSize.of(context).isCompact;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, compact ? 0 : 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      widget.form.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge,
                    ),
                    Text(
                      l10n.compareSubtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const CloseButton(),
            ],
          ),
          SegmentedButton<_Mode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: _Mode.hold,
                label: Text(
                  l10n.compareModeHold,
                  key: const ValueKey('compare-hold-mode'),
                ),
              ),
              ButtonSegment(
                value: _Mode.diff,
                label: Text(
                  l10n.compareModeDiff,
                  key: const ValueKey('compare-diff-mode'),
                ),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (picked) =>
                setState(() => _mode = picked.single),
          ),
          if (_mode == _Mode.hold)
            _Hold(form: widget.form, compact: compact)
          else
            _Diff(form: widget.form, compact: compact),
          Text(
            l10n.compareFoot,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A etiqueta no canto do quadro grande ("Shiny ✦", "Normal", "Muda").
class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color, this.leading});

  final String label;
  final Color color;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          ?leading,
          Text(label, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    ),
  );
}

/// Lado a lado e, embaixo, o shiny grande: segurar o dedo (ou o mouse)
/// troca pelo normal no mesmo lugar; soltar volta.
class _Hold extends StatefulWidget {
  const _Hold({required this.form, required this.compact});

  final FormRef form;
  final bool compact;

  @override
  State<_Hold> createState() => _HoldState();
}

class _HoldState extends State<_Hold> {
  bool _holding = false;

  void _set(bool holding) => setState(() => _holding = holding);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final form = widget.form;
    final side = widget.compact ? 150.0 : 240.0;
    Widget card(String label, String url, {Widget? icon}) => DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 12),
        child: Column(
          spacing: 6,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 4,
              children: [
                Text(label, style: theme.textTheme.titleSmall),
                ?icon,
              ],
            ),
            PokemonSprite(url: url, size: side),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        Row(
          spacing: 12,
          children: [
            Expanded(child: card(l10n.compareNormal, form.spriteUrl)),
            Expanded(
              child: card(
                l10n.compareShiny,
                form.shinySpriteUrl,
                icon: const ShinyIcon(size: 14),
              ),
            ),
          ],
        ),
        // Listener, e não GestureDetector: o dedo apertado conta na hora,
        // sem esperar o "toque longo".
        Semantics(
          button: true,
          label: l10n.compareHold,
          child: Listener(
            key: const ValueKey('compare-hold'),
            onPointerDown: (_) => _set(true),
            onPointerUp: (_) => _set(false),
            onPointerCancel: (_) => _set(false),
            child: Container(
              height: widget.compact ? 268 : 236,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
                border: _holding
                    ? Border.all(color: scheme.primary, width: 2)
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PokemonSprite(
                    url: _holding ? form.spriteUrl : form.shinySpriteUrl,
                    size: widget.compact ? 220 : 200,
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: _holding
                        ? _Tag(
                            label: l10n.compareNormal,
                            color: scheme.surfaceContainerLow,
                          )
                        : _Tag(
                            label: l10n.compareShiny,
                            color: scheme.tertiaryContainer,
                            leading: const ShinyIcon(size: 12),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 8,
          children: [
            const Icon(Icons.touch_app, size: 18),
            Text(
              _holding ? l10n.compareRelease : l10n.compareHold,
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
      ],
    );
  }
}

/// O mapa da diferença e as cores principais, normal → shiny.
class _Diff extends ConsumerWidget {
  const _Diff({required this.form, required this.compact});

  final FormRef form;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return switch (ref.watch(spriteDiffProvider(form))) {
      AsyncData(value: final diff) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Container(
            height: compact ? 268 : 236,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.square(
                  dimension: compact ? 220 : 200,
                  child: PixelsImage(diff.map),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: _Tag(
                    label: l10n.compareChanges,
                    color: scheme.surface,
                    leading: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFF000000 | SpriteDiff.highlight),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(switch ((diff.changedShare * 100).round()) {
            final percent when percent < 10 => l10n.compareSummaryFew(percent),
            final percent => l10n.compareSummary(percent),
          }, style: theme.textTheme.bodyMedium),
          Text(l10n.compareColors, style: theme.textTheme.titleSmall),
          for (final shift in diff.colors)
            Row(
              spacing: 10,
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    '${(shift.share * 100).round()}%',
                    textAlign: TextAlign.end,
                    style: muted?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                _Swatch(shift.from),
                Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                _Swatch(shift.to),
                if (SpriteDiff.isAlmostSame(shift))
                  Text(l10n.compareAlmostSame, style: muted),
              ],
            ),
        ],
      ),
      AsyncError() => Column(
        spacing: 8,
        children: [
          Text(l10n.compareFailed, textAlign: TextAlign.center),
          TextButton(
            onPressed: () => ref.invalidate(spriteDiffProvider(form)),
            child: Text(l10n.tryAgain),
          ),
        ],
      ),
      _ => const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
    };
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.rgb);

  final int rgb;

  @override
  Widget build(BuildContext context) {
    final hex = '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
    return Tooltip(
      message: hex,
      child: Container(
        width: 44,
        height: 28,
        decoration: BoxDecoration(
          color: Color(0xFF000000 | rgb),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

/// Mostra [pixels] (RGBA) como imagem.
class PixelsImage extends StatefulWidget {
  const PixelsImage(this.pixels, {super.key});

  final SpritePixels pixels;

  @override
  State<PixelsImage> createState() => _PixelsImageState();
}

class _PixelsImageState extends State<PixelsImage> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    final pixels = widget.pixels;
    ui.decodeImageFromPixels(
      pixels.rgba,
      pixels.width,
      pixels.height,
      ui.PixelFormat.rgba8888,
      (image) {
        if (mounted) {
          setState(() => _image = image);
        } else {
          image.dispose();
        }
      },
    );
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RawImage(image: _image, fit: BoxFit.contain);
}
