import 'package:flutter/material.dart';
import 'package:ishinydex/core/theme/app_palette.dart';

/// Ícone na cor de "concluído" do tema ([AppColors.success]): depositado,
/// registrado, box completa.
class SuccessIcon extends StatelessWidget {
  const SuccessIcon(this.icon, {super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) =>
      Icon(icon, color: AppColors.of(context).success);
}
