import 'package:flutter/material.dart';

/// Draws bold text with a subtle stroke (outline) so it remains readable
/// against mixed or low-contrast backgrounds.
class OutlinedText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;
  final String? fontFamily;
  final TextAlign textAlign;
  final double? letterSpacing;

  const OutlinedText(
    this.text, {
    super.key,
    required this.fontSize,
    this.fontWeight = FontWeight.w900,
    required this.fillColor,
    required this.strokeColor,
    this.strokeWidth = 1.2,
    this.fontFamily,
    this.textAlign = TextAlign.center,
    this.letterSpacing,
  });

  @override
  Widget build(BuildContext context) {
    // Two-layer approach: bottom stroke + top fill
    return Stack(
      alignment: Alignment.center,
      children: [
        // Stroke layer
        Text(
          text,
          textAlign: textAlign,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            fontFamily: fontFamily,
            letterSpacing: letterSpacing,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..color = strokeColor,
          ),
        ),
        // Fill layer
        Text(
          text,
          textAlign: textAlign,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            fontFamily: fontFamily,
            letterSpacing: letterSpacing,
            color: fillColor,
          ),
        ),
      ],
    );
  }
}
