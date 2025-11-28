import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/file_utils.dart';
import 'media_store_service.dart';

class FileService {
  static Future<void> shareFile(File file, String type) async {
    final fileName = FileUtils.getFileName(file.path);
    await Share.shareXFiles(
      [XFile(file.path, name: fileName)],
      text: 'Shared via PDF-Suite',
    );
  }

  static Future<File> saveToDownloads(File file) async {
    if (Platform.isAndroid) {
      return await MediaStoreService.saveToDownloads(file);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = FileUtils.getFileName(file.path);
      final savedPath = '${dir.path}/$fileName';
      return await file.copy(savedPath);
    }
  }

  static Future<File> zipImages(List<String> imagePaths, String? baseName) async {
    final archive = Archive();

    for (int i = 0; i < imagePaths.length; i++) {
      final imagePath = imagePaths[i];
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final extension = FileUtils.inferExtension(imagePath);
      final fileName = 'image_${i + 1}$extension';
      
      final archiveFile = ArchiveFile(fileName, bytes.length, bytes);
      archive.addFile(archiveFile);
    }

    final zipData = ZipEncoder().encode(archive)!;
    final tempDir = await getTemporaryDirectory();
    final zipFileName = FileUtils.createZipFileName(baseName);
    final zipFile = File('${tempDir.path}/$zipFileName');
    await zipFile.writeAsBytes(zipData);
    
    return zipFile;
  }

  static Future<File> zipFiles(List<File> files, String baseName) async {
    final archive = Archive();

    for (final file in files) {
      final bytes = await file.readAsBytes();
      final name = FileUtils.getFileName(file.path);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    final zipData = ZipEncoder().encode(archive)!;
    final tempDir = await getTemporaryDirectory();
    final zipFile = File('${tempDir.path}/$baseName');
    await zipFile.writeAsBytes(zipData);
    return zipFile;
  }
}