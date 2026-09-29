import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/core/utils/pokemon_types.dart';

void main() {
  test('nomes em inglês, formatados', () {
    expect(typeLabel('grass'), 'Grass');
    expect(typeLabel('psychic'), 'Psychic');
    expect(typeLabel('shadow-type'), 'Shadow Type');
  });

  test('cores e contraste do texto', () {
    expect(typeColor('fire'), const Color(0xFFEE8130));
    expect(typeColor('desconhecido'), Colors.grey);
    // Fundo escuro → texto branco; fundo claro → texto escuro.
    expect(typeOnColor('ghost'), Colors.white);
    expect(typeOnColor('electric'), Colors.black87);
  });
}
