/// `"mr-mime-galar"` → `"Mr Mime Galar"`.
String prettifyName(String raw) => raw
    .split(RegExp('[-_ ]+'))
    .where((part) => part.isNotEmpty)
    .map((part) => part[0].toUpperCase() + part.substring(1))
    .join(' ');

/// Nome de uma versão de jogo como o jogo se chama (`legends-za` →
/// "Legends: Z-A"); as demais, pelo [prettifyName].
String versionLabel(String version) =>
    _versionLabels[version] ?? prettifyName(version);

const _versionLabels = {
  'firered': 'FireRed',
  'leafgreen': 'LeafGreen',
  'legends-arceus': 'Legends: Arceus',
  'legends-za': 'Legends: Z-A',
  'lets-go-pikachu': "Let's Go Pikachu",
  'lets-go-eevee': "Let's Go Eevee",
  'pokemon-go': 'Pokémon GO',
};

/// O nome completo do jogo, como na capa (`legends-arceus` → "Pokémon
/// Legends: Arceus"), onde há espaço para ele (Meus saves, #356).
String versionFullName(String version) =>
    _versionFullNames[version] ?? 'Pokémon ${versionLabel(version)}';

const _versionFullNames = {
  'lets-go-pikachu': "Pokémon: Let's Go, Pikachu!",
  'lets-go-eevee': "Pokémon: Let's Go, Eevee!",
  'pokemon-go': 'Pokémon GO',
};

/// Percentual inteiro de [done] sobre [total] (0 quando [total] é 0).
int percentOf(int done, int total) =>
    total == 0 ? 0 : (done * 100 / total).floor();

/// Emojis de shiny e alfa, os mesmos do admin do backend (`Specimen.__str__`).
const shinyEmoji = '✨';
const alphaEmoji = '💢';

/// Espécime vindo do Pokémon GO, como no admin.
const goEmoji = '📱';

const _diacritics = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', //
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n',
};

/// Minúsculas e sem acentos, para buscas: `"Poké Ball"` → `"poke ball"`.
String foldForSearch(String text) => text
    .toLowerCase()
    .split('')
    .map((char) => _diacritics[char] ?? char)
    .join();
