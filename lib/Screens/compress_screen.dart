import 'dart:io';

import 'package:docu_scan/Services/document_scanner_service.dart';
import 'package:docu_scan/Services/file_service.dart';
import 'package:docu_scan/Services/pdf_compression_service.dart';
import 'package:docu_scan/Widgets/common/custom_snackbar.dart';
import 'package:docu_scan/Widgets/common/loading_overlay.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class CompressScreen extends StatefulWidget {
  const CompressScreen({super.key});

  @override
  State<CompressScreen> createState() => _CompressScreenState();
}

class _CompressScreenState extends State<CompressScreen> {
  final List<String> _selectedPdfPaths = [];
  PdfCompressionPreset _preset = PdfCompressionPreset.medium;
  PdfSizeTarget _sizeTarget = PdfSizeTarget.half;
  bool _useSizeMode = false; // Toggle between quality and size mode

  bool _isLoading = false;
  String? _loadingText;

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

  Future<void> _compressAndExport({required bool saveOnly}) async {
    if (_selectedPdfPaths.isEmpty) return;
    setState(() {
      _isLoading = true;
      _loadingText = 'Compressing…';
    });

    try {
      final outputs = _useSizeMode
          ? await PdfCompressionService.compressBatchBySize(
              _selectedPdfPaths,
              sizeTarget: _sizeTarget,
              onProgress: (i, total) {
                if (mounted) {
                  setState(() => _loadingText = 'Compressing $i of $total…');
                }
              },
            )
          : await PdfCompressionService.compressBatch(
              _selectedPdfPaths,
              preset: _preset,
              onProgress: (i, total) {
                if (mounted) {
                  setState(() => _loadingText = 'Compressing $i of $total…');
                }
              },
            );

      if (outputs.length == 1) {
        final out = outputs.first;
        if (saveOnly) {
          final saved = await FileService.saveToDownloads(out);
          CustomSnackbar.showSuccess(context, 'Saved to: ${saved.path}');
        } else {
          await FileService.shareFile(out, 'pdf');
          CustomSnackbar.showSuccess(context, 'Compressed PDF shared.');
        }
      } else {
        final zipName = _zipNameForBatch(outputs);
        final zip = await FileService.zipFiles(outputs, zipName);
        if (saveOnly) {
          final saved = await FileService.saveToDownloads(zip);
          CustomSnackbar.showSuccess(context, 'Saved ZIP to: ${saved.path}');
        } else {
          await FileService.shareFile(zip, 'zip');
          CustomSnackbar.showSuccess(context, 'Compressed PDFs (ZIP) shared.');
        }
      }
    } catch (e) {
      CustomSnackbar.showError(context, 'Compression failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingText = null;
        });
      }
    }
  }

  String _zipNameForBatch(List<File> files) {
    if (files.isEmpty) return 'compressed_pdfs.zip';
    final base = p.basenameWithoutExtension(files.first.path);
    return base.endsWith('_compressed') ? '$base.zip' : '${base}_compressed.zip';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Compress PDFs'),
          centerTitle: true,
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
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isLoading || _selectedPdfPaths.isEmpty
                            ? null
                            : () => _compressAndExport(saveOnly: true),
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Save'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLoading || _selectedPdfPaths.isEmpty
                            ? null
                            : () => _compressAndExport(saveOnly: false),
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Share'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
