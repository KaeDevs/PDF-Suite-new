import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pdf;

/// Compression presets for simple user selection.
enum PdfCompressionPreset {
  low, // smallest size, lowest quality
  medium, // balanced size and quality
}

class PdfCompressionService {
  /// Compress a single PDF by rasterizing its pages to JPEG images at the
  /// chosen quality/scale, then rebuilding a new PDF. This is effective for
  /// scanned/image-based PDFs and ensures visible size reduction.
  static Future<File> compressPdf(
    String inputPath, {
    PdfCompressionPreset preset = PdfCompressionPreset.medium,
  }) async {
    final doc = await pdfx.PdfDocument.openFile(inputPath);
    final pageCount = doc.pagesCount;

    final quality = _jpegQualityForPreset(preset);
    final maxWidth = _targetMaxWidthForPreset(preset);

    final out = pw.Document();

    for (int i = 1; i <= pageCount; i++) {
      final page = await doc.getPage(i);
      final pageWidth = page.width; // in PDF points
      final pageHeight = page.height; // in PDF points

      // Determine render pixel dimensions preserving aspect ratio
      final scale = pageWidth > 0 ? (maxWidth / pageWidth) : 1.0;
  final renderW = (pageWidth * scale).clamp(300, 4096).toDouble();
  final renderH = (pageHeight * scale).clamp(300, 4096).toDouble();

      final img = await page.render(
        width: renderW,
        height: renderH,
        format: pdfx.PdfPageImageFormat.jpeg,
        quality: quality,
      );
      await page.close();

      final imageBytes = img!.bytes;
      final memImg = pw.MemoryImage(imageBytes);

      out.addPage(
        pw.Page(
          pageFormat: pdf.PdfPageFormat(pageWidth, pageHeight),
          build: (context) => pw.Center(
            child: pw.Image(memImg, fit: pw.BoxFit.cover),
          ),
        ),
      );
    }

    final outBytes = await out.save();
    await doc.close();

    final tempDir = await getTemporaryDirectory();
    final basename = p.basenameWithoutExtension(inputPath);
    final presetName = _presetSuffix(preset);
    final outPath = p.join(tempDir.path, '${basename}_compressed_$presetName.pdf');
    final outFile = File(outPath);
    await outFile.writeAsBytes(outBytes, flush: true);
    return outFile;
  }

  /// Batch compress multiple PDF files. Returns the list of compressed files in the same order.
  static Future<List<File>> compressBatch(
    List<String> inputPaths, {
    PdfCompressionPreset preset = PdfCompressionPreset.medium,
    void Function(int index, int total)? onProgress,
  }) async {
    final results = <File>[];
    for (var i = 0; i < inputPaths.length; i++) {
      final out = await compressPdf(inputPaths[i], preset: preset);
      results.add(out);
      onProgress?.call(i + 1, inputPaths.length);
    }
    return results;
  }

  static int _jpegQualityForPreset(PdfCompressionPreset preset) {
    switch (preset) {
      case PdfCompressionPreset.low:
        return 35; // more aggressive for smaller files
      case PdfCompressionPreset.medium:
        return 55; // reduced from 65 to avoid size increase
    }
  }

  static double _targetMaxWidthForPreset(PdfCompressionPreset preset) {
    switch (preset) {
      case PdfCompressionPreset.low:
        return 1000; // reduced for smaller files
      case PdfCompressionPreset.medium:
        return 1400; // reduced from 1700 to ensure compression
    }
  }

  static String _presetSuffix(PdfCompressionPreset preset) {
    switch (preset) {
      case PdfCompressionPreset.low:
        return 'low';
      case PdfCompressionPreset.medium:
        return 'medium';
    }
  }
}
