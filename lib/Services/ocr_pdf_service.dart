// OCR PDF Service - Creates searchable PDFs with invisible text layers
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:image/image.dart' as img;
import 'ocr_engine.dart';

// Standard DPI for PDF rendering (72 points = 1 inch)
const double _dpi = 300.0;

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
        // Classify each PDF page
        final bytes = await File(path).readAsBytes();
        final sf.PdfDocument doc = sf.PdfDocument(inputBytes: bytes);

        for (int i = 0; i < doc.pages.count; i++) {
          final text = sf.PdfTextExtractor(doc)
              .extractText(startPageIndex: i, endPageIndex: i);

          final type =
              (text.trim().length) > 10 ? PageType.textBased : PageType.scanned;

          print('📄 Page ${i + 1} classification:');
          print('  Extracted text length: ${text.trim().length}');
          print('  Type: $type');

          pages.add(PageInfo(
            filePath: path,
            pageNumber: i + 1,
            type: type,
            extractedText: text,
          ));
        }
        doc.dispose();
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
    final sf.PdfDocument result = sf.PdfDocument();

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
          result: result,
          pageInfo: pageInfo,
          ocrEngine: ocrEngine,
          language: language,
          forceOcrAll: forceOcrAll,
        );
      } else {
        await _processImagePage(
          result: result,
          pageInfo: pageInfo,
          ocrEngine: ocrEngine,
          language: language,
        );
      }

      processedCount++;
    }

    onProgress?.call(1.0, 'Saving PDF...');

    final bytes = Uint8List.fromList(await result.save());
    result.dispose();

    final dir = await getTemporaryDirectory();
    final outPath =
        p.join(dir.path, 'ocr_${DateTime.now().millisecondsSinceEpoch}.pdf');
    final outFile = File(outPath);
    await outFile.writeAsBytes(bytes, flush: true);

    return outFile;
  }

  /// Process a single PDF page
  static Future<void> _processPdfPage({
    required sf.PdfDocument result,
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
      result.pages.add();
      return;
    }

    final imageWidthPx = (rendered.width ?? pdfxPage.width * 2).toDouble();
    final imageHeightPx = (rendered.height ?? pdfxPage.height * 2).toDouble();

    // Use image dimensions directly for PDF page size (1:1 mapping)
    final pdfWidth = imageWidthPx;
    final pdfHeight = imageHeightPx;

    // Configure page settings
    result.pageSettings.margins.all = 0;
    result.pageSettings.size = ui.Size(pdfWidth, pdfHeight);
    result.pageSettings.orientation = pdfWidth > pdfHeight
        ? sf.PdfPageOrientation.landscape
        : sf.PdfPageOrientation.portrait;

    final newPage = result.pages.add();

    // Draw image
    final pageBitmap = sf.PdfBitmap(rendered.bytes);
    newPage.graphics.drawImage(
      pageBitmap,
      ui.Rect.fromLTWH(0, 0, pdfWidth, pdfHeight),
    );

    // Add OCR text layer if needed
    if (pageInfo.needsOcr || forceOcrAll) {
      final processedBytes = await _preprocessImage(rendered.bytes);
      final ocr = await ocrEngine.recognizeText(
        processedBytes,
        language: language,
        imageSize: ui.Size(imageWidthPx, imageHeightPx),
      );

      if (ocr.hasText) {
        print('📝 OCR found ${ocr.blocks.length} text blocks');
        await _addInvisibleTextLayer(
          page: newPage,
          blocks: ocr.blocks,
          imageWidth: imageWidthPx,
          imageHeight: imageHeightPx,
          pdfWidth: pdfWidth,
          pdfHeight: pdfHeight,
        );
      }
    }
  }

  /// Process a single image page
  static Future<void> _processImagePage({
    required sf.PdfDocument result,
    required PageInfo pageInfo,
    required OcrEngine ocrEngine,
    required String language,
  }) async {
    final bytes = await File(pageInfo.filePath).readAsBytes();

    // Decode image to get dimensions
    final decodedImg = img.decodeImage(bytes);
    if (decodedImg == null) {
      result.pages.add();
      return;
    }

    final imageWidthPx = decodedImg.width.toDouble();
    final imageHeightPx = decodedImg.height.toDouble();

    // Use image dimensions directly for PDF page size (1:1 mapping)
    final pdfWidth = imageWidthPx;
    final pdfHeight = imageHeightPx;

    // Configure page settings
    result.pageSettings.margins.all = 0;
    result.pageSettings.size = ui.Size(pdfWidth, pdfHeight);
    result.pageSettings.orientation = pdfWidth > pdfHeight
        ? sf.PdfPageOrientation.landscape
        : sf.PdfPageOrientation.portrait;

    final newPage = result.pages.add();

    // Draw image
    final pdfImg = sf.PdfBitmap(bytes);
    newPage.graphics.drawImage(
      pdfImg,
      ui.Rect.fromLTWH(0, 0, pdfWidth, pdfHeight),
    );

    // Add OCR text layer
    final processedBytes = await _preprocessImage(bytes);
    final ocrResult = await ocrEngine.recognizeText(
      processedBytes,
      language: language,
      imageSize: ui.Size(imageWidthPx, imageHeightPx),
    );

    if (ocrResult.hasText) {
      print('📝 OCR found ${ocrResult.blocks.length} text blocks');
      await _addInvisibleTextLayerPerChar(
        page: newPage,
        blocks: ocrResult.blocks,
        imageWidth: imageWidthPx,
        imageHeight: imageHeightPx,
        pdfWidth: pdfWidth,
        pdfHeight: pdfHeight,
      );
    }
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

  /// Add invisible text layer to page using render mode 3 (invisible)
  static Future<void> _addInvisibleTextLayer({
  required sf.PdfPage page,
  required List<OcrTextBlock> blocks,
  required double imageWidth,
  required double imageHeight,
  required double pdfWidth,
  required double pdfHeight,
}) async {
  // Calculate scale factors: points per pixel
  final scaleX = pdfWidth / imageWidth;
  final scaleY = pdfHeight / imageHeight;

  print('📐 Transform: ImageSize=${imageWidth}x$imageHeight, PDFSize=${pdfWidth}x$pdfHeight');
  print('   ScaleX=$scaleX, ScaleY=$scaleY');

  for (final block in blocks) {
    final text = block.text?.trim() ?? '';
    if (text.isEmpty) continue;

    // Split into words and position each one individually
    final words = text.split(RegExp(r'\s+'));
    final box = block.boundingBox;
    
    // Calculate approximate word width in the original box
    final totalChars = words.fold<int>(0, (sum, word) => sum + word.length);
    if (totalChars == 0) continue;
    
    final boxWidth = box.width * scaleX;
    final boxHeight = box.height * scaleY;
    
    // Estimate space taken by each character
    final charWidth = boxWidth / totalChars;
    
    // Start position
    double currentX = box.left * scaleX;
    final pdfY = box.top * scaleY;
    
    for (final word in words) {
      if (word.isEmpty) continue;
      
      // Calculate this word's width based on character count
      final wordWidth = charWidth * word.length;
      
      // Calculate font size to match box height
      // Use a more conservative factor for better compatibility
      final fontSize = (boxHeight * 0.75).clamp(6.0, 500.0);
      
      final font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, fontSize);
      
      // Create bounds for this specific word
      final wordBounds = ui.Rect.fromLTWH(currentX, pdfY, wordWidth, boxHeight);
      
      // Use transparent brush for invisible text
      final brush = sf.PdfSolidBrush(sf.PdfColor(0, 0, 0, 0));
      
      // Draw the word - let it naturally fit in its bounds
      page.graphics.drawString(
        word,
        font,
        brush: brush,
        bounds: wordBounds,
        format: sf.PdfStringFormat(
          alignment: sf.PdfTextAlignment.left,
          lineAlignment: sf.PdfVerticalAlignment.top,
        ),
      );
      
      print('  ✓ "$word" @ (${currentX.toStringAsFixed(1)}, ${pdfY.toStringAsFixed(1)}) '
            'w=${wordWidth.toStringAsFixed(1)} font=${fontSize.toStringAsFixed(1)}');
      
      // Move to next word position (add word width + space)
      currentX += wordWidth + (charWidth * 0.5); // 0.5 char width for space
    }
  }
}

