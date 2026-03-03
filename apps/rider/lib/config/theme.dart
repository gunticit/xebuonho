import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color bg = Color(0xFF0B0F1A);
  static const Color bg2 = Color(0xFF111827);
  static const Color bg3 = Color(0xFF1F2937);
  static const Color card = Color(0xF2111827);
  static const Color border = Color(0x404B5563);
  static const Color text = Color(0xFFF9FAFB);
  static const Color text2 = Color(0xFF9CA3AF);
  static const Color text3 = Color(0xFF6B7280);
  static const Color green = Color(0xFF10B981);
  static const Color greenBg = Color(0x1F10B981);
  static const Color blue = Color(0xFF3B82F6);
  static const Color blueBg = Color(0x1F3B82F6);
  static const Color orange = Color(0xFFF59E0B);
  static const Color orangeBg = Color(0x1FF59E0B);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color purpleBg = Color(0x1F8B5CF6);
  static const Color red = Color(0xFFEF4444);
  static const Color redBg = Color(0x1FEF4444);
  static const Color cyan = Color(0xFF06B6D4);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      primaryColor: AppColors.blue,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.blue,
        secondary: AppColors.green,
        surface: AppColors.bg2,
        error: AppColors.red,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bg2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.blue, width: 2),
        ),
        hintStyle: const TextStyle(color: AppColors.text3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
