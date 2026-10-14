import 'package:ishinydex/core/utils/origin_mark.dart';
import 'package:ishinydex/l10n/app_localizations.dart';

/// Textos de `core/utils` no idioma da tela (ishinydex-frontend#178).
extension CoreLabels on AppLocalizations {
  /// Os jogos da [mark] por extenso: `"Sword e Shield"`, `"X e Y / Omega
  /// Ruby e Alpha Sapphire"`.
  String originMarkGames(OriginMark mark) => mark.games
      .map(
        (pair) => switch (pair) {
          [final first, final second] => gamePair(first, second),
          _ => pair.join(' / '),
        },
      )
      .join(' / ');

  /// `" · 2 fora"` (registrados fora do HOME); vazio se nenhum.
  String awayCount(int away) => away > 0 ? awaySuffix('$away') : '';
}
