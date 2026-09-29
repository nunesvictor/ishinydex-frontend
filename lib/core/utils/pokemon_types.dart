import 'package:flutter/material.dart';
import 'package:ishinydex/core/utils/format.dart';

/// Nomes em pt-BR dos tipos, como nos jogos. A API manda o slug em inglês.
const _typeLabels = {
  'normal': 'Normal',
  'fire': 'Fogo',
  'water': 'Água',
  'electric': 'Elétrico',
  'grass': 'Planta',
  'ice': 'Gelo',
  'fighting': 'Lutador',
  'poison': 'Venenoso',
  'ground': 'Terrestre',
  'flying': 'Voador',
  'psychic': 'Psíquico',
  'bug': 'Inseto',
  'rock': 'Pedra',
  'ghost': 'Fantasma',
  'dragon': 'Dragão',
  'dark': 'Sombrio',
  'steel': 'Aço',
  'fairy': 'Fada',
  'stellar': 'Estelar',
};

/// Cores tradicionais de cada tipo.
const _typeColors = {
  'normal': Color(0xFFA8A77A),
  'fire': Color(0xFFEE8130),
  'water': Color(0xFF6390F0),
  'electric': Color(0xFFF7D02C),
  'grass': Color(0xFF7AC74C),
  'ice': Color(0xFF96D9D6),
  'fighting': Color(0xFFC22E28),
  'poison': Color(0xFFA33EA1),
  'ground': Color(0xFFE2BF65),
  'flying': Color(0xFFA98FF3),
  'psychic': Color(0xFFF95587),
  'bug': Color(0xFFA6B91A),
  'rock': Color(0xFFB6A136),
  'ghost': Color(0xFF735797),
  'dragon': Color(0xFF6F35FC),
  'dark': Color(0xFF705746),
  'steel': Color(0xFFB7B7CE),
  'fairy': Color(0xFFD685AD),
  'stellar': Color(0xFF40B5A5),
};

/// `"grass"` → `"Planta"`; tipo desconhecido cai no nome formatado.
String typeLabel(String type) => _typeLabels[type] ?? prettifyName(type);

/// Cor do tipo; cinza para tipos desconhecidos.
Color typeColor(String type) => _typeColors[type] ?? Colors.grey;

/// Cor do texto sobre [typeColor]: preto ou branco, o que tiver mais contraste.
Color typeOnColor(String type) =>
    ThemeData.estimateBrightnessForColor(typeColor(type)) == Brightness.dark
    ? Colors.white
    : Colors.black87;
