import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/core/utils/origin_mark.dart';
import 'package:ishinydex/core/widgets/action_sheet.dart';
import 'package:ishinydex/core/widgets/origin_mark_chip.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
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

/// Escolhe o save de destino dos [ids]. Sem nenhum save cadastrado, explica
/// e oferece abrir Ajustes → Meus saves. `null` = desistiu. Um save que não
/// aceita os espécimes (o Let's Go só recebe quem veio dele) fica
/// desabilitado; um em cujo jogo eles não estão na pokédex, só avisa.
Future<Save?> pickSave(
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
  return await showModalBottomSheet<Save>(
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
  final warning = !check.allowed
      ? save.restriction
      : switch (check.outside) {
          0 => null,
          1 when ids.length == 1 => 'Fora da pokédex de ${save.game}',
          final n => '$n fora da pokédex de ${save.game}',
        };
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
    onTap: () => Navigator.of(context).pop(save),
  );
}

/// Envia os [ids] para um save escolhido. Devolve `true` se enviou.
Future<bool> sendToGame(
  BuildContext context,
  WidgetRef ref,
  List<int> ids,
) async {
  final save = await pickSave(context, ref, ids);
  if (save == null || !context.mounted) return false;
  try {
    final moved = await ref
        .read(specimenRepositoryProvider)
        .transfer(ids, saveId: save.id);
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

/// Ação da localização para a folha "Mais ações": "Trazer de volta ao
/// HOME" (fora do HOME) ou "Enviar para jogo…" (no HOME). Para o detalhe do
/// espécime e o painel do slot.
SheetAction locationAction(
  BuildContext context,
  WidgetRef ref, {
  required int specimenId,
  required String name,
  required bool away,
}) => away
    ? SheetAction(
        icon: Icons.flight_land,
        label: 'Trazer de volta ao HOME',
        onSelected: () =>
            bringBack(context, ref, specimenId: specimenId, name: name),
      )
    : SheetAction(
        icon: Icons.flight_takeoff,
        label: 'Enviar para jogo…',
        onSelected: () => sendToGame(context, ref, [specimenId]),
      );
