/// Até quando um jogo só de ida chega ao HOME (#222): o fechamento do
/// Pokémon Bank, em 26/02/2027, corta XY, ORAS, SM e USUM. A data vem do
/// catálogo (`homeUntil`), então um adiamento é só uma release do catálogo.
///
/// O corte só afeta a **transferência**: saves, caçadas e odds desses jogos
/// continuam valendo (decisão do usuário).
class HomeCutoff {
  const HomeCutoff({required this.until, required this.now});

  /// O instante do corte (UTC).
  final DateTime until;
  final DateTime now;

  /// O corte já passou: o Pokémon do jogo não chega mais ao HOME.
  bool get passed => !now.isBefore(until);

  /// Os dias inteiros até o corte (0 no último dia).
  int get daysLeft => until.difference(now).inDays;

  /// Nos últimos 30 dias, o aviso fica forte.
  bool get closing => !passed && until.difference(now).inDays < 30;
}
