// OCR PDF Service - Creates searchable PDFs with invisible text layers
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;
import 'ocr_engine.dart';

/// Page classification result
enum PageType {
  textBased, // Has extractable text
  scanned, // No text, needs OCR
}

/// Page info with classification
class PageInfo {
  final String filePath;
  final int pageNumber; // 1-based for PDFs, 1 for images
  final PageType type;
  final String? extractedText;

  PageInfo({
    required this.filePath,
    required this.pageNumber,
    required this.type,
    this.extractedText,
  });

  bool get needsOcr => type == PageType.scanned;
}

/// OCR PDF Service
class OcrPdfService {
  /// Classify pages from input files
  static Future<List<PageInfo>> classifyPages(List<String> inputs) async {
    final List<PageInfo> pages = [];

    for (final path in inputs) {
      final lower = path.toLowerCase();

      if (lower.endsWith('.pdf')) {
        // Classify each PDF page using pdfx for text extraction
        try {
          final bytes = await File(path).readAsBytes();
          final document = await pdfx.PdfDocument.openData(bytes);

          for (int i = 1; i <= document.pagesCount; i++) {
            final page = await document.getPage(i);
            
            // pdfx doesn't provide text extraction, so we'll assume scanned
            // You may need to render and OCR to determine if text exists
            // For now, classify as scanned to trigger OCR
            await page.close();

            final type = PageType.scanned;

            print('📄 Page $i classification:');
            print('  Type: $type (pdfx cannot extract text)');

            pages.add(PageInfo(
              filePath: path,
              pageNumber: i,
              type: type,
              extractedText: null,
            ));
          }
          await document.close();
        } catch (e) {
          print('Error classifying PDF: $e');
          // If error, treat as scanned
          pages.add(PageInfo(
            filePath: path,
            pageNumber: 1,
            type: PageType.scanned,
          ));
        }
      } else if (lower.endsWith('.png') ||
          lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.webp') ||
          lower.endsWith('.bmp')) {
        // Images are always scanned
        pages.add(PageInfo(
          filePath: path,
          pageNumber: 1,
          type: PageType.scanned,
        ));
      }
    }

    return pages;
  }

  /// Generate searchable PDF with OCR
  static Future<File> generateSearchablePdf({
    required List<String> inputs,
    required OcrEngine ocrEngine,
    required String language,
    required bool forceOcrAll,
    Function(double progress, String message)? onProgress,
  }) async {
    final pdf = pw.Document();

    onProgress?.call(0.0, 'Classifying pages...');
    final pages = await classifyPages(inputs);

    int processedCount = 0;
    final totalPages = pages.length;

    for (final pageInfo in pages) {
      final progress = processedCount / totalPages;
      onProgress?.call(
          progress, 'Processing page ${processedCount + 1} of $totalPages...');

      final lower = pageInfo.filePath.toLowerCase();

      if (lower.endsWith('.pdf')) {
        await _processPdfPage(
          pdf: pdf,
          pageInfo: pageInfo,
          ocrEngine: ocrEngine,
          language: language,
          forceOcrAll: forceOcrAll,
        );
      } else {
        await _processImagePage(
          pdf: pdf,
          pageInfo: pageInfo,
          ocrEngine: ocrEngine,
          language: language,
        );
      }

      processedCount++;
    }

    onProgress?.call(1.0, 'Saving PDF...');

    final bytes = await pdf.save();

    final dir = await getTemporaryDirectory();
    final outPath =
        p.join(dir.path, 'ocr_${DateTime.now().millisecondsSinceEpoch}.pdf');
    final outFile = File(outPath);
    await outFile.writeAsBytes(bytes, flush: true);

    return outFile;
  }

