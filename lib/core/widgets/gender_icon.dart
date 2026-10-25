import 'package:flutter/material.dart';

import 'package:ishinydex/core/l10n/l10n.dart';

/// O símbolo de gênero (#349): o ícone do Material, que vem com o app, no
/// lugar do emoji ♂️/♀️ (a fonte de emoji é baixada, e cada sistema a
/// desenha de um jeito). Azul para macho e vermelho para fêmea, como nos
/// jogos; no escuro, os mesmos tons claros da natureza. `null` para
/// qualquer outro valor (sem gênero).
class GenderIcon extends StatelessWidget {
  const GenderIcon(this.gender, {this.size = 18, super.key});

  /// `"male"` ou `"female"`.
  final String gender;
  final double size;

  static Color maleColor(Brightness brightness) => brightness == Brightness.dark
      ? const Color(0xFF90CAF9)
      : const Color(0xFF1565C0);

  static Color femaleColor(Brightness brightness) =>
      brightness == Brightness.dark
      ? const Color(0xFFEF9A9A)
      : const Color(0xFFC62828);

  /// O ícone de [gender], ou `null` quando não é macho nem fêmea.
  static GenderIcon? of(String? gender, {double size = 18}) =>
      gender == 'male' || gender == 'female'
      ? GenderIcon(gender!, size: size)
      : null;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final male = gender == 'male';
    return Icon(
      male ? Icons.male : Icons.female,
      size: size,
      color: male ? maleColor(brightness) : femaleColor(brightness),
      semanticLabel: male ? context.l10n.genderMale : context.l10n.genderFemale,
    );
  }
}
