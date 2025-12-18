import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;
import '../constants/app_constants.dart';
import '../utils/file_utils.dart';
import '../Modules/page_ref.dart';

class PdfService {
  static Future<File> convertImagesToPdf(
    List<String> imagePaths,
    String? fileName,
    bool enableCompression, {
    void Function(int current, int total)? onProgress,
    int? targetWidth,
  }) async {
    final pdf = pw.Document();

    final total = imagePaths.length;
    int done = 0;

    for (final path in imagePaths) {
      await Future.delayed(const Duration(milliseconds: 1));
      try {
        Uint8List processedBytes;

        if (path.toLowerCase().endsWith('.heic')) {
          final compressedBytes = await FlutterImageCompress.compressWithFile(
            path,
            quality: enableCompression ? 85 : 95,
            format: CompressFormat.jpeg,
          );

          if (compressedBytes == null) {
            continue;
          }

          processedBytes = compressedBytes;

          if (enableCompression) {
            final decodedImage = img.decodeImage(processedBytes);
            if (decodedImage != null) {
              final resized = img.copyResize(
                decodedImage,
                width: targetWidth ?? AppConstants.compressionWidth,
              );
              processedBytes = Uint8List.fromList(
                img.encodeJpg(resized, quality: AppConstants.compressionQuality),
              );
            }
          }
        } else {
          final bytes = await File(path).readAsBytes();
          if (bytes.isEmpty) continue;

          final lower = path.toLowerCase();
          final isJpeg = lower.endsWith('.jpg') || lower.endsWith('.jpeg');
          if (!enableCompression && isJpeg) {
            processedBytes = bytes;
          } else {
            final decodedImage = img.decodeImage(bytes);
            if (decodedImage == null) {
              continue;
            }

            if (enableCompression) {
              final resized = img.copyResize(
                decodedImage,
                width: targetWidth ?? AppConstants.compressionWidth,
              );
              processedBytes = Uint8List.fromList(
                img.encodeJpg(resized, quality: AppConstants.compressionQuality),
              );
            } else {
              processedBytes = Uint8List.fromList(
                img.encodeJpg(decodedImage, quality: 95),
              );
            }
          }
        }

        final image = pw.MemoryImage(processedBytes);
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            build: (context) => pw.Center(
              child: pw.FittedBox(
                fit: pw.BoxFit.contain,
                child: pw.Image(image),
              ),
            ),
          ),
        );
      } catch (e) {
        // continue
      }

