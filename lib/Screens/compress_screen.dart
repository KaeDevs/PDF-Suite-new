import 'dart:io';

import 'package:docu_scan/Services/document_scanner_service.dart';
import 'package:docu_scan/Services/file_service.dart';
import 'package:docu_scan/Services/pdf_compression_service.dart';
import 'package:docu_scan/Widgets/common/custom_snackbar.dart';
import 'package:docu_scan/Widgets/common/loading_overlay.dart';
import 'package:docu_scan/services/ad_service.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'output_screen.dart';

class CompressScreen extends StatefulWidget {
  const CompressScreen({super.key});

  @override
  State<CompressScreen> createState() => _CompressScreenState();
}

class _CompressScreenState extends State<CompressScreen> {
  final AdService _adService = AdService();
  final List<String> _selectedPdfPaths = [];
  PdfCompressionPreset _preset = PdfCompressionPreset.medium;
  PdfSizeTarget _sizeTarget = PdfSizeTarget.half;
  bool _useSizeMode = false; // Toggle between quality and size mode

  bool _isLoading = false;
  String? _loadingText;

  @override
  void initState() {
    super.initState();
    _adService.loadInterstitialAd();
  }

  @override
  void dispose() {
    _adService.dispose();
    super.dispose();
  }

  Future<void> _pickPdfs() async {
    try {
      final files = await DocumentScannerService.pickPdfFiles();
      if (files.isEmpty) return;
      setState(() => _selectedPdfPaths
        ..clear()
        ..addAll(files));
      CustomSnackbar.showSuccess(context, 'Selected ${files.length} file(s).');
    } catch (e) {
      CustomSnackbar.showError(context, 'Failed to pick PDFs: $e');
    }
  }

  Future<void> _compressAndNavigate() async {
    if (_selectedPdfPaths.isEmpty) return;
    setState(() {
      _isLoading = true;
      _loadingText = 'Compressing…';
    });

    try {
      // Start compression in background and show ad while processing
      final compressionFuture = _useSizeMode
          ? PdfCompressionService.compressBatchBySize(
              _selectedPdfPaths,
              sizeTarget: _sizeTarget,
              onProgress: (i, total) {
                if (mounted) {
                  setState(() => _loadingText = 'Compressing $i of $total…');
                }
              },
            )
          : PdfCompressionService.compressBatch(
              _selectedPdfPaths,
              preset: _preset,
              onProgress: (i, total) {
                if (mounted) {
                  setState(() => _loadingText = 'Compressing $i of $total…');
                }
              },
            );

      // Show ad while compression runs in background
      final outputs = await _adService.showAdWhileFuture(compressionFuture);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadingText = null;
      });

      File outputFile;
      String title;

      if (outputs.length == 1) {
        outputFile = outputs.first;
        title = 'Compressed PDF';
      } else {
        final zipName = _zipNameForBatch(outputs);
        outputFile = await FileService.zipFiles(outputs, zipName);
        title = 'Compressed PDFs (ZIP)';
      }

      // Navigate to output screen
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OutputScreen(
            pdfFile: outputFile,
            customTitle: _zipNameForBatch(outputs),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingText = null;
        });
        CustomSnackbar.showError(context, 'Compression failed: $e');
      }
    }
  }

  String _zipNameForBatch(List<File> files) {
    if (files.isEmpty) return 'compressed_pdfs.zip';
    final base = p.basenameWithoutExtension(files.first.path);
    return base.endsWith('_compressed') ? '$base.zip' : '${base}_compressed.zip';
  }

  void _showCompressionInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Compression Methods'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Quality Mode',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                '• Low: Aggressive compression with smaller file size but reduced image quality\n'
                '• Medium: Balanced compression maintaining good quality while reducing size\n',
              ),
              SizedBox(height: 16),
              Text(
                'Target Size Mode',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                '• 25%: Compress to 1/4 of original size (most aggressive)\n'
                '• 50%: Compress to half of original size (recommended)\n'
                '• 75%: Compress to 3/4 of original size (light compression)\n',
              ),
              SizedBox(height: 8),
              // Text(
              //   'How It Works',
              //   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              // ),
              // SizedBox(height: 8),
              // Text(
              //   'PDFs are compressed by converting each page to optimized JPEG images and rebuilding the document. This method works best for scanned documents and image-based PDFs.\n\n'
              //   'Note: Text searchability may be reduced after compression.',
              //   style: TextStyle(fontSize: 13, color: Colors.grey),
              // ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Compress PDFs'),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: _showCompressionInfo,
              icon: const Icon(Icons.info_outline),
              tooltip: 'Compression Info',
            ),
          ],
        ),
        body: LoadingOverlay(
          isLoading: _isLoading,
          loadingText: _loadingText,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Mode toggle
                Row(
                  children: [
                    const Text('Mode:'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('Quality')),
                          ButtonSegment(value: true, label: Text('Target Size')),
                        ],
                        selected: {_useSizeMode},
                        onSelectionChanged: (s) => setState(() => _useSizeMode = s.first),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Conditional preset selector
                if (!_useSizeMode)
                  Row(
                    children: [
                      const Text('Quality:'),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SegmentedButton<PdfCompressionPreset>(
                          segments: const [
                            ButtonSegment(value: PdfCompressionPreset.low, label: Text('Low')),
                            ButtonSegment(value: PdfCompressionPreset.medium, label: Text('Medium')),
                          ],
                          selected: {_preset},
                          onSelectionChanged: (s) => setState(() => _preset = s.first),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      const Text('Target Size:'),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SegmentedButton<PdfSizeTarget>(
                          segments: const [
                            ButtonSegment(value: PdfSizeTarget.quarter, label: Text('25%')),
                            ButtonSegment(value: PdfSizeTarget.half, label: Text('50%')),
                            ButtonSegment(value: PdfSizeTarget.threeQuarter, label: Text('75%')),
                          ],
                          selected: {_sizeTarget},
                          onSelectionChanged: (s) => setState(() => _sizeTarget = s.first),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                // Pick files button
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _pickPdfs,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Select PDFs'),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _selectedPdfPaths.isEmpty
                      ? Center(
                          child: Text(
                            'No PDFs selected',
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _selectedPdfPaths.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final path = _selectedPdfPaths[index];
                            final name = p.basename(path);
                            return ListTile(
                              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                              title: Text(name),
                              subtitle: Text(path, maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(() => _selectedPdfPaths.removeAt(index)),
                                tooltip: 'Remove',
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isLoading || _selectedPdfPaths.isEmpty
                      ? null
                      : _compressAndNavigate,
                  icon: const Icon(Icons.compress),
                  label: const Text('Compress PDF'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
