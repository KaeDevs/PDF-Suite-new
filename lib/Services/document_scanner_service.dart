import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:file_picker/file_picker.dart';

class DocumentScannerService {
  static Future<List<String>> scanDocuments() async {
    try {
      final scannedImages = await CunningDocumentScanner.getPictures();
      return scannedImages ?? [];
    } catch (e) {
      throw Exception('Failed to scan documents: $e');
    }
  }

  static Future<List<String>> pickFromFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        return result.paths
            .where((path) => path != null)
            .cast<String>()
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to pick files: $e');
    }
  }

  static Future<List<String>> pickPdfFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        return result.paths
            .where((path) => path != null)
            .cast<String>()
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to pick PDF files: $e');
    }
  }
}