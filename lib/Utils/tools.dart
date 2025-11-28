import 'package:flutter/material.dart';

class Tools {
  // Headings (Theme-based colors)
  static TextStyle h1(BuildContext context,) {
    final textScale = MediaQuery.of(context).textScaler;
    return TextStyle(
    
        fontSize: 30 * textScale.scale(30)  ,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.titleLarge?.color,
      );
  }

  static TextStyle h2(BuildContext context) => TextStyle(
        fontSize: 27,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onPrimary,
      );

  static TextStyle h3(BuildContext context) { 
    // final textScale = MediaQuery.of(context).textScaleFactor;
    return TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: Theme.of(context).colorScheme.onPrimary,
      );
  }
  // Oswald-styled numeric value (still dynamic color)
  // static TextStyle oswaldValue(BuildContext context) => TextStyle(
  //       fontSize: 28,
  //       fontWeight: FontWeight.bold,
  //       fontFamily: 'Oswald',
  //       color: Theme.of(context).colorScheme.onPrimary,
  //     );

  // Themed button style
  // static ButtonStyle buttonStyle(BuildContext context, bool isActive) {
  //   final colorScheme = Theme.of(context).colorScheme;
  //   return TextButton.styleFrom(
  //     foregroundColor: isActive ? colorScheme.onSurface : Colors.grey[600],
  //     backgroundColor: isActive ? colorScheme.surfaceContainerHighest : Colors.grey[300],
  //     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
  //     shape: RoundedRectangleBorder(
  //       borderRadius: BorderRadius.circular(5),
  //     ),
  //   );
  // }
}
