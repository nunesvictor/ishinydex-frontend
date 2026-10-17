import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/utils/origin_mark.dart';
import 'package:ishinydex/core/widgets/chip_icons.dart';
import 'package:ishinydex/core/widgets/game_icon.dart';
import 'package:ishinydex/core/widgets/more_actions.dart';
import 'package:ishinydex/core/widgets/origin_mark_chip.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/domain/transfer_rules.dart';
import 'package:ishinydex/features/specimens/presentation/specimen_labels.dart';
import 'package:ishinydex/features/specimens/presentation/widgets/form_picker.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';

// Enviar espécimes para um save e trazê-los de volta ao HOME.
//
// As funções daqui são usadas pelo painel do slot, pelo detalhe do
// espécime, pela seleção do inventário e pela tela "Fora do HOME": todas
// terminam com `specimensChanged()`, que recarrega slots, contagens e
// inventário, e uma mensagem.

/// Ícone do save: a marca de origem do jogo, ou um avião se a versão não
/// tiver marca.
class SaveIcon extends StatelessWidget {
  const SaveIcon(this.save, {this.size = 20, super.key});

  final Save save;
  final double size;

  @override
  Widget build(BuildContext context) =>
      switch (OriginMark.fromVersion(save.trainer.version)) {
        final mark? => OriginMarkIcon(mark, size: size),
        null => Icon(Icons.flight_takeoff, size: size),
      };
}

/// "Em Scarlet · Switch" / "desde 12/03/2026 · há 203 dias": onde o
/// espécime está quando não está no HOME.
class LocationTile extends StatelessWidget {
  const LocationTile({required this.save, this.since, super.key});

  final Save save;
  final DateTime? since;

  @override
  Widget build(BuildContext context) {
    final date = since;
    return ListTile(
      key: const ValueKey('location-tile'),
      contentPadding: EdgeInsets.zero,
      leading: SaveIcon(save, size: 28),
      title: Text(context.l10n.awayIn(save.title)),
      subtitle: date == null
          ? Text(context.l10n.awayFromHome)
          : Text(
              context.l10n.sinceWhen(
                MaterialLocalizations.of(context).formatCompactDate(date),
                context.l10n.awayFor(date),
              ),
            ),
    );
  }
}

void _notify(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

/// Escolhe o save de destino dos [ids], com a checagem de quem pode ir
/// ([TransferCheck]). Os saves só de ida ([Save.isOneWay]) não são destino:
/// ficam de fora, com uma nota no pé. Sem nenhum save que receba, explica e
/// oferece abrir Ajustes → Meus saves. `null` = desistiu. Um save em que nenhum dos
/// espécimes pode entrar fica desabilitado; os outros dizem quantos ficam,
/// os avisos e quantos estão fora da pokédex do jogo.
Future<({Save save, TransferCheck check})?> pickSave(
  BuildContext context,
  WidgetRef ref,
  List<int> ids,
) async {
  final List<Save> all;
  try {
    all = await ref.read(savesProvider.future);
  } on AppFailure catch (failure) {
    if (context.mounted) _notify(context, context.failureText(failure));
    return null;
  }
  if (!context.mounted) return null;
  final saves = [
    for (final s in all)
      if (!s.isOneWay) s,
  ];
  final oneWay = [
    for (final s in all)
      if (s.isOneWay) s.game,
  ];
  if (saves.isEmpty) {
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          oneWay.isEmpty
              ? context.l10n.noSavesYet
              : context.l10n.noReceivingSave,
        ),
        content: Text(context.l10n.addSavesHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.notNow),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.openMySaves),
          ),
        ],
      ),
    );
    if ((open ?? false) && context.mounted) context.go(Routes.saves);
    return null;
  }
  return await showModalBottomSheet<({Save save, TransferCheck check})>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              context.l10n.sendToWhichSave,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final save in saves) _saveOption(context, ref, save, ids),
          if (oneWay.isNotEmpty) _oneWayNote(context, oneWay),
        ],
      ),
    ),
  );
}

