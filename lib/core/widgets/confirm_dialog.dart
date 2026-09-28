import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Diálogo de confirmação adaptativo (Cupertino no iOS/macOS).
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  bool destructive = false,
}) async {
  final result = await showAdaptiveDialog<bool>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
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
  return TextButton(onPressed: onPressed, child: child);
}
