import 'package:path/path.dart' as p;
import '../constants/app_constants.dart';

class FileUtils {
  static String inferExtension(String path) {
    final extension = p.extension(path).toLowerCase();
    switch (extension) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.webp':
      case '.heic':
      case '.heif':
        return extension;
      default:
        return '.jpg';
    }
  }

  static String getFileName(String fullPath) {
    return p.basename(fullPath);
  }

  static String createPdfFileName(String? baseName) {
    final name = baseName?.isNotEmpty == true ? baseName! : AppConstants.defaultFileName;
    // final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$name.pdf';
  }

  static String createZipFileName(String? baseName) {
    final name = baseName?.isNotEmpty == true ? baseName! : AppConstants.defaultFileName;
    // final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$name.zip';
  }

  static String createImageFileName(String fullPath, String? customName) {
    if (customName?.isNotEmpty == true) {
      return '$customName.jpg';
    }
    final baseName = p.basenameWithoutExtension(fullPath);
    return '$baseName.jpg';
  }
}