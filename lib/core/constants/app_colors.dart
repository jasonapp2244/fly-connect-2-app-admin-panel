import 'package:flutter/material.dart';

class AppColors {
  // Primary brand colors
  static const Color primary = Color(0xFFD4F53C); // Neon yellow-green
  static const Color primaryDark = Color(0xFFC4E530);
  static const Color primaryLight = Color(0xFFE8FF6B);

  // Dark/background colors
  static const Color dark = Color(0xFF1A1D27); // Near-black dark navy
  static const Color darkCard = Color(0xFF252836);
  static const Color darkIcon = Color(0xFF1E2130);

  // Text colors
  static const Color textPrimary = Color(0xFF1A1D27);
  static const Color textSecondary = Color(0xFF8A8D9A);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textHint = Color(0xFFAAAAAA);

  // Background colors
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundGrey = Color(0xFFF5F5F5);
  static const Color backgroundCard = Color(0xFFF8F8F8);

  // Input field
  static const Color inputBorder = Color(0xFFE0E0E0);
  static const Color inputFill = Color(0xFFFFFFFF);

  // Status colors
  static const Color online = Color(0xFF4CAF50);
  static const Color error = Color(0xFFFF3B30);
  static const Color warning = Color(0xFFFF9500);
  static const Color badge = Color(0xFFFF3B30);

  // Gradient
  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8FF3C), Color(0xFFC8F000)],
  );

  static const LinearGradient onboardingOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x00D4F53C),
      Color(0xCCD4F53C),
      Color(0xFFD4F53C),
    ],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient matchCardOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Color(0xCC000000),
    ],
    stops: [0.4, 1.0],
  );
}
