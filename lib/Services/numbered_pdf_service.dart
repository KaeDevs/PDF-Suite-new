import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Numbering modes for page numbering overlay
enum PageNumberFormat {
  topLeft,
  topCenter,
  topRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
  customOffset,
}

/// Numbering type (which pages to number)
enum NumberingType {
  continuous,    // All pages: 1, 2, 3, 4...
  oddOnly,       // Odd pages only: 1, 3, 5...
  evenOnly,      // Even pages only: 2, 4, 6...
  customRange,   // Custom range: e.g., pages 5-10
}

class NumberedPdfService {
  static Future<File> generateNumberedPdf({
    required List<String> inputs,
    required PageNumberFormat numberFormat,
    NumberingType numberingType = NumberingType.continuous,
    int? rangeStart,
    int? rangeEnd,
    bool insertBlankAfterEveryPage = true,
    ({double dx, double dy})? customOffset,
    String? spacerPdf,
  }) async {
    final PdfDocument result = PdfDocument();

    void _drawOutlinedTextElement({
      required PdfPage page,
      required String text,
      required PdfFont font,
      required double x,
      required double y,
      PdfBrush? fill,
      PdfBrush? stroke,
      double spread = 1.5,
    }) {
      // Use white fill with black stroke for maximum visibility on any background
      final PdfBrush fillBrush = fill ?? PdfBrushes.white;
      final PdfBrush strokeBrush = stroke ?? PdfBrushes.black;
      
      // Draw outline strokes in 8 directions for better visibility
      final offsets = <ui.Offset>[
        ui.Offset(-spread, -spread),
        ui.Offset(0, -spread),
        ui.Offset(spread, -spread),
        ui.Offset(-spread, 0),
        ui.Offset(spread, 0),
        ui.Offset(-spread, spread),
        ui.Offset(0, spread),
        ui.Offset(spread, spread),
      ];
      
      for (final o in offsets) {
        page.graphics.drawString(
          text,
          font,
          brush: strokeBrush,
          bounds: ui.Rect.fromLTWH(x + o.dx, y + o.dy, 0, 0),
        );
      }
      
      // Draw the fill text on top
      page.graphics.drawString(
        text,
        font,
        brush: fillBrush,
        bounds: ui.Rect.fromLTWH(x, y, 0, 0),
      );
    }

    void _addBlankPage({ui.Size? likeSize}) {
      if (likeSize != null) {
        final oldSize = result.pageSettings.size;
        result.pageSettings.size = likeSize;
        result.pages.add();
        result.pageSettings.size = oldSize;
      } else {
        result.pages.add();
      }
    }

    PdfDocument? spacerDoc;
    if (spacerPdf != null && spacerPdf.isNotEmpty) {
      final spacerBytes = await File(spacerPdf).readAsBytes();
      spacerDoc = PdfDocument(inputBytes: spacerBytes);
    }

    for (final path in inputs) {
      final lower = path.toLowerCase();
      if (lower.endsWith('.pdf')) {
        final bytes = await File(path).readAsBytes();
        final PdfDocument src = PdfDocument(inputBytes: bytes);

        for (int i = 0; i < src.pages.count; i++) {
          final srcPage = src.pages[i];
          final newPage = result.pages.add();

          final PdfTemplate template = srcPage.createTemplate();
          newPage.graphics.drawPdfTemplate(
            template,
            const ui.Offset(0, 0),
            ui.Size(newPage.size.width, newPage.size.height),
          );

          if (insertBlankAfterEveryPage) {
            if (spacerDoc != null && spacerDoc.pages.count > 0) {
              final tpl = spacerDoc.pages[0].createTemplate();
              final blankPage = result.pages.add();
              blankPage.graphics.drawPdfTemplate(
                tpl,
                const ui.Offset(0, 0),
                ui.Size(blankPage.size.width, blankPage.size.height),
              );
            } else {
              _addBlankPage(likeSize: ui.Size(srcPage.size.width, srcPage.size.height));
            }
          }
        }
        src.dispose();
      } else if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp') || lower.endsWith('.bmp')) {
        final bytes = await File(path).readAsBytes();
        final img = PdfBitmap(bytes);
        final page = result.pages.add();
        page.graphics.drawImage(
          img,
          ui.Rect.fromLTWH(0, 0, page.size.width, page.size.height),
        );
        if (insertBlankAfterEveryPage) {
          _addBlankPage(likeSize: ui.Size(page.size.width, page.size.height));
        }
      }
    }

    final font = PdfStandardFont(
      PdfFontFamily.helvetica,
      24,
      style: PdfFontStyle.bold,
    );

    for (int i = 0; i < result.pages.count; i++) {
      final page = result.pages[i];
      final pageNumber = i + 1;
      
      // Check if this page should be numbered based on numbering type
      bool shouldNumber = false;
      switch (numberingType) {
        case NumberingType.continuous:
          shouldNumber = true;
          break;
        case NumberingType.oddOnly:
          shouldNumber = pageNumber % 2 == 1;
          break;
        case NumberingType.evenOnly:
          shouldNumber = pageNumber % 2 == 0;
          break;
        case NumberingType.customRange:
          final start = rangeStart ?? 1;
          final end = rangeEnd ?? result.pages.count;
          shouldNumber = pageNumber >= start && pageNumber <= end;
          break;
      }
      
      if (!shouldNumber) continue;
      
      final number = pageNumber.toString();
      final size = page.size;
      
      // Calculate text size for proper positioning
      final textSize = font.measureString(number);
      const marginX = 24.0;
      const marginY = 24.0;

      switch (numberFormat) {
        case PageNumberFormat.topLeft:
          {
            _drawOutlinedTextElement(
              page: page,
              text: number,
              font: font,
              x: marginX,
              y: marginY,
            );
          }
          break;
        case PageNumberFormat.topCenter:
          {
            _drawOutlinedTextElement(
              page: page,
              text: number,
              font: font,
              x: (size.width - textSize.width) / 2.3,
              y: marginY,
            );
          }
          break;
        case PageNumberFormat.topRight:
          {
            _drawOutlinedTextElement(
              page: page,
              text: number,
              font: font,
              x: size.width - textSize.width - marginX - 120, // Based on your findings: 450 works on ~595pt page
              y: marginY,
            );
          }
          break;
        case PageNumberFormat.bottomLeft:
          {
            _drawOutlinedTextElement(
              page: page,
              text: number,
              font: font,
              x: marginX,
              y: 700, // Based on your findings: 700 works on ~842pt page (A4 height)
            );
          }
          break;
        case PageNumberFormat.bottomCenter:
          {
            _drawOutlinedTextElement(
              page: page,
              text: number,
              font: font,
              x: (size.width - textSize.width) / 2.3,
              y: 700,
            );
          }
          break;
        case PageNumberFormat.bottomRight:
          {
            _drawOutlinedTextElement(
              page: page,
              text: number,
              font: font,
              x: size.width - textSize.width - marginX - 120,
              y: 700,
            );
          }
          break;
        case PageNumberFormat.customOffset:
          final dx = customOffset?.dx ?? 24;
          final dy = customOffset?.dy ?? 24;
          {
            _drawOutlinedTextElement(
              page: page,
              text: number,
              font: font,
              x: dx,
              y: dy,
            );
          }
          break;
      }
    }

    final bytes = Uint8List.fromList(await result.save());
    result.dispose();
    final dir = await getTemporaryDirectory();
    final outPath = p.join(dir.path, 'numbered_${DateTime.now().millisecondsSinceEpoch}.pdf');
    final outFile = File(outPath);
    await outFile.writeAsBytes(bytes, flush: true);
    return outFile;
  }
}
