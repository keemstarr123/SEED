import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF000000); // Black for buttons
  static const Color accentColor = Color(0xFF6C63FF); // Example accent
  static const Color backgroundColor = Color(0xFFF8F8FF); // Light Blue
  static const Color fieldColor = Color(0xFFEAEAF6);

  static const double normalTextSize = 16;
  static const double smallTextSize = normalTextSize / 1.3;
  static const double largeTextSize = normalTextSize * 1.3;
  static const double extraSmallTextSize = (normalTextSize / 1.3) / 1.3;
  static const double extraLargeTextSize = (normalTextSize * 1.3) * 1.3;
  // Custom Gradients based on the provided image (Soft Blue -> Pink/Peach)
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFB3E5FC), // Light Blue
      Color(0xFFE1F5FE), // Lighter Blue
      Color(0xFFFFF3E0), // Peach
      Color(0xFFFFE0B2), // Stronger Peach/Orange
    ],
    stops: [0.0, 0.4, 0.7, 1.0],
  );

  static final ThemeData themeData = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      primary: primaryColor,
    ),
    scaffoldBackgroundColor:
        Colors.transparent, // Important for gradient background
    textTheme: GoogleFonts.poppinsTextTheme(),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[200],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
