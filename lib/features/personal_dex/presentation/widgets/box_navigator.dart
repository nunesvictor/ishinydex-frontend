import 'package:flutter/material.dart';
import 'package:ishinydex/core/utils/format.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';

/// Cabeçalho "‹ HOME 1 · 28/30 ›" com menu para saltar entre boxes.
class BoxNavigator extends StatelessWidget {
  const BoxNavigator({
    required this.boxes,
    required this.index,
    required this.onChanged,
    super.key,
  });

  final List<BoxSummary> boxes;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final box = boxes[index];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Box anterior',
          onPressed: index > 0 ? () => onChanged(index - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Flexible(
          child: PopupMenuButton<int>(
            tooltip: 'Escolher box',
            initialValue: index,
            onSelected: onChanged,
            itemBuilder: (context) => [
              for (final (i, b) in boxes.indexed)
                PopupMenuItem(
                  value: i,
                  child: Text(
                    '${b.name} · ${b.registered}/${b.total}${awaySuffix(b.away)}',
                  ),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Text(
                '${box.name} · ${box.registered}/${box.total}'
                '${awaySuffix(box.away)}',
                style: Theme.of(context).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Próxima box',
          onPressed: index < boxes.length - 1
              ? () => onChanged(index + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
