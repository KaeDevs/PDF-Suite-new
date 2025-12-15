import 'dart:typed_data';
import 'dart:ui';

/// Result from OCR text recognition
class OcrResult {
  final String text;
  final List<OcrTextBlock> blocks;

  OcrResult({
    required this.text,
    required this.blocks,
  });

  bool get hasText => text.trim().isNotEmpty;
}

/// A block of recognized text with bounding box
class OcrTextBlock {
  final String text;
  final OcrBoundingBox boundingBox;

  OcrTextBlock({
    required this.text,
    required this.boundingBox,
  });
}

/// Bounding box for text positioning
class OcrBoundingBox {
  final double left;
  final double top;
  final double width;
  final double height;

  OcrBoundingBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
}

/// Abstract OCR engine interface
abstract class OcrEngine {
  /// Recognize text from image bytes
  Future<OcrResult> recognizeText(
    Uint8List imageBytes, {
    String language = 'en',    Size? imageSize,  });

  /// Release resources
  Future<void> dispose();
}
