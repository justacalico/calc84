import 'package:flutter/material.dart';

/// Palette for the handheld's hardware and LCD.
class CalcTheme {
  // Body plastic
  static const bodyTop = Color(0xFF2B2D30);
  static const bodyBottom = Color(0xFF141518);
  static const faceplate = Color(0xFF1C1D20);

  // LCD
  static const lcdBg = Color(0xFFF4F6F1);
  static const lcdEdge = Color(0xFF0A0B0C);
  static const lcdText = Color(0xFF1A1C1E);
  static const lcdDim = Color(0xFF5A5E60);
  static const lcdBlue = Color(0xFF3557C9);
  static const lcdGrid = Color(0xFFD6DAD2);
  static const lcdAxes = Color(0xFF2B2E30);
  static const lcdInverse = Color(0xFF1A1C1E);
  static const lcdCursor = Color(0xFF9AA39B);

  // Keys
  static const keyTop = Color(0xFF3A3C40);
  static const keyBottom = Color(0xFF232527);
  static const keyLightTop = Color(0xFF565A60);
  static const keyLightBottom = Color(0xFF3C4046);
  static const keyBlue = Color(0xFF2F6FD0);
  static const keyBlueDark = Color(0xFF1D4E9E);
  static const keyGreen = Color(0xFF3DA34A);
  static const keyGreenDark = Color(0xFF257A31);

  // Legend
  static const legend2nd = Color(0xFF5B8DEF);
  static const legendAlpha = Color(0xFF5BD06A);

  static const brand = Color(0xFFB9BDC2);

  static TextStyle lcd({double size = 13, bool bold = false, Color? color}) =>
      TextStyle(
        fontFamily: 'Roboto',
        fontSize: size,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        color: color ?? lcdText,
        height: 1.0,
      );

  static TextStyle keyLabel({double size = 13, Color color = Colors.white}) =>
      TextStyle(
        fontFamily: 'Roboto',
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.0,
      );

  static TextStyle legend({double size = 8.5, required Color color}) =>
      TextStyle(
        fontFamily: 'RobotoCondensed',
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.0,
        letterSpacing: -0.2,
      );
}
