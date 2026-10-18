import 'package:flutter/material.dart';
import 'brand_tokens.dart';

/// Lớp ánh xạ màu sắc tương thích ngược và kết nối trực tiếp với [BrandTokens].
class AppColors {
  // Brand identity colors (Light)
  static const Color primary = BrandTokens.brandPrimary;
  static const Color primarySecondary = BrandTokens.brandNavy;
  static const Color deepBlue = BrandTokens.brandNavy;

  static const Color textPrimary = BrandTokens.textPrimary;
  static const Color textSecondary = BrandTokens.textSecondary;
  static const Color textTertiary = BrandTokens.textTertiary;

  static const Color backgroundSoft = BrandTokens.background;
  static const Color backgroundBlueSoft = BrandTokens.brandTint;

  // Status semantic colors
  static const Color success = BrandTokens.normalFg;
  static const Color warning = BrandTokens.mediumFg;
  static const Color danger = BrandTokens.highFg;

  // Dark mode colors
  static const Color darkBackground = BrandTokens.darkBackground;
  static const Color darkSurface = BrandTokens.darkSurface;
  static const Color darkSurfaceVariant = BrandTokens.darkSurfaceVariant;
  static const Color darkTextPrimary = BrandTokens.darkTextPrimary;
  static const Color darkTextSecondary = BrandTokens.darkTextSecondary;
  static const Color darkTextTertiary = BrandTokens.darkTextTertiary;
  static const Color darkBorder = BrandTokens.darkBorder;

  // Backwards compatibility aliases
  static const Color primaryDark = deepBlue;
  static const Color primaryLight = BrandTokens.darkPrimary;
  static const Color background = backgroundSoft;
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: BrandTokens.brandPrimary,
        brightness: Brightness.light,
        primary: BrandTokens.brandPrimary,
        surface: BrandTokens.surface,
        onSurface: BrandTokens.textPrimary,
        outline: BrandTokens.border,
      ),
      scaffoldBackgroundColor: BrandTokens.background,
      cardColor: BrandTokens.surface,
      cardTheme: CardThemeData(
        color: BrandTokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
          side: BorderSide(
            color: BrandTokens.border.withValues(alpha: 0.6),
            width: 0.8,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: BrandTokens.surface,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: BrandTokens.textPrimary),
        titleTextStyle: TextStyle(
          color: BrandTokens.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BrandTokens.brandPrimary,
          foregroundColor: Colors.white,
          elevation: 1.5,
          shadowColor: BrandTokens.brandPrimary.withValues(alpha: 0.25),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BrandTokens.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BrandTokens.inputRadius),
          borderSide: const BorderSide(color: BrandTokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BrandTokens.inputRadius),
          borderSide: const BorderSide(color: BrandTokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BrandTokens.inputRadius),
          borderSide: const BorderSide(color: BrandTokens.brandPrimary, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: BrandTokens.surface,
        indicatorColor: BrandTokens.brandPrimary.withValues(alpha: 0.15),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: BrandTokens.brandPrimary,
        brightness: Brightness.dark,
        primary: BrandTokens.darkPrimary,
        surface: BrandTokens.darkSurface,
        onSurface: BrandTokens.darkTextPrimary,
        outline: BrandTokens.darkBorder,
      ),
      scaffoldBackgroundColor: BrandTokens.darkBackground,
      cardColor: BrandTokens.darkSurface,
      cardTheme: CardThemeData(
        color: BrandTokens.darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
          side: BorderSide(
            color: BrandTokens.darkBorder.withValues(alpha: 0.7),
            width: 0.8,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: BrandTokens.darkSurface,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BrandTokens.darkPrimary,
          foregroundColor: BrandTokens.darkOnPrimary, // Chữ navy đậm trên nền primary sáng
          elevation: 1.5,
          shadowColor: BrandTokens.darkPrimary.withValues(alpha: 0.25),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BrandTokens.darkSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BrandTokens.inputRadius),
          borderSide: const BorderSide(color: BrandTokens.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BrandTokens.inputRadius),
          borderSide: const BorderSide(color: BrandTokens.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BrandTokens.inputRadius),
          borderSide: const BorderSide(color: BrandTokens.darkPrimary, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: BrandTokens.darkSurface,
        indicatorColor: BrandTokens.darkPrimary.withValues(alpha: 0.25),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12);
          }
          return TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12);
        }),
      ),
    );
  }
}
