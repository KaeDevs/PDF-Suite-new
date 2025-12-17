import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
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

    // Note: The pdf package doesn't support importing existing PDFs directly.
    // You'll need to use pdf_render or similar to convert pages to images first.
    throw UnimplementedError(
      'PDF merging requires additional packages like pdf_render to convert pages to images',
    );
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

    throw UnimplementedError(
      'PDF page merging requires additional packages like pdf_render to convert pages to images',
    );
  }
}
