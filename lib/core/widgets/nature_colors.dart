import 'package:material_ui/material_ui.dart';

/// As cores dos jogos para os stats da natureza (#410): o que ela aumenta
/// em vermelho (↑) e o que diminui em azul (↓), mais claras no tema escuro.
/// As mesmas do hexágono dos status base e do `GenderIcon`.
abstract final class NatureColors {
  static Color increased(Brightness brightness) => brightness == Brightness.dark
      ? const Color(0xFFEF9A9A)
      : const Color(0xFFC62828);

  static Color decreased(Brightness brightness) => brightness == Brightness.dark
      ? const Color(0xFF90CAF9)
      : const Color(0xFF1565C0);
}
