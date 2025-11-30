import 'package:flutter/material.dart';

/// Comprehensive app theme with defined color palette
class AppTheme {
  // ============================================
  // LIGHT MODE COLORS
  // ============================================
  static const Color lightPrimary = Color(0xFF2d6fa8); // Bright Blue - Primary actions
  static const Color lightSecondary = Color(0xFF3a9fd5); // Sky Blue - Secondary elements
  static const Color lightAccent = Color(0xFF52b8e8); // Light Blue - Highlights & accents
  static const Color lightBackground = Color(0xFFF5F9FC); // Soft Blue-tinted background
  static const Color lightSurface = Color(0xFFFFFFFF); // White surface
  static const Color lightOnPrimary = Color(0xFFFFFFFF); // White text on primary
  static const Color lightOnSurface = Color(0xFF1a2332); // Dark blue-gray text
  static const Color lightTertiary = Color(0xFFfdb82f); // Bright Golden - Tertiary/Highlights

  // ============================================
  // DARK MODE COLORS
  // ============================================
  static const Color darkPrimary = Color(0xFF254b73); // Deep Blue - Primary actions
  static const Color darkSecondary = Color(0xFF1c679a); // Ocean Blue - Secondary elements
  static const Color darkAccent = Color(0xFF248cc8); // Sky Blue - Highlights & accents
  static const Color darkBackground = Color(0xFF021028); // Very Dark Blue background
  static const Color darkSurface = Color(0xFF0a1a35); // Elevated dark blue surface
  static const Color darkOnPrimary = Color(0xFFFFFFFF); // White text on primary
  static const Color darkOnSurface = Color(0xFFE0E0E0); // Light text on surface
  static const Color darkTertiary = Color(0xFFf1a704); // Golden Yellow - Tertiary/Highlights

  // ============================================
  // GRADIENT DEFINITIONS
  // ============================================
  static const LinearGradient lightPrimaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lightPrimary, Color(0xFF4589c5)],
  );

  static const LinearGradient lightSecondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lightSecondary, Color(0xFF5bb5e5)],
  );

  static const LinearGradient lightAccentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lightAccent, Color(0xFF7fcef5)],
  );

  static const LinearGradient lightTertiaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFfdb82f), Color(0xFFffd165)],
  );

  static const LinearGradient darkPrimaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [darkPrimary, Color(0xFF2d5f8f)],
  );

  static const LinearGradient darkSecondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [darkSecondary, Color(0xFF2380b8)],
  );

  static const LinearGradient darkAccentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [darkAccent, Color(0xFF3aa5e0)],
  );

  static const LinearGradient darkTertiaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFf1a704), Color(0xFFffc13d)],
  );

  // ============================================
  // LIGHT THEME
  // ============================================
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: lightPrimary,
      secondary: lightSecondary,
      tertiary: lightTertiary,
      surface: lightSurface,
      background: lightBackground,
      onPrimary: lightOnPrimary,
      onSecondary: Colors.white,
      onSurface: lightOnSurface,
    ),
    scaffoldBackgroundColor: lightBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: lightPrimary,
      foregroundColor: lightOnPrimary,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: lightSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: lightPrimary,
        foregroundColor: lightOnPrimary,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: lightPrimary,
        foregroundColor: lightOnPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: lightPrimary,
        side: const BorderSide(color: lightPrimary, width: 2),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: lightTertiary,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD0E3F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD0E3F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: lightPrimary, width: 2),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: lightOnSurface),
      displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: lightOnSurface),
      displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: lightOnSurface),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: lightOnSurface),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: lightOnSurface),
      bodyLarge: TextStyle(fontSize: 16, color: lightOnSurface),
      bodyMedium: TextStyle(fontSize: 14, color: lightOnSurface),
    ),
  );

  // ============================================
  // DARK THEME
  // ============================================
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: darkPrimary,
      secondary: darkSecondary,
      tertiary: darkTertiary,
      surface: darkSurface,
      background: darkBackground,
      onPrimary: darkOnPrimary,
      onSecondary: Colors.white,
      onSurface: darkOnSurface,
    ),
    scaffoldBackgroundColor: darkBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: darkSurface,
      foregroundColor: darkOnSurface,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: darkSurface,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: darkPrimary,
        foregroundColor: darkOnPrimary,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: darkPrimary,
        foregroundColor: darkOnPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: darkPrimary,
        side: const BorderSide(color: darkPrimary, width: 2),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: darkTertiary,
      foregroundColor: Colors.black,
      elevation: 4,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF333333)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF333333)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: darkPrimary, width: 2),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: darkOnSurface),
      displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: darkOnSurface),
      displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: darkOnSurface),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: darkOnSurface),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: darkOnSurface),
      bodyLarge: TextStyle(fontSize: 16, color: darkOnSurface),
      bodyMedium: TextStyle(fontSize: 14, color: darkOnSurface),
    ),
  );

  // ============================================
  // HELPER METHODS
  // ============================================
  
  /// Get primary gradient based on theme brightness
  static LinearGradient getPrimaryGradient(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? lightPrimaryGradient
        : darkPrimaryGradient;
  }

  /// Get secondary gradient based on theme brightness
  static LinearGradient getSecondaryGradient(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? lightSecondaryGradient
        : darkSecondaryGradient;
  }

  /// Get accent gradient based on theme brightness
  static LinearGradient getAccentGradient(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? lightAccentGradient
        : darkAccentGradient;
  }

  /// Get tertiary gradient based on theme brightness
  static LinearGradient getTertiaryGradient(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? lightTertiaryGradient
        : darkTertiaryGradient;
  }

  /// Get multiple gradients for grid items
  static List<LinearGradient> getGridGradients(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? [lightPrimaryGradient, lightSecondaryGradient, lightAccentGradient, lightTertiaryGradient]
        : [darkPrimaryGradient, darkSecondaryGradient, darkAccentGradient, darkTertiaryGradient];
  }
}