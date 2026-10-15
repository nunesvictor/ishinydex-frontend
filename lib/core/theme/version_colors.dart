import 'package:flutter/material.dart';

/// A cor de cada versão (#203): vermelho no Scarlet, roxo no Violet, azul no
/// Sword... É a cor de marca do jogo, da qual saem o fundo e o texto de cada
/// tema ([versionTone]). Versões fora daqui usam as cores neutras do tema.
const versionColors = <String, Color>{
  'red': Color(0xFFE3350D),
  'blue': Color(0xFF3B6FD6),
  'yellow': Color(0xFFF5C400),
  'gold': Color(0xFFC9A227),
  'silver': Color(0xFFA8A9AD),
  'crystal': Color(0xFF4FC3E8),
  'ruby': Color(0xFFC0182E),
  'sapphire': Color(0xFF1F4FB3),
  'emerald': Color(0xFF10A35A),
  'firered': Color(0xFFF05A28),
  'leafgreen': Color(0xFF6AB94A),
  'diamond': Color(0xFF7EA6D9),
  'pearl': Color(0xFFE6A6C5),
  'platinum': Color(0xFF8C8C99),
  'heartgold': Color(0xFFD8A92B),
  'soulsilver': Color(0xFFA9B4C2),
  'black': Color(0xFF3A3A3A),
  'white': Color(0xFFD9D9D9),
  'black-2': Color(0xFF2F4757),
  'white-2': Color(0xFFE2C4C4),
  'x': Color(0xFF2563C9),
  'y': Color(0xFFD63A3A),
  'omega-ruby': Color(0xFFB3152B),
  'alpha-sapphire': Color(0xFF1E5BB8),
  'sun': Color(0xFFF08A1F),
  'moon': Color(0xFF6A4FBF),
  'ultra-sun': Color(0xFFF06A1F),
  'ultra-moon': Color(0xFF4B3BAF),
  'lets-go-pikachu': Color(0xFFF2C40A),
  'lets-go-eevee': Color(0xFFB07A3E),
  'sword': Color(0xFF2A8FD8),
  'shield': Color(0xFFD8316A),
  'brilliant-diamond': Color(0xFF4F8FE0),
  'shining-pearl': Color(0xFFE07FB0),
  'legends-arceus': Color(0xFFC8B27A),
  'scarlet': Color(0xFFE2382E),
  'violet': Color(0xFF7A3FC6),
  'legends-za': Color(0xFF3FA96B),
  'go': Color(0xFF2A9FD8),
};

/// O fundo e o texto de uma etiqueta ou chip de uma versão.
typedef VersionTone = ({Color background, Color foreground});

/// As cores de [version] no tema [brightness], ou `null` sem cor de marca.
///
/// Do matiz da marca saem um fundo claro e um texto escuro (no tema claro),
/// ou o contrário (no escuro). A saturação tem teto, para o amarelo do
/// Yellow e o ouro do HeartGold não sumirem nem ofuscarem; a luminosidade é
/// fixa, o que garante o contraste em todas as versões.
VersionTone? versionTone(String version, Brightness brightness) {
  final base = versionColors[version];
  if (base == null) return null;
  final hsl = HSLColor.fromColor(base);
  Color tone(double maxSaturation, double lightness) => HSLColor.fromAHSL(
    1,
    hsl.hue,
    hsl.saturation.clamp(0, maxSaturation),
    lightness,
  ).toColor();
  return brightness == Brightness.dark
      ? (background: tone(0.45, 0.26), foreground: tone(0.80, 0.87))
      : (background: tone(0.70, 0.89), foreground: tone(0.80, 0.24));
}

/// As cores de [version] no tema em volta de [context]: as da versão, ou as
/// neutras do tema ([neutral]) se ela não tiver cor de marca.
VersionTone versionToneOf(
  BuildContext context,
  String version, {
  required VersionTone neutral,
}) => versionTone(version, Theme.of(context).brightness) ?? neutral;
