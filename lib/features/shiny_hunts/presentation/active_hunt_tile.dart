import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/features/personal_dex/presentation/widgets/slot_tile.dart';
import 'package:ishinydex/features/shiny_hunts/domain/models.dart';
import 'package:ishinydex/features/shiny_hunts/shiny_hunt_providers.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

/// "Caçada em andamento" no painel do slot (#183): jogo, método e contagem
/// da caçada ativa da forma [formId], com o selo da grade. Tocar leva às
/// caçadas ([onTap]). Sem caçada ativa da forma, não ocupa espaço.
class ActiveHuntTile extends ConsumerWidget {
  const ActiveHuntTile({required this.formId, this.onTap, super.key});

  final int formId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hunt = (ref.watch(shinyHuntsProvider).value ?? const <ShinyHunt>[])
        .where((h) => !h.paused && h.form == formId)
        .firstOrNull;
    if (hunt == null) return const SizedBox.shrink();
    final save = (ref.watch(savesProvider).value ?? const <Save>[])
        .where((s) => s.id == hunt.save)
        .firstOrNull;
    final method = ref
        .watch(shinyMethodsProvider)(null)
        .where((m) => m.id == hunt.method)
        .firstOrNull;
    final count = hunt.timed
        ? timerLabel(hunt.elapsed(ref.read(shinyHuntActionsProvider).now()))
        : '${huntCountLabel(hunt.count, null)} '
              '${huntUnitLabels[hunt.unit] ?? hunt.unit}';
    return ListTile(
      key: const ValueKey('active-hunt-tile'),
      contentPadding: EdgeInsets.zero,
      leading: const HuntBadge(size: 28),
      title: const Text('Caçada em andamento'),
      subtitle: Text([?save?.game, ?method?.label, count].join(' · ')),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