      done++;
      onProgress?.call(done, total);
    }

    if (pdf.document.pdfPageList.pages.isEmpty) {
      throw Exception('No valid images could be processed for PDF creation');
    }

    final dir = await getTemporaryDirectory();
    final pdfFileName = FileUtils.createPdfFileName(fileName);
    final file = File('${dir.path}/$pdfFileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// Merges multiple local PDF files by converting each page to an image
  static Future<File> mergePdfs(
    List<String> pdfPaths, {
    String? baseName,
    void Function(int current, int total)? onProgress,
    int targetLongSidePx = 1200,
  }) async {
    if (pdfPaths.isEmpty) {
      throw ArgumentError('No PDF files provided to merge');
    }

    final pdf = pw.Document();
    int totalPages = 0;
    int processedPages = 0;

    // First, count total pages
    for (final pdfPath in pdfPaths) {
      try {
        final doc = await pdfx.PdfDocument.openFile(pdfPath);
        totalPages += doc.pagesCount;
        await doc.close();
      } catch (e) {
        // Skip files that can't be opened
        continue;
      }
    }

    // Process each PDF file
    for (final pdfPath in pdfPaths) {
      try {
        final doc = await pdfx.PdfDocument.openFile(pdfPath);
        
        // Process each page
        for (int i = 1; i <= doc.pagesCount; i++) {
          try {
            final page = await doc.getPage(i);
            
            // Calculate render dimensions maintaining aspect ratio
            final aspect = page.width / page.height;
            double renderWidth, renderHeight;
            if (aspect >= 1) {
              // Landscape
              renderWidth = targetLongSidePx.toDouble();
              renderHeight = targetLongSidePx / aspect;
            } else {
              // Portrait
              renderHeight = targetLongSidePx.toDouble();
              renderWidth = targetLongSidePx * aspect;
            }
            
            // Render page to image
            final pageImage = await page.render(
              width: renderWidth,
              height: renderHeight,
              format: pdfx.PdfPageImageFormat.jpeg,
              backgroundColor: '#FFFFFF',
            );
            
            await page.close();
            
            if (pageImage != null && pageImage.bytes.isNotEmpty) {
              final image = pw.MemoryImage(pageImage.bytes);
              pdf.addPage(
                pw.Page(
                  pageFormat: PdfPageFormat.a4,
                  margin: const pw.EdgeInsets.all(0),
                  build: (context) => pw.Center(
                    child: pw.Image(image, fit: pw.BoxFit.contain),
                  ),
                ),
              );
            }
            
            processedPages++;
            onProgress?.call(processedPages, totalPages);
          } catch (e) {
            // Skip pages that fail to render
            processedPages++;
            onProgress?.call(processedPages, totalPages);
            continue;
          }
        }
        
        await doc.close();
      } catch (e) {
        // Skip files that can't be opened
        continue;
      }
    }

    if (pdf.document.pdfPageList.pages.isEmpty) {
      throw Exception('No valid pages could be processed for PDF merging');
    }

    final dir = await getTemporaryDirectory();
    final pdfFileName = FileUtils.createPdfFileName(baseName);
    final file = File('${dir.path}/$pdfFileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// Merge pages in an explicit order
  static Future<File> mergePages(
    List<PageRef> pages, {
    String? baseName,
    void Function(int current, int total)? onProgress,
    int targetLongSidePx = 1200,
  }) async {
    if (pages.isEmpty) {
      throw ArgumentError('No pages provided to merge');
    }

    final pdf = pw.Document();
    final total = pages.length;
    int processed = 0;

    for (final pageRef in pages) {
      try {
        final doc = await pdfx.PdfDocument.openFile(pageRef.filePath);
        
        if (pageRef.pageNumber < 1 || pageRef.pageNumber > doc.pagesCount) {
          await doc.close();
          processed++;
          onProgress?.call(processed, total);
          continue;
        }
        
        final page = await doc.getPage(pageRef.pageNumber);
        
        // Calculate render dimensions maintaining aspect ratio
        final aspect = page.width / page.height;
        double renderWidth, renderHeight;
        if (aspect >= 1) {
          // Landscape
          renderWidth = targetLongSidePx.toDouble();
          renderHeight = targetLongSidePx / aspect;
        } else {
          // Portrait
          renderHeight = targetLongSidePx.toDouble();
          renderWidth = targetLongSidePx * aspect;
        }
        
        // Render page to image
        final pageImage = await page.render(
          width: renderWidth,
          height: renderHeight,
          format: pdfx.PdfPageImageFormat.jpeg,
          backgroundColor: '#FFFFFF',
        );
        
        await page.close();
        await doc.close();
        
        if (pageImage != null && pageImage.bytes.isNotEmpty) {
          final image = pw.MemoryImage(pageImage.bytes);
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(0),
              build: (context) => pw.Center(
                child: pw.Image(image, fit: pw.BoxFit.contain),
              ),
            ),
          );
        }
        
        processed++;
        onProgress?.call(processed, total);
      } catch (e) {
        // Skip pages that fail to render
        processed++;
        onProgress?.call(processed, total);
        continue;
      }
    }

    if (pdf.document.pdfPageList.pages.isEmpty) {
      throw Exception('No valid pages could be processed for PDF merging');
    }

    final dir = await getTemporaryDirectory();
    final pdfFileName = FileUtils.createPdfFileName(baseName);
    final file = File('${dir.path}/$pdfFileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
