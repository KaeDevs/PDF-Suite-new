import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/pdf_view_page.dart';
import '../utils/file_utils.dart';

class PdfViewerService {
  static bool isPdfFile(String filePath) {
    return filePath.toLowerCase().endsWith('.pdf');
  }

  static Future<bool> canOpenPdf(String filePath) async {
    if (!isPdfFile(filePath)) return false;
    
    final file = File(filePath);
    return await file.exists();
  }

  static Future<void> openPdf(BuildContext context, String filePath, {String? title}) async {
    if (!await canOpenPdf(filePath)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot open PDF file'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final fileName = title ?? FileUtils.getFileName(filePath);
    
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PdfViewPage(
          filePath: filePath,
          title: fileName,
        ),
      ),
    );
  }
}