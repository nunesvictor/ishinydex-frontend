import 'package:flutter/material.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';

/// Lista lateral de boxes (layout expandido).
class BoxListPanel extends StatelessWidget {
  const BoxListPanel({
    required this.boxes,
    required this.index,
    required this.onSelected,
    super.key,
  });

  final List<BoxSummary> boxes;
  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => ListView.builder(
    itemCount: boxes.length,
    itemBuilder: (context, i) {
      final box = boxes[i];
      return ListTile(
        selected: i == index,
        title: Text(box.name),
        subtitle: Text('${box.registered}/${box.total}'),
        trailing: box.isComplete
            ? const Icon(Icons.check_circle, color: Colors.green)
            : null,
        onTap: () => onSelected(i),
      );
    },
  );
}
