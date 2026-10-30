import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Design system and theming for Magn.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.deepRed,
        secondary: AppColors.coralPink,
        surface: AppColors.warmCream,
        onPrimary: AppColors.warmCream,
        onSecondary: AppColors.warmCream,
        onSurface: AppColors.deepRed,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.warmCream,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
        ),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.warmCream,
        size: 28.0,
      ),
    );
  }
}
