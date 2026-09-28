import 'package:flutter/material.dart';
import 'package:ishinydex/core/utils/format.dart';

/// Barra de progresso com o texto "registrados/total (xx%)".
class ProgressBadge extends StatelessWidget {
  const ProgressBadge({
    required this.registered,
    required this.total,
    super.key,
  });

  final int registered;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final complete = total > 0 && registered >= total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : registered / total,
            minHeight: 6,
            color: complete ? Colors.green : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$registered/$total (${percentOf(registered, total)}%)',
          style: theme.textTheme.labelMedium,
        ),
      ],
    );
  }
}
