import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accentPurple,
      brightness: brightness,
      surface: isDark ? AppColors.darkSurface : AppColors.bgSecondary,
      primary: AppColors.accentPurple,
      secondary: AppColors.accentTeal,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? AppColors.darkBg : AppColors.bgPrimary,
      fontFamily: 'Inter',
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? AppColors.darkText : AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardTheme(
        color: isDark ? AppColors.darkCard : AppColors.bgCard,
        elevation: 0,
        shadowColor: AppColors.accentPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.darkBorder : AppColors.border,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : AppColors.lavenderSoft,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.accentPurple),
        ),
        labelStyle: TextStyle(
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        ),
        hintStyle: TextStyle(
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        ),
        prefixIconColor: AppColors.accentPurple,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accentPurple,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? AppColors.darkText : AppColors.purpleDeep,
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
          minimumSize: const Size.fromHeight(48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: isDark ? AppColors.darkText : AppColors.textPrimary,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : (isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.accentPurple
              : (isDark ? AppColors.darkSurface : AppColors.lavender),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.accentPurple,
        inactiveTrackColor: isDark ? AppColors.darkSurface : AppColors.lavender,
        thumbColor: AppColors.accentPurple,
      ),
    );
  }
}
