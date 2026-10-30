import 'package:flutter/material.dart';

/// Semantic and chromatic palette for Magn.
class AppColors {
  AppColors._();

  // Primary Brand Sunset Chromatics
  static const Color deepRed = Color(0xFFAA0003);
  static const Color coralPink = Color(0xFFFF6B6B);
  static const Color warmCream = Color(0xFFFFEDD5);

  // Surface & Overlays
  static const Color creamTranslucent = Color(0x33FFEDD5);
  static const Color deepRedTranslucent = Color(0x1FAA0003);
  static const Color coralTranslucent = Color(0x26FF6B6B);

  // Lap Delta Highlights
  static const Color lapFastest = Color(0xFF10B981);
  static const Color lapSlowest = Color(0xFFEF4444);

  // Full-screen gradient
  static const List<Color> backgroundGradient = [
    deepRed,
    coralPink,
    warmCream,
  ];

  static const List<double> backgroundGradientStops = [0.0, 0.5, 1.0];
}
