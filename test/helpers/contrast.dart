import 'package:flutter/material.dart';

/// Razão de contraste do WCAG entre duas cores (1 a 21). Texto normal pede
/// 4,5; ícones e elementos grandes, 3.
double contrast(Color a, Color b) {
  final (la, lb) = (a.computeLuminance(), b.computeLuminance());
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}
