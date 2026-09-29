/// `"mr-mime-galar"` → `"Mr Mime Galar"`.
String prettifyName(String raw) => raw
    .split(RegExp('[-_ ]+'))
    .where((part) => part.isNotEmpty)
    .map((part) => part[0].toUpperCase() + part.substring(1))
    .join(' ');

/// Percentual inteiro de [done] sobre [total] (0 quando [total] é 0).
int percentOf(int done, int total) =>
    total == 0 ? 0 : (done * 100 / total).floor();

/// Emoji de alfa, o mesmo do admin do backend (`Specimen.__str__`).
const alphaEmoji = '💢';
