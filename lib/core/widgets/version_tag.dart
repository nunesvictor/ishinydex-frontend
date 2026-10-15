import 'package:flutter/material.dart';
import 'package:ishinydex/core/theme/version_colors.dart';

/// Etiqueta pequena ligada a um jogo ("exclusivo Scarlet", "Seu: Violet"),
/// com a cor da [version] (#203). Sem versão (ou sem cor de marca), fica
/// nas cores neutras do tema.
class VersionTag extends StatelessWidget {
  const VersionTag(this.text, {this.version, super.key});

  final String text;
  final String? version;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final neutral = (
      background: theme.colorScheme.surfaceContainerHighest,
      foreground: theme.colorScheme.onSurfaceVariant,
    );
    final version = this.version;
    final tone = version == null
        ? neutral
        : versionToneOf(context, version, neutral: neutral);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(color: tone.foreground),
        ),
      ),
    );
  }
}
