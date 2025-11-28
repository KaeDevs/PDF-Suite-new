import 'dart:io';
import 'dart:typed_data';

class ImageUtils {
  static Future<Uint8List> readImageFile(String path) async {
    final file = File(path);
    return await file.readAsBytes();
  }

  static bool isHeicFile(String path) {
    final extension = path.toLowerCase();
    return extension.endsWith('.heic') || extension.endsWith('.heif');
  }

  static bool isValidImageFile(String path) {
    final extension = path.toLowerCase();
    return extension.endsWith('.jpg') ||
           extension.endsWith('.jpeg') ||
           extension.endsWith('.png') ||
           extension.endsWith('.webp') ||
           extension.endsWith('.heic') ||
           extension.endsWith('.heif');
  }
}