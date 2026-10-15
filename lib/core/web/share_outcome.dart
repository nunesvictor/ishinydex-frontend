/// O que aconteceu ao compartilhar um arquivo (#243).
enum ShareOutcome {
  /// A folha do sistema abriu e a pessoa escolheu um destino.
  shared,

  /// A pessoa fechou a folha sem escolher.
  cancelled,

  /// O navegador não compartilha arquivos: o arquivo foi baixado.
  downloaded,

  /// O navegador recusou (no iOS, quando a chamada não vem logo depois do
  /// toque).
  notAllowed,

  /// Outro erro.
  failed;

  /// Deu certo, ou a pessoa desistiu: não há o que avisar.
  bool get silent => this == shared || this == cancelled;
}
