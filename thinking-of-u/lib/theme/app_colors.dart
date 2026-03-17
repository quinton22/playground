import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary — warm rose/pink (love & friendship)
  static const Color primary = Color(0xFFE91E8C);
  static const Color primaryLight = Color(0xFFF48FB1);
  static const Color primaryDark = Color(0xFFC2185B);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Secondary — soft lavender (playful, dreamy)
  static const Color secondary = Color(0xFF9C27B0);
  static const Color secondaryLight = Color(0xFFCE93D8);
  static const Color onSecondary = Color(0xFFFFFFFF);

  // Tertiary — peach/orange (warm, friendly)
  static const Color tertiary = Color(0xFFFF6B6B);
  static const Color tertiaryLight = Color(0xFFFFAB91);
  static const Color onTertiary = Color(0xFFFFFFFF);

  // Accent — golden yellow (joy, sunshine)
  static const Color accent = Color(0xFFFFD700);
  static const Color accentLight = Color(0xFFFFF176);

  // Background — very light pink/cream
  static const Color background = Color(0xFFFFF5F9);
  static const Color onBackground = Color(0xFF2D1B2E);

  // Surface
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFFCE4EC);
  static const Color onSurface = Color(0xFF2D1B2E);

  // Divider / Border
  static const Color divider = Color(0xFFFFCDD2);

  // Error
  static const Color error = Color(0xFFE53935);
  static const Color onError = Color(0xFFFFFFFF);

  // Success
  static const Color success = Color(0xFF43A047);
  static const Color onSuccess = Color(0xFFFFFFFF);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFE91E8C), Color(0xFF9C27B0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFFFFF5F9), Color(0xFFFCE4EC), Color(0xFFF3E5F5)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient heartGradient = LinearGradient(
    colors: [Color(0xFFE91E8C), Color(0xFFFF6B6B), Color(0xFFFFD700)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFFFF0F5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
