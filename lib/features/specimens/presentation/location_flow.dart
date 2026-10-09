import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/utils/origin_mark.dart';
import 'package:ishinydex/core/widgets/action_sheet.dart';
import 'package:ishinydex/core/widgets/game_icon.dart';
import 'package:ishinydex/core/widgets/origin_mark_chip.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/domain/transfer_rules.dart';
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
      title: Text('Em ${save.title}'),
      subtitle: date == null
          ? const Text('Fora do HOME')
          : Text(
              'Desde ${MaterialLocalizations.of(context).formatCompactDate(date)}'
              ' · ${awayFor(date)}',
            ),
    );
  }
}

void _notify(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

/// Escolhe o save de destino dos [ids], com a checagem de quem pode ir
/// ([TransferCheck]). Sem nenhum save cadastrado, explica e oferece abrir
/// Ajustes → Meus saves. `null` = desistiu. Um save em que nenhum dos
/// espécimes pode entrar fica desabilitado; os outros dizem quantos ficam,
/// os avisos e quantos estão fora da pokédex do jogo.
Future<({Save save, TransferCheck check})?> pickSave(
  BuildContext context,
  WidgetRef ref,
  List<int> ids,
) async {
  final List<Save> saves;
  try {
    saves = await ref.read(savesProvider.future);
  } on AppFailure catch (failure) {
    if (context.mounted) _notify(context, failure.message);
    return null;
  }
  if (!context.mounted) return null;
  if (saves.isEmpty) {
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nenhum save cadastrado'),
        content: const Text(
          'Cadastre seus saves (os jogos para onde você envia Pokémon) em '
          'Ajustes → Meus saves.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Agora não'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Abrir Meus saves'),
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
              'Enviar para qual save?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final save in saves) _saveOption(context, ref, save, ids),
        ],
      ),
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
  final warning = _saveWarning(save, ids.length, check);
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
String? _saveWarning(Save save, int total, TransferCheck check) {
  final outsideText = 'fora da pokédex de ${save.game}';
  if (total == 1) {
    if (check.blocked.isNotEmpty) return check.blocked.first.message;
    if (check.warnings.isNotEmpty) return check.warnings.first.message;
    return check.outside > 0 ? 'Fora da pokédex de ${save.game}' : null;
  }
  if (!check.allowed) {
    final reasons = {for (final b in check.blocked) b.message};
    return reasons.length == 1 ? reasons.first : 'Nenhum deles pode ir';
  }
  final parts = [
    if (check.blocked.length == 1) '1 não pode ir',
    if (check.blocked.length > 1) '${check.blocked.length} não podem ir',
    if (check.warnings.isNotEmpty) '${check.warnings.length} com aviso',
    if (check.outside > 0) '${check.outside} $outsideText',
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
    child: Text('${i.name}: ${i.message}'),
  );
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Enviar $going de $total para ${save.title}?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ficam no HOME', style: theme.textTheme.titleSmall),
            ...check.blocked.map(issue),
            if (check.warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Vão com aviso', style: theme.textTheme.titleSmall),
              ...check.warnings.map(issue),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(going == 1 ? 'Enviar 1' : 'Enviar os $going'),
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
      _notify(
        context,
        moved == 1
            ? '1 espécime enviado para ${save.title}.'
            : '$moved espécimes enviados para ${save.title}.',
      );
    }
    return true;
  } on AppFailure catch (failure) {
    if (context.mounted) _notify(context, failure.message);
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
      _notify(
        context,
        moved == 1
            ? '1 espécime de volta ao HOME.'
            : '$moved espécimes de volta ao HOME.',
      );
    }
    return true;
  } on AppFailure catch (failure) {
    if (context.mounted) _notify(context, failure.message);
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
      title: Text('$name voltou para o HOME'),
      content: const Text(
        'Ele voltou igual ou evoluiu no jogo? Se evoluiu, ele sai do slot '
        'atual, que volta a faltar, e fica disponível no inventário.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_Return.evolved),
          child: const Text('Evoluiu…'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_Return.same),
          child: const Text('Voltou igual'),
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
      _notify(
        context,
        'Evoluiu para ${form.displayName} e voltou ao HOME. O slot antigo '
        'voltou a faltar.',
      );
    }
  } on AppFailure catch (failure) {
    ref.read(slotActionsProvider).specimensChanged();
    if (context.mounted) _notify(context, failure.message);
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
    title: const Text('No HOME, visitando o Champions'),
    subtitle: Text(
      'Desde ${MaterialLocalizations.of(context).formatCompactDate(since)}'
      ' · ${awayFor(since)}',
    ),
  );
}

/// Ações de localização para a folha "Mais ações" (detalhe do espécime e
/// painel do slot): fora do HOME, "Trazer de volta"; visitando o Champions
/// (#174), "Voltou do Champions" e o envio desabilitado; no HOME, "Enviar
/// para jogo…" e "Visitar o Champions".
List<SheetAction> locationActions(
  BuildContext context,
  WidgetRef ref, {
  required int id,
  required String name,
  required bool away,
  required bool visiting,
}) {
  if (away) {
    return [
      SheetAction(
        icon: Icons.flight_land,
        label: 'Trazer de volta ao HOME',
        onSelected: () => bringBack(context, ref, specimenId: id, name: name),
      ),
    ];
  }
  return [
    if (visiting)
      SheetAction(
        icon: Icons.emoji_events,
        leading: const ChampionsIcon(),
        label: 'Voltou do Champions',
        subtitle: 'Libera o envio para saves',
        onSelected: () => _champions(context, ref, id, visiting: false),
      ),
    SheetAction(
      icon: Icons.flight_takeoff,
      label: 'Enviar para jogo…',
      subtitle: visiting ? 'Está visitando o Champions' : null,
      enabled: !visiting,
      onSelected: () => sendToGame(context, ref, [id]),
    ),
    if (!visiting)
      SheetAction(
        icon: Icons.emoji_events,
        leading: const ChampionsIcon(),
        label: 'Visitar o Champions',
        subtitle: 'Continua no HOME; enquanto visita, não vai para saves',
        onSelected: () => _champions(context, ref, id, visiting: true),
      ),
  ];
}

/// Libertar, desabilitado enquanto visita o Champions.
SheetAction releaseAction({
  required bool visiting,
  required VoidCallback onSelected,
}) => SheetAction(
  icon: Icons.warning_amber_rounded,
  label: 'Libertar',
  subtitle: visiting
      ? 'Não dá enquanto visita o Champions'
      : 'Apaga o cadastro (pede confirmação)',
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
        visiting ? 'Visitando o Champions.' : 'Voltou do Champions.',
      );
    }
  } on AppFailure catch (failure) {
    if (context.mounted) _notify(context, failure.message);
  }
}