/// O pé da escolha do destino: por que os saves só de ida não aparecem.
Widget _oneWayNote(BuildContext context, List<String> games) {
  final theme = Theme.of(context);
  final names = {...games}.toList();
  final list = joinLabels(context.l10n, names);
  return Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Icon(
          Icons.info_outline,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        Expanded(
          child: Text(
            context.l10n.oneWayNotListed(names.length, list),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _saveOption(
  BuildContext context,
  WidgetRef ref,
  Save save,
  List<int> ids,
) {
  final check = ref.read(transferCheckProvider)(ids, save);
  final warning = _saveWarning(context.l10n, save, ids.length, check);
  return ListTile(
    enabled: check.allowed,
    leading: SaveIcon(save),
    title: Text(save.title),
    subtitle: warning == null
        ? Text(save.trainer.label)
        : Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${save.trainer.label}\n'),
                if (check.allowed)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Icon(
                      Icons.warning_amber,
                      size: 16,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                TextSpan(text: check.allowed ? ' $warning' : warning),
              ],
            ),
          ),
    isThreeLine: warning != null,
    onTap: () => Navigator.of(context).pop((save: save, check: check)),
  );
}

/// O texto embaixo do save: com um espécime, o motivo ou o aviso dele; com
/// vários, as contagens (quantos ficam, quantos têm aviso, quantos estão
/// fora da pokédex). `null` = nada a dizer.
String? _saveWarning(
  AppLocalizations l10n,
  Save save,
  int total,
  TransferCheck check,
) {
  if (total == 1) {
    if (check.blocked.isNotEmpty) {
      return l10n.problem(check.blocked.first.problem);
    }
    if (check.warnings.isNotEmpty) {
      return l10n.problem(check.warnings.first.problem);
    }
    return check.outside > 0 ? l10n.outsideGamePokedex(save.game) : null;
  }
  if (!check.allowed) {
    final reasons = {for (final b in check.blocked) l10n.problem(b.problem)};
    return reasons.length == 1 ? reasons.first : l10n.noneCanGo;
  }
  final parts = [
    if (check.blocked.isNotEmpty) l10n.cannotGoCount(check.blocked.length),
    if (check.warnings.isNotEmpty) l10n.withWarningCount(check.warnings.length),
    if (check.outside > 0)
      l10n.outsideGamePokedexCount(check.outside, save.game),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Quando parte dos espécimes não pode ir: confirma o envio só dos outros,
/// listando quem fica no HOME (e por quê) e os avisos.
Future<bool> _confirmPartial(
  BuildContext context,
  Save save,
  int total,
  TransferCheck check,
) async {
  final going = check.movable.length;
  final theme = Theme.of(context);
  Widget issue(TransferIssue i) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text('${i.name}: ${context.l10n.problem(i.problem)}'),
  );
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.sendSomeQuestion(going, total, save.title)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.stayInHome, style: theme.textTheme.titleSmall),
            ...check.blocked.map(issue),
            if (check.warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                context.l10n.goWithWarning,
                style: theme.textTheme.titleSmall,
              ),
              ...check.warnings.map(issue),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(context.l10n.sendCount(going)),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Envia os [ids] para um save escolhido: só os que podem ir, confirmando
/// antes quando algum fica. Devolve `true` se enviou.
Future<bool> sendToGame(
  BuildContext context,
  WidgetRef ref,
  List<int> ids,
) async {
  final picked = await pickSave(context, ref, ids);
  if (picked == null || !context.mounted) return false;
  final (:save, :check) = picked;
  if (check.blocked.isNotEmpty &&
      !await _confirmPartial(context, save, ids.length, check)) {
    return false;
  }
  if (!context.mounted) return false;
  try {
    final moved = await ref
        .read(specimenRepositoryProvider)
        .transfer(check.movable, saveId: save.id);
    ref.read(slotActionsProvider).specimensChanged();
    if (context.mounted) {
      _notify(context, context.l10n.specimensSent(moved, save.title));
    }
    return true;
  } on AppFailure catch (failure) {
    if (context.mounted) _notify(context, context.failureText(failure));
    return false;
  }
}

/// Traz os [ids] de volta ao HOME, sem perguntar sobre evolução (o lote).
/// Devolve `true` se trouxe.
Future<bool> bringBackMany(
  BuildContext context,
  WidgetRef ref,
  List<int> ids,
) async {
  try {
    final moved = await ref
        .read(specimenRepositoryProvider)
        .transfer(ids, saveId: null);
    ref.read(slotActionsProvider).specimensChanged();
    if (context.mounted) {
      _notify(context, context.l10n.specimensBack(moved));
    }
    return true;
  } on AppFailure catch (failure) {
    if (context.mounted) _notify(context, context.failureText(failure));
    return false;
  }
}

enum _Return { same, evolved }

/// Traz um espécime de volta, perguntando se ele voltou igual ou evoluiu.
/// Se evoluiu, escolhe a forma nova: o espécime vira essa forma e sai do
/// slot antigo (que volta a faltar), ficando disponível no inventário.
Future<void> bringBack(
  BuildContext context,
  WidgetRef ref, {
  required int specimenId,
  required String name,
}) async {
  final answer = await showDialog<_Return>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.backToHomeTitle(name)),
      content: Text(context.l10n.backToHomeQuestion),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_Return.evolved),
          child: Text(context.l10n.evolvedAction),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_Return.same),
          child: Text(context.l10n.cameBackSame),
        ),
      ],
    ),
  );
  if (answer == null || !context.mounted) return;
  if (answer == _Return.same) {
    await bringBackMany(context, ref, [specimenId]);
    return;
  }
  final form = await showFormPicker(context);
  if (form == null || !context.mounted) return;
  final repository = ref.read(specimenRepositoryProvider);
  try {
    // Evoluir primeiro: se a forma não servir, nada muda.
    await repository.evolve(specimenId, formId: form.id);
    await repository.transfer([specimenId], saveId: null);
    ref.read(slotActionsProvider).specimensChanged();
    if (context.mounted) {
      _notify(context, context.l10n.evolvedAndBack(form.displayName));
    }
  } on AppFailure catch (failure) {
    ref.read(slotActionsProvider).specimensChanged();
    if (context.mounted) _notify(context, context.failureText(failure));
  }
}

