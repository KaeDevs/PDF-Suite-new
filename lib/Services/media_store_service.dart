import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/app_constants.dart';
import '../utils/file_utils.dart';

class MediaStoreService {
  static const MethodChannel _channel = MethodChannel(AppConstants.channelName);
  static const MethodChannel _legacyChannel = MethodChannel(AppConstants.legacyChannelName);

  static Future<File> saveToDownloads(File file) async {
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final fileName = FileUtils.getFileName(file.path);

      if (androidInfo.version.sdkInt >= 29) {
        return await _saveUsingMediaStore(file, fileName);
      } else {
        return await _saveLegacy(file);
      }
    } catch (e) {
      // print('Error saving file: $e');
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = FileUtils.getFileName(file.path);
      final fallbackPath = '${appDir.path}/$fileName';
      return await file.copy(fallbackPath);
    }
  }

  static Future<File> _saveUsingMediaStore(File file, String fileName) async {
    try {
      final bytes = await file.readAsBytes();
      
      final result = await _channel.invokeMethod('saveToDownloads', {
        'fileName': fileName,
        'bytes': bytes,
        'mimeType': 'application/pdf',
      });

      if (result == true) {
        return file;
      } else {
        throw Exception('MediaStore save failed');
      }
    } catch (e) {
      print('MediaStore error: $e');
      return await _saveLegacy(file);
    }
  }

  static Future<File> _saveLegacy(File file) async {
    final permission = await Permission.storage.request();
    if (!permission.isGranted) {
      throw Exception("Storage permission denied");
    }

    Directory? targetDir;

    if (Platform.isAndroid) {
      targetDir = Directory('/storage/emulated/0/Download');
      if (!await targetDir.exists()) {
        targetDir = Directory('/storage/emulated/0/Documents');
        if (!await targetDir.exists()) {
          targetDir = await getExternalStorageDirectory();
        }
      }
    } else {
      targetDir = await getApplicationDocumentsDirectory();
    }

    if (targetDir == null) {
      throw Exception("Could not access storage directory");
    }

    final fileName = FileUtils.getFileName(file.path);
    final savedPath = '${targetDir.path}/$fileName';

    await targetDir.create(recursive: true);
    final savedFile = await file.copy(savedPath);

    if (Platform.isAndroid) {
      try {
        await _legacyChannel.invokeMethod('scanFile', {'path': savedPath});
      } catch (e) {
        print('MediaScanner notification failed: $e');
      }
    }

    return savedFile;
  }
}