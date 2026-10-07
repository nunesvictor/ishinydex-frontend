/// Marca de origem (origin mark) do Pokémon HOME: o símbolo do jogo em que o
/// espécime foi obtido. A regra (qual jogo tem qual marca, GO com prioridade)
/// fica no backend, que manda o [slug] em `Specimen.originMark`; aqui é só a
/// apresentação.
///
/// Os ícones são os do HOME (Bulbagarden Archives): glifos brancos com fundo
/// transparente, pintados com a cor do tema (ver `OriginMarkIcon`).
enum OriginMark {
  gameBoy('game-boy', 'GB', 'Game Boy (Virtual Console)', 'game_boy'),
  kalos('kalos', 'XY/ORAS', 'X e Y / Omega Ruby e Alpha Sapphire', 'kalos'),
  alola('alola', 'SM/USUM', 'Sun e Moon / Ultra Sun e Ultra Moon', 'alola'),
  letsGo('lets-go', 'LGPE', "Let's Go, Pikachu! e Let's Go, Eevee!", 'lets_go'),
  galar('galar', 'SwSh', 'Sword e Shield', 'galar'),
  bdsp('bdsp', 'BDSP', 'Brilliant Diamond e Shining Pearl', 'bdsp'),
  hisui('hisui', 'PLA', 'Legends: Arceus', 'hisui'),
  paldea('paldea', 'SV', 'Scarlet e Violet', 'paldea'),
  lumiose('lumiose', 'PLZA', 'Legends: Z-A', 'lumiose'),
  go('go', 'GO', 'Pokémon GO', 'go');

  OriginMark(this.slug, this.label, this.games, this._file);

  /// Valor da API (`origin_mark`).
  final String slug;

  /// Sigla dos jogos, como os jogadores conhecem (`SV`, `SM/USUM`...).
  final String label;

  /// Nome completo dos jogos, para o tooltip e o leitor de tela.
  final String games;
  final String _file;

  String get asset => 'assets/origin_marks/$_file.png';

  /// `"paldea"` → [paldea]; valor desconhecido ou `null` → `null`.
  static OriginMark? fromSlug(String? slug) =>
      values.where((m) => m.slug == slug).firstOrNull;

  /// Marca dos jogos que recebem Pokémon do HOME, pela versão (o selo do
  /// save onde um espécime está): `"scarlet"` → [paldea].
  static OriginMark? fromVersion(String? version) => switch (version) {
    'lets-go-pikachu' || 'lets-go-eevee' => letsGo,
    'sword' || 'shield' => galar,
    'brilliant-diamond' || 'shining-pearl' => bdsp,
    'legends-arceus' => hisui,
    'scarlet' || 'violet' => paldea,
    'legends-za' => lumiose,
    _ => null,
  };
}