  /// Process a single PDF page
  static Future<void> _processPdfPage({
    required pw.Document pdf,
    required PageInfo pageInfo,
    required OcrEngine ocrEngine,
    required String language,
    required bool forceOcrAll,
  }) async {
    // Render source PDF page to an image
    final bytes = await File(pageInfo.filePath).readAsBytes();
    final pdfxDoc = await pdfx.PdfDocument.openData(bytes);
    final pdfxPage = await pdfxDoc.getPage(pageInfo.pageNumber);

    // Render at 2x for better quality
    final rendered = await pdfxPage.render(
      width: pdfxPage.width * 2,
      height: pdfxPage.height * 2,
      format: pdfx.PdfPageImageFormat.png,
    );
    await pdfxPage.close();
    await pdfxDoc.close();

    if (rendered == null) {
      pdf.addPage(pw.Page(build: (context) => pw.Container()));
      return;
    }

    final imageWidthPx = (rendered.width ?? pdfxPage.width * 2).toDouble();
    final imageHeightPx = (rendered.height ?? pdfxPage.height * 2).toDouble();

    // Decode image for embedding
    final decodedImage = img.decodeImage(rendered.bytes);
    if (decodedImage == null) {
      pdf.addPage(pw.Page(build: (context) => pw.Container()));
      return;
    }

    final pdfImage = pw.MemoryImage(rendered.bytes);

    // Add OCR text layer if needed
    List<OcrTextBlock>? ocrBlocks;
    if (pageInfo.needsOcr || forceOcrAll) {
      final processedBytes = await _preprocessImage(rendered.bytes);
      final ocr = await ocrEngine.recognizeText(
        processedBytes,
        language: language,
        imageSize: ui.Size(imageWidthPx, imageHeightPx),
      );

      if (ocr.hasText) {
        print('📝 OCR found ${ocr.blocks.length} text blocks');
        ocrBlocks = ocr.blocks;
      }
    }

    // Create PDF page with image and invisible text layer
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          imageWidthPx,
          imageHeightPx,
          marginAll: 0,
        ),
        build: (context) {
          return pw.Stack(
            children: [
              // Background image
              pw.Image(pdfImage, fit: pw.BoxFit.fill),
              // Invisible text layer
              if (ocrBlocks != null)
                ..._buildInvisibleTextWidgets(
                  ocrBlocks,
                  imageWidthPx,
                  imageHeightPx,
                ),
            ],
          );
        },
      ),
    );
  }

  /// Process a single image page
  static Future<void> _processImagePage({
    required pw.Document pdf,
    required PageInfo pageInfo,
    required OcrEngine ocrEngine,
    required String language,
  }) async {
    final bytes = await File(pageInfo.filePath).readAsBytes();

    // Decode image to get dimensions
    final decodedImg = img.decodeImage(bytes);
    if (decodedImg == null) {
      pdf.addPage(pw.Page(build: (context) => pw.Container()));
      return;
    }

    final imageWidthPx = decodedImg.width.toDouble();
    final imageHeightPx = decodedImg.height.toDouble();

    final pdfImage = pw.MemoryImage(bytes);

    // Add OCR text layer
    final processedBytes = await _preprocessImage(bytes);
    final ocrResult = await ocrEngine.recognizeText(
      processedBytes,
      language: language,
      imageSize: ui.Size(imageWidthPx, imageHeightPx),
    );

    List<OcrTextBlock>? ocrBlocks;
    if (ocrResult.hasText) {
      print('📝 OCR found ${ocrResult.blocks.length} text blocks');
      ocrBlocks = ocrResult.blocks;
    }

    // Create PDF page with image and invisible text layer
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          imageWidthPx,
          imageHeightPx,
          marginAll: 0,
        ),
        build: (context) {
          return pw.Stack(
            children: [
              // Background image
              pw.Image(pdfImage, fit: pw.BoxFit.fill),
              // Invisible text layer
              if (ocrBlocks != null)
                ..._buildInvisibleTextWidgets(
                  ocrBlocks,
                  imageWidthPx,
                  imageHeightPx,
                ),
            ],
          );
        },
      ),
    );
  }

    /// Preprocess image for better OCR
  static Future<Uint8List> _preprocessImage(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;

      // Convert to grayscale
      final grayscale = img.grayscale(image);

      // Increase contrast
      final contrast = img.adjustColor(grayscale, contrast: 1.2);

      // Encode back to PNG
      final processed = img.encodePng(contrast);
      return Uint8List.fromList(processed);
    } catch (e) {
      return imageBytes;
    }
  }

  /// Build invisible text widgets for PDF overlay
  /// Uses text rendering with character spacing to match OCR bounding boxes
  static List<pw.Widget> _buildInvisibleTextWidgets(
    List<OcrTextBlock> blocks,
    double pageWidth,
    double pageHeight,
  ) {
    final widgets = <pw.Widget>[];

    for (final block in blocks) {
      final text = block.text?.trim() ?? '';
      if (text.isEmpty) continue;

      final box = block.boundingBox;

      // PDF package uses bottom-left origin, OCR uses top-left
      // Convert coordinates: pdfY = pageHeight - (ocrY + ocrHeight)
      final left = box.left;
      final bottom = pageHeight - (box.top + box.height);
      final width = box.width;
      final height = box.height;

      // Calculate font size based on box height
      final fontSize = (height * 0.75).clamp(6.0, 100.0);

      // Calculate character spacing to stretch text across the box width
      // Estimate natural text width (Helvetica: ~0.5 * fontSize per char)
      final avgCharWidth = fontSize * 0.5;
      final estimatedWidth = text.length * avgCharWidth;
      final charSpacing = estimatedWidth > 0 && text.length > 1
          ? (width - estimatedWidth) / (text.length - 1)
          : 0.0;

      widgets.add(
        pw.Positioned(
          left: left,
          bottom: bottom,
          // width: width,
          // height: height,
          child: pw.Opacity(
            opacity: 0.0, // Completely invisible
            child: pw.Text(
              text,
              style: pw.TextStyle(
                font: pw.Font.helvetica(),
                fontSize: fontSize,
                letterSpacing: charSpacing.clamp(-2.0, 5.0),
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }
}
