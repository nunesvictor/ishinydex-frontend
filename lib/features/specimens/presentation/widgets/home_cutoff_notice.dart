import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ishinydex/core/clock.dart';
import 'package:ishinydex/core/router/app_router.dart';
import 'package:ishinydex/features/specimens/domain/home_cutoff.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/specimen_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda o dia em que o aviso forte foi dispensado ("Entendi"): ele só
/// volta no dia seguinte. Não é dado do usuário (não vai para o sync).
abstract interface class HomeNoticeStorage {
  Future<String?> read();
  Future<void> write(String day);
}

class PrefsHomeNoticeStorage implements HomeNoticeStorage {
  static const _key = 'home_notice_dismissed';

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> write(String day) async {
    await (await SharedPreferences.getInstance()).setString(_key, day);
  }
}

final homeNoticeStorageProvider = Provider<HomeNoticeStorage>(
  (ref) => PrefsHomeNoticeStorage(),
);

/// O dia dispensado (`AAAA-MM-DD`), lido do aparelho.
final FutureProvider<String?> _dismissedProvider =
    FutureProvider.autoDispose<String?>(
      (ref) => ref.watch(homeNoticeStorageProvider).read(),
    );

String _day(DateTime d) => d.toIso8601String().substring(0, 10);

/// O aviso do corte do HOME (#222): quantos espécimes estão em saves cujo
/// jogo deixa de chegar ao HOME, e até quando dá para movê-los. Amarelo
/// antes; vermelho nos últimos 30 dias, quando "Entendi" o esconde até o
/// dia seguinte. Some sem espécimes nesses saves ou depois do corte.
/// [showAction]: o botão que abre a lista Fora do HOME.
class HomeCutoffNotice extends ConsumerWidget {
  const HomeCutoffNotice({this.showAction = true, super.key});

  final bool showAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cutoffOf = ref.watch(homeCutoffProvider);
    final specimens = ref.watch(awaySpecimensProvider).value ?? const [];
    final pending = <(Specimen, HomeCutoff)>[
      for (final s in specimens)
        if (cutoffOf(s.location?.trainer.version) case final c? when !c.passed)
          (s, c),
    ];
    if (pending.isEmpty) return const SizedBox.shrink();
    final cutoff = pending
        .map((p) => p.$2)
        .reduce((a, b) => a.until.isBefore(b.until) ? a : b);
    final now = ref.watch(clockProvider)();
    if (cutoff.closing && ref.watch(_dismissedProvider).value == _day(now)) {
      return const SizedBox.shrink();
    }
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final (background, foreground) = cutoff.closing
        ? (colors.errorContainer, colors.onErrorContainer)
        : (colors.tertiaryContainer, colors.onTertiaryContainer);
    final games = {for (final (s, _) in pending) s.location!.game}.toList();
    final where = games.length == 1
        ? games.single
        : '${games.sublist(0, games.length - 1).join(', ')} e ${games.last}';
    final n = pending.length;
    final date = MaterialLocalizations.of(context)
        .formatCompactDate(cutoff.until.toLocal());
    final days = cutoff.daysLeft;
    return Card(
      key: const ValueKey('home-cutoff-notice'),
      color: background,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                Icon(Icons.warning_amber_rounded, color: foreground),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        cutoff.closing
                            ? (days == 0
                                  ? 'Último dia do Pokémon Bank'
                                  : 'Faltam $days '
                                        '${days == 1 ? 'dia' : 'dias'} '
                                        'para o fim do Pokémon Bank')
                            : '$n ${n == 1 ? 'espécime' : 'espécimes'} '
                                  'em $where',
                        style: text.titleSmall?.copyWith(color: foreground),
                      ),
                      Text(
                        cutoff.closing
                            ? '$n ${n == 1 ? 'espécime' : 'espécimes'} em '
                                  '$where não ${n == 1 ? 'chega' : 'chegam'} '
                                  'mais ao HOME depois de $date.'
                            : 'O Pokémon Bank fecha em $date. Depois disso, '
                                  '${n == 1 ? 'ele não chega' : 'eles não chegam'} '
                                  'mais ao HOME. Mova antes (precisa do HOME '
                                  'Premium).',
                        style: text.bodySmall?.copyWith(color: foreground),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Wrap: no celular, os dois botões podem não caber lado a lado.
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                if (cutoff.closing)
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: foreground),
                    onPressed: () async {
                      await ref
                          .read(homeNoticeStorageProvider)
                          .write(_day(now));
                      ref.invalidate(_dismissedProvider);
                    },
                    child: const Text('Entendi'),
                  ),
                if (showAction)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: foreground,
                      side: BorderSide(color: foreground),
                    ),
                    onPressed: () => context.push(Routes.away),
                    child: Text(
                      n == 1 ? 'Ver o espécime' : 'Ver os $n espécimes',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