/// O ícone colorido do Pokémon Champions (o do HOME).
class ChampionsIcon extends StatelessWidget {
  const ChampionsIcon({this.size = 24, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => GameIcon('champions', size: size);
}

/// "Visitando o Champions · desde 09/10/2026": o Pokémon continua no HOME.
class ChampionsTile extends StatelessWidget {
  const ChampionsTile({required this.since, super.key});

  final DateTime since;

  @override
  Widget build(BuildContext context) => ListTile(
    key: const ValueKey('champions-tile'),
    contentPadding: EdgeInsets.zero,
    leading: const ChampionsIcon(size: 28),
    title: Text(context.l10n.inHomeVisitingChampions),
    subtitle: Text(
      context.l10n.sinceWhen(
        MaterialLocalizations.of(context).formatCompactDate(since),
        context.l10n.awayFor(since),
      ),
    ),
  );
}

/// Ações de localização para o menu "Mais ações" (detalhe do espécime e
/// painel do slot): fora do HOME, "Trazer de volta"; visitando o Champions
/// (#174), "Voltou do Champions" e o envio desabilitado; no HOME, "Enviar
/// para jogo…" e "Visitar o Champions".
List<MoreAction> locationActions(
  BuildContext context,
  WidgetRef ref, {
  required int id,
  required String name,
  required bool away,
  required bool visiting,
  Save? location,
}) {
  if (away) {
    // Depois do corte do HOME (#222), o jogo não envia mais: fica no save.
    final stuck =
        ref.read(homeCutoffProvider)(location?.trainer.version)?.passed ??
        false;
    return [
      MoreAction(
        icon: Icons.flight_land,
        label: context.l10n.bringBackToHome,
        subtitle: stuck ? context.l10n.gameNoLongerSends(location!.game) : null,
        enabled: !stuck,
        onSelected: () => bringBack(context, ref, specimenId: id, name: name),
      ),
    ];
  }
  return [
    if (visiting)
      MoreAction(
        icon: Icons.emoji_events,
        leading: const ChampionsIcon(),
        label: context.l10n.backFromChampions,
        subtitle: context.l10n.backFromChampionsHint,
        onSelected: () => _champions(context, ref, id, visiting: false),
      ),
    MoreAction(
      icon: Icons.flight_takeoff,
      label: context.l10n.sendToGame,
      subtitle: visiting ? context.l10n.problemVisitingChampions : null,
      enabled: !visiting,
      onSelected: () => sendToGame(context, ref, [id]),
    ),
    if (!visiting)
      MoreAction(
        icon: Icons.emoji_events,
        leading: const ChampionsIcon(),
        label: context.l10n.visitChampions,
        subtitle: context.l10n.visitChampionsHint,
        onSelected: () => _champions(context, ref, id, visiting: true),
      ),
  ];
}

/// Libertar, desabilitado enquanto visita o Champions.
MoreAction releaseAction(
  AppLocalizations l10n, {
  required bool visiting,
  required VoidCallback onSelected,
}) => MoreAction(
  icon: Icons.warning_amber_rounded,
  label: l10n.releaseAction,
  subtitle: visiting ? l10n.releaseWhileVisiting : l10n.releaseHint,
  destructive: true,
  enabled: !visiting,
  onSelected: onSelected,
);

Future<void> _champions(
  BuildContext context,
  WidgetRef ref,
  int id, {
  required bool visiting,
}) async {
  try {
    await ref
        .read(specimenRepositoryProvider)
        .setChampionsVisit(id, visiting: visiting);
    ref.read(slotActionsProvider).specimensChanged();
    if (context.mounted) {
      _notify(
        context,
        visiting
            ? context.l10n.nowVisitingChampions
            : context.l10n.nowBackFromChampions,
      );
    }
  } on AppFailure catch (failure) {
    if (context.mounted) _notify(context, context.failureText(failure));
  }
}
