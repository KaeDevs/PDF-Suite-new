import 'dart:typed_data';
import 'dart:ui';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'ocr_engine.dart';

/// ML Kit implementation of OCR engine
class MlKitOcrEngine implements OcrEngine {
  final TextRecognizer _recognizer;

  MlKitOcrEngine({String script = 'latin'})
      : _recognizer = TextRecognizer(script: _getTextRecognitionScript(script));

  static TextRecognitionScript _getTextRecognitionScript(String script) {
    switch (script.toLowerCase()) {
      case 'latin':
        return TextRecognitionScript.latin;
      case 'chinese':
        return TextRecognitionScript.chinese;
      // case 'devanagari':
      //   return TextRecognitionScript.devanagari;
      case 'japanese':
        return TextRecognitionScript.japanese;
      case 'korean':
        return TextRecognitionScript.korean;
      default:
        return TextRecognitionScript.latin;
    }
  }

  @override
  Future<OcrResult> recognizeText(
    Uint8List imageBytes, {
    String language = 'en',
    Size? imageSize,
  }) async {
    try {
      // Save bytes to temporary file (ML Kit works better with file paths)
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path, 'ocr_temp_${DateTime.now().millisecondsSinceEpoch}.png'));
      await tempFile.writeAsBytes(imageBytes);
      
      print('\ud83d\udcbe Saved temp file: ${tempFile.path}');
      
      // Create InputImage from file path
      final inputImage = InputImage.fromFilePath(tempFile.path);
      
      print('\ud83d\udcf8 Processing image with ML Kit...');
      final recognizedText = await _recognizer.processImage(inputImage);
      
      // Clean up temp file
      try {
        await tempFile.delete();
      } catch (e) {
        print('\u26a0\ufe0f Could not delete temp file: $e');
      }
      
      print('🔍 ML Kit OCR Results:');
      print('  Total text length: ${recognizedText.text.length}');
      print('  Number of blocks: ${recognizedText.blocks.length}');
      
      final blocks = <OcrTextBlock>[];
      // Use word-level granularity for precise text positioning (industry standard)
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          for (final element in line.elements) {
            final rect = element.boundingBox;
            blocks.add(
              OcrTextBlock(
                text: element.text,
                boundingBox: OcrBoundingBox(
                  left: rect.left,
                  top: rect.top,
                  width: rect.width,
                  height: rect.height,
                ),
              ),
            );
          }
        }
      }

      return OcrResult(
        text: recognizedText.text,
        blocks: blocks,
      );
    } catch (e, stackTrace) {
      print('\u274c ML Kit OCR Error: $e');
      print('Stack trace: $stackTrace');
      // Return empty result on error
      return OcrResult(text: '', blocks: []);
    }
  }

  @override
  Future<void> dispose() async {
    await _recognizer.close();
  }
}
