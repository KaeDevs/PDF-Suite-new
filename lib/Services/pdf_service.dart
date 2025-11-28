import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../constants/app_constants.dart';
import '../utils/file_utils.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'dart:ui' show Size, Offset;
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
      // Yield to keep UI responsive between heavy operations
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
            print('Failed to compress HEIC image: $path');
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

          // Fast path: if not compressing and already JPEG, avoid re-encoding
          final lower = path.toLowerCase();
          final isJpeg = lower.endsWith('.jpg') || lower.endsWith('.jpeg');
          if (!enableCompression && isJpeg) {
            processedBytes = bytes; // keep original
          } else {
            final decodedImage = img.decodeImage(bytes);
            if (decodedImage == null) {
              print('Failed to decode image: $path');
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
        print('Error processing image $path: $e');
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

  /// Merges multiple local PDF files into a single PDF preserving vector/text.
  static Future<File> mergePdfs(
    List<String> pdfPaths, {
    String? baseName,
    void Function(int current, int total)? onProgress,
    int targetLongSidePx = 1200,
  }) async {
    if (pdfPaths.isEmpty) {
      throw ArgumentError('No PDF files provided to merge');
    }
    // Count total pages for progress updates
    int totalPages = 0;
    final List<sf.PdfDocument> sources = [];
    for (final path in pdfPaths) {
      final bytes = await File(path).readAsBytes();
      final doc = sf.PdfDocument(inputBytes: bytes);
      totalPages += doc.pages.count;
      sources.add(doc);
    }

    int done = 0;
    final out = sf.PdfDocument();
    // Remove margins so template fits exactly
    out.pageSettings.margins.all = 0;
    for (final src in sources) {
      final count = src.pages.count;
      for (int i = 0; i < count; i++) {
        await Future.delayed(const Duration(milliseconds: 1));
        final srcPage = src.pages[i];
        final sz = srcPage.size; // Size from dart:ui
        out.pageSettings.size = Size(sz.width, sz.height);
        final newPage = out.pages.add();
        final template = srcPage.createTemplate();
        newPage.graphics.drawPdfTemplate(
          template,
          Offset.zero,
          Size(sz.width, sz.height),
        );
        done++;
        onProgress?.call(done, totalPages);
      }
    }

    final bytes = out.saveSync();
    out.dispose();
    for (final s in sources) {
      s.dispose();
    }

    final dir = await getTemporaryDirectory();
    final outName = (baseName?.isNotEmpty ?? false) ? baseName! : 'merged';
    final file = File('${dir.path}/$outName.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Merge pages in an explicit order defined by PageRef(filePath, pageNumber)
  static Future<File> mergePages(
    List<PageRef> pages, {
    String? baseName,
    void Function(int current, int total)? onProgress,
    int targetLongSidePx = 1200,
  }) async {
    if (pages.isEmpty) {
      throw ArgumentError('No pages provided to merge');
    }

    final totalPages = pages.length;
    int done = 0;

    // Cache opened documents (Syncfusion)
    final cache = <String, sf.PdfDocument>{};
    final out = sf.PdfDocument();
    out.pageSettings.margins.all = 0;

    for (final ref in pages) {
      await Future.delayed(const Duration(milliseconds: 1));
      final src = cache[ref.filePath] ??= sf.PdfDocument(
        inputBytes: await File(ref.filePath).readAsBytes(),
      );

      final idx = ref.pageNumber - 1; // zero-based
      final srcPage = src.pages[idx];
      final sz = srcPage.size;
      out.pageSettings.size = Size(sz.width, sz.height);
      final newPage = out.pages.add();
      final template = srcPage.createTemplate();
      newPage.graphics.drawPdfTemplate(
        template,
        Offset.zero,
        Size(sz.width, sz.height),
      );

      done++;
      onProgress?.call(done, totalPages);
    }

    final bytes = out.saveSync();
    out.dispose();
    for (final d in cache.values) {
      d.dispose();
    }

    final dir = await getTemporaryDirectory();
    final outName = (baseName?.isNotEmpty ?? false) ? baseName! : 'merged_pages';
    final file = File('${dir.path}/$outName.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}