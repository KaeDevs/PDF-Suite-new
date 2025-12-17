import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/file_utils.dart';
import 'media_store_service.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';



class FileService {
  static Future<void> shareFile(File file, String type) async {
    final fileName = FileUtils.getFileName(file.path);
    await Share.shareXFiles(
      [XFile(file.path, name: fileName)],
      text: 'Shared via PDF-Suite',
    );
  }



static Future<void> openFileLocation(String filePath) async {
  try {
    final directory = p.dirname(filePath);
    final file = File(filePath);
    
    // Check if file exists
    if (!await file.exists()) {
      debugPrint('File does not exist: $filePath');
      return;
    }
    
    if (Platform.isAndroid) {
      // On Android, open the file with the system file manager
      // This will show the file in context of its directory
      final result = await OpenFilex.open(
        filePath,
        type: 'application/*', // Generic type to show file options
      );
      
      if (result.type != ResultType.done) {
        debugPrint('Failed to open file location: ${result.message}');
        
        // Fallback: Try to open just the directory
        final dirResult = await OpenFilex.open(directory);
        if (dirResult.type != ResultType.done) {
          debugPrint('Failed to open directory: ${dirResult.message}');
        }
      }
    } else if (Platform.isIOS) {
      // On iOS, use Share sheet to show file options
      // This allows user to save to Files app or share
      final result = await Share.shareXFiles(
        [XFile(filePath)],
        text: 'File: ${p.basename(filePath)}',
      );
      
      if (result.status == ShareResultStatus.unavailable) {
        debugPrint('Share unavailable on iOS');
      }
    } else {
      // For other platforms (Desktop)
      final result = await OpenFilex.open(directory);
      if (result.type != ResultType.done) {
        debugPrint('Failed to open directory: ${result.message}');
      }
    }
  } catch (e) {
    debugPrint('Error opening file location: $e');
  }
}

// Alternative: Show file in a custom file picker/manager
static Future<void> openFileLocationWithDialog(
  BuildContext context,
  String filePath,
) async {
  try {
    final directory = p.dirname(filePath);
    final fileName = p.basename(filePath);
    
    if (Platform.isAndroid) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('File Location'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Directory: $directory'),
              const SizedBox(height: 8),
              Text('File: $fileName'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await OpenFilex.open(filePath);
              },
              child: const Text('Open File'),
            ),
          ],
        ),
      );
    } else if (Platform.isIOS) {
      await Share.shareXFiles([XFile(filePath)]);
    }
  } catch (e) {
    debugPrint('Error opening file location with dialog: $e');
  }
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