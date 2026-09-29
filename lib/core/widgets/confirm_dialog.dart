import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Diálogo de confirmação adaptativo (Cupertino no iOS/macOS).
///
/// [destructive] pinta a confirmação com a cor de erro; [icon] aparece
/// acima do título (ex.: alerta em ações que não podem ser desfeitas).
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  bool destructive = false,
  IconData? icon,
}) async {
  final result = await showAdaptiveDialog<bool>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      icon: icon == null
          ? null
          : Icon(
              icon,
              color: destructive ? Theme.of(context).colorScheme.error : null,
            ),
      title: Text(title),
      content: Text(message),
      actions: [
        adaptiveAction(
          context: context,
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        adaptiveAction(
          context: context,
          onPressed: () => Navigator.of(context).pop(true),
          isDestructive: destructive,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

Widget adaptiveAction({
  required BuildContext context,
  required VoidCallback onPressed,
  required Widget child,
  bool isDestructive = false,
}) {
  final platform = Theme.of(context).platform;
  if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
    return CupertinoDialogAction(
      onPressed: onPressed,
      isDestructiveAction: isDestructive,
      child: child,
    );
  }
  return TextButton(
    onPressed: onPressed,
    style: isDestructive
        ? TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          )
        : null,
    child: child,
  );
}
