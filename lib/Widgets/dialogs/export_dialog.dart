import 'package:flutter/material.dart';

class ExportDialog extends StatelessWidget {
  final VoidCallback? onPreviewPdf;
  final VoidCallback onSharePdf;
  final VoidCallback onSavePdf;

  const ExportDialog({
    super.key,
    this.onPreviewPdf,
    required this.onSharePdf,
    required this.onSavePdf,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.visibility),
            title: const Text('Preview PDF'),
            onTap: onPreviewPdf,
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share PDF'),
            onTap: onSharePdf,
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Save to Device'),
            onTap: onSavePdf,
          ),
        ],
      ),
    );
  }
}