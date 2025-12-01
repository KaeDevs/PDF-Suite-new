import 'package:flutter/material.dart';

class Tools {
  // Headings (Theme-based colors with Poppins font)
  static TextStyle h1(BuildContext context,) {
    final textScale = MediaQuery.of(context).textScaler;
    return TextStyle(
        fontSize: 30 * textScale.scale(30),
        fontWeight: FontWeight.bold,
        fontFamily: 'Poppins',
        color: Theme.of(context).textTheme.titleLarge?.color,
      );
  }

  static TextStyle h2(BuildContext context) => TextStyle(
        fontSize: 27,
        fontWeight: FontWeight.bold,
        fontFamily: 'Poppins',
        color: Theme.of(context).colorScheme.onPrimary,
      );

  static TextStyle h3(BuildContext context) { 
    return TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        fontFamily: 'Poppins',
        color: Theme.of(context).colorScheme.onPrimary,
      );
  }

  // Oswald-styled text for numbers and special emphasis
  static TextStyle oswaldText(BuildContext context, {
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.bold,
    Color? color,
  }) => TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontFamily: 'Oswald',
        color: color ?? Theme.of(context).colorScheme.onPrimary,
      );

  // Poppins body text
  static TextStyle bodyText(BuildContext context, {
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
  }) => TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontFamily: 'Poppins',
        color: color ?? Theme.of(context).textTheme.bodyLarge?.color,
      );

  // Poppins subtitle text
  static TextStyle subtitle(BuildContext context, {
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
  }) => TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontFamily: 'Poppins',
        color: color ?? Theme.of(context).textTheme.bodyMedium?.color,
      );
}
