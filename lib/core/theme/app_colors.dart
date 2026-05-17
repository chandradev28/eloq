import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const bgPrimary = Color(0xFFF4EEFF);
  static const bgSecondary = Color(0xFFFBF9FF);
  static const bgCard = Color(0xFFFFFFFF);
  static const accentPurple = Color(0xFF8A4FE8);
  static const accentTeal = Color(0xFFB89BFF);
  static const accentGreen = Color(0xFF6DCD96);
  static const accentYellow = Color(0xFFFFC65B);
  static const accentRed = Color(0xFFE45B73);
  static const textPrimary = Color(0xFF20202B);
  static const textSecondary = Color(0xFF8E88A1);
  static const border = Color(0xFFE9E1F6);

  static const lavender = Color(0xFFEDE3FF);
  static const lavenderSoft = Color(0xFFF7F2FF);
  static const purpleDeep = Color(0xFF6F35D6);
  static const dock = Color(0xFF17161C);
  static const dockItem = Color(0xFF2A2830);

  static const darkBg = Color(0xFF14111D);
  static const darkSurface = Color(0xFF211C2D);
  static const darkCard = Color(0xFF2B2438);
  static const darkBorder = Color(0xFF3C334C);
  static const darkText = Color(0xFFF9F6FF);
  static const darkTextSecondary = Color(0xFFC2B8D3);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color page(BuildContext context) =>
      isDark(context) ? darkBg : bgPrimary;

  static Color surface(BuildContext context) =>
      isDark(context) ? darkCard : bgCard;

  static Color softSurface(BuildContext context) =>
      isDark(context) ? darkSurface : lavenderSoft;

  static Color primaryText(BuildContext context) =>
      isDark(context) ? darkText : textPrimary;

  static Color secondaryText(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textSecondary;

  static Color line(BuildContext context) =>
      isDark(context) ? darkBorder : border;
}
