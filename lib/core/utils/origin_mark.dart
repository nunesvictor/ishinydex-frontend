/// Marca de origem (origin mark) do Pokémon HOME: o símbolo do jogo em que o
/// espécime foi obtido. A regra (qual jogo tem qual marca, GO com prioridade)
/// fica no backend, que manda o [slug] em `Specimen.originMark`; aqui é só a
/// apresentação.
///
/// Os ícones são os do HOME (Bulbagarden Archives): glifos brancos com fundo
/// transparente, pintados com a cor do tema (ver `OriginMarkIcon`).
enum OriginMark {
  gameBoy('game-boy', 'Game Boy', 'game_boy'),
  kalos('kalos', 'Pentágono azul', 'kalos'),
  alola('alola', 'Trevo preto', 'alola'),
  letsGo('lets-go', "Let's Go", 'lets_go'),
  galar('galar', 'Galar', 'galar'),
  bdsp('bdsp', 'Brilliant Diamond e Shining Pearl', 'bdsp'),
  hisui('hisui', 'Legends: Arceus', 'hisui'),
  paldea('paldea', 'Scarlet e Violet', 'paldea'),
  lumiose('lumiose', 'Legends: Z-A', 'lumiose'),
  go('go', 'Pokémon GO', 'go');

  OriginMark(this.slug, this.label, this._file);

  /// Valor da API (`origin_mark`).
  final String slug;
  final String label;
  final String _file;

  String get asset => 'assets/origin_marks/$_file.png';

  /// `"paldea"` → [paldea]; valor desconhecido ou `null` → `null`.
  static OriginMark? fromSlug(String? slug) =>
      values.where((m) => m.slug == slug).firstOrNull;
}
