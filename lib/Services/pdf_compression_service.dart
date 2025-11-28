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

/// Target file size presets (as percentage of original)
enum PdfSizeTarget {
  quarter, // 25% of original
  half, // 50% of original
  threeQuarter, // 75% of original
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

  /// Compress a PDF to target a specific file size percentage
  static Future<File> compressPdfBySize(
    String inputPath, {
    PdfSizeTarget sizeTarget = PdfSizeTarget.half,
  }) async {
    final inputFile = File(inputPath);
    final originalSize = await inputFile.length();
    final targetSizeBytes = (originalSize * _targetPercentageForSize(sizeTarget)).round();
    
    // Start with aggressive settings and adjust if needed
    var quality = _initialQualityForSize(sizeTarget);
    var maxWidth = _initialWidthForSize(sizeTarget);
    
    for (int attempt = 0; attempt < 3; attempt++) {
      final compressedFile = await _compressPdfWithSettings(
        inputPath, 
        quality: quality, 
        maxWidth: maxWidth,
        suffix: '_${_sizeSuffix(sizeTarget)}',
      );
      
      final compressedSize = await compressedFile.length();
      
      // If we're within 10% of target, we're good
      if (compressedSize <= targetSizeBytes * 1.1) {
        return compressedFile;
      }
      
      // Adjust settings for next attempt
      quality = (quality * 0.8).round().clamp(20, 90);
      maxWidth = (maxWidth * 0.9).clamp(600, 2000);
      
      // Clean up failed attempt
      await compressedFile.delete();
    }
    
    // Final attempt with most aggressive settings
    return await _compressPdfWithSettings(
      inputPath,
      quality: 25,
      maxWidth: 800,
      suffix: '_${_sizeSuffix(sizeTarget)}',
    );
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

  /// Batch compress multiple PDF files by size target
  static Future<List<File>> compressBatchBySize(
    List<String> inputPaths, {
    PdfSizeTarget sizeTarget = PdfSizeTarget.half,
    void Function(int index, int total)? onProgress,
  }) async {
    final results = <File>[];
    for (var i = 0; i < inputPaths.length; i++) {
      final out = await compressPdfBySize(inputPaths[i], sizeTarget: sizeTarget);
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

  // Helper method to compress with specific settings
  static Future<File> _compressPdfWithSettings(
    String inputPath, {
    required int quality,
    required double maxWidth,
    required String suffix,
  }) async {
    final doc = await pdfx.PdfDocument.openFile(inputPath);
    final pageCount = doc.pagesCount;
    final out = pw.Document();

    for (int i = 1; i <= pageCount; i++) {
      final page = await doc.getPage(i);
      final pageWidth = page.width;
      final pageHeight = page.height;

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
    final outPath = p.join(tempDir.path, '$basename$suffix.pdf');
    final outFile = File(outPath);
    await outFile.writeAsBytes(outBytes, flush: true);
    return outFile;
  }

  static double _targetPercentageForSize(PdfSizeTarget sizeTarget) {
    switch (sizeTarget) {
      case PdfSizeTarget.quarter:
        return 0.25;
      case PdfSizeTarget.half:
        return 0.50;
      case PdfSizeTarget.threeQuarter:
        return 0.75;
    }
  }

  static int _initialQualityForSize(PdfSizeTarget sizeTarget) {
    switch (sizeTarget) {
      case PdfSizeTarget.quarter:
        return 30;
      case PdfSizeTarget.half:
        return 45;
      case PdfSizeTarget.threeQuarter:
        return 60;
    }
  }

  static double _initialWidthForSize(PdfSizeTarget sizeTarget) {
    switch (sizeTarget) {
      case PdfSizeTarget.quarter:
        return 900;
      case PdfSizeTarget.half:
        return 1200;
      case PdfSizeTarget.threeQuarter:
        return 1500;
    }
  }

  static String _sizeSuffix(PdfSizeTarget sizeTarget) {
    switch (sizeTarget) {
      case PdfSizeTarget.quarter:
        return 'compressed_25';
      case PdfSizeTarget.half:
        return 'compressed_50';
      case PdfSizeTarget.threeQuarter:
        return 'compressed_75';
    }
  }
}