/// Alternative: Draw each character individually for PERFECT positioning
/// This is what professional OCR systems do when they have per-character coordinates
static Future<void> _addInvisibleTextLayerPerChar({
  required sf.PdfPage page,
  required List<OcrTextBlock> blocks,
  required double imageWidth,
  required double imageHeight,
  required double pdfWidth,
  required double pdfHeight,
}) async {
  final scaleX = pdfWidth / imageWidth;
  final scaleY = pdfHeight / imageHeight;

  for (final block in blocks) {
    final text = block.text?.trim() ?? '';
    if (text.isEmpty) continue;

    final box = block.boundingBox;
    final boxWidth = box.width * scaleX;
    final boxHeight = box.height * scaleY;

    final charWidth = boxWidth / text.length;

    double currentX = box.left * scaleX;
    final pdfY = box.top * scaleY;

    final fontSize = (boxHeight * 0.75).clamp(6.0, 500.0);
    final font =
        sf.PdfStandardFont(sf.PdfFontFamily.helvetica, fontSize);

    final format = sf.PdfStringFormat(
      alignment: sf.PdfTextAlignment.center,
      lineAlignment: sf.PdfVerticalAlignment.top,
    );

    // 🔑 Make text invisible
    page.graphics.save();
    page.graphics.setTransparency(0);

    final brush = sf.PdfSolidBrush(sf.PdfColor(0, 0, 0));

    for (int i = 0; i < text.length; i++) {
      final char = text[i];

      if (char.trim().isEmpty) {
        currentX += charWidth;
        continue;
      }

      final charBounds =
          ui.Rect.fromLTWH(currentX, pdfY, charWidth, boxHeight);

      page.graphics.drawString(
        char,
        font,
        brush: brush,
        bounds: charBounds,
        format: format,
      );

      currentX += charWidth;
    }

    page.graphics.restore();
  }
}


/// BEST APPROACH: Use text matrix transformation for perfect scaling
/// This is the PDF specification's intended method for fitting text
static Future<void> _addInvisibleTextLayerWithMatrix({
  required sf.PdfPage page,
  required List<OcrTextBlock> blocks,
  required double imageWidth,
  required double imageHeight,
  required double pdfWidth,
  required double pdfHeight,
}) async {
  final scaleX = pdfWidth / imageWidth;
  final scaleY = pdfHeight / imageHeight;

  for (final block in blocks) {
    final text = block.text?.trim() ?? '';
    if (text.isEmpty) continue;

    final box = block.boundingBox;
    
    // Transform to PDF coordinates
    final pdfX = box.left * scaleX;
    final pdfY = box.top * scaleY;
    final pdfW = box.width * scaleX;
    final pdfH = box.height * scaleY;
    
    if (pdfW <= 0 || pdfH <= 0) continue;

    // Use a standard font size
    final baseFontSize = 12.0;
    final font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, baseFontSize);
    
    // Measure text at base size
    final textSize = font.measureString(text);
    
    if (textSize.width <= 0 || textSize.height <= 0) continue;
    
    // Calculate scale factors to fit text into bounding box
    final scaleTextX = pdfW / textSize.width;
    final scaleTextY = pdfH / textSize.height;
    
    // Save graphics state
    page.graphics.save();
    
    // Apply transformation matrix: scale then translate
    // This stretches/compresses the text to fit perfectly
    page.graphics.translateTransform(pdfX, pdfY);
    // page.graphics.scaleTransform(scaleTextX, scaleTextY);
    
    // Draw at origin (transformation moves it to correct position)
    final brush = sf.PdfSolidBrush(sf.PdfColor(0, 0, 0, 0));
    page.graphics.drawString(
      text,
      font,
      brush: brush,
      bounds: ui.Rect.fromLTWH(0, 0, textSize.width, textSize.height),
      format: sf.PdfStringFormat(
        alignment: sf.PdfTextAlignment.left,
        lineAlignment: sf.PdfVerticalAlignment.top,
      ),
    );
    
    // Restore graphics state
    page.graphics.restore();
    
    print('  ✓ "$text" @ (${pdfX.toStringAsFixed(1)}, ${pdfY.toStringAsFixed(1)}) '
          'scale=(${scaleTextX.toStringAsFixed(2)}x, ${scaleTextY.toStringAsFixed(2)}x)');
  }
}
}
