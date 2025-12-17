import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import '../Services/document_scanner_service.dart';
import '../Services/file_service.dart';
import '../Services/ocr_pdf_service.dart';
import '../Services/ocr_engine.dart';
import '../Services/mlkit_ocr_engine.dart';
import '../Services/ad_service.dart';
import '../Utils/tools.dart';
import '../Widgets/common/custom_snackbar.dart';
import '../Widgets/dialogs/export_dialog.dart';

class OcrPdfScreen extends StatefulWidget {
  const OcrPdfScreen({super.key});

  @override
  State<OcrPdfScreen> createState() => _OcrPdfScreenState();
}

class _OcrPdfScreenState extends State<OcrPdfScreen> with SingleTickerProviderStateMixin {
  final AdService _adService = AdService();
  final List<String> _inputs = [];
  bool _loading = false;
  String? _progressText;
  double? _progressValue;

  // Tab controller
  late TabController _tabController;

  // View mode settings
  bool _isGridView = false;
  int _gridCount = 3;
  final Map<String, Uint8List> _thumbCache = {};
  final Map<String, PageType?> _pageTypeCache = {}; // Classification cache

  // OCR settings
  String _language = 'latin'; // ML Kit script
  bool _forceOcrAll = false; // OCR all pages even if they have text

  // Language options
  final _languageOptions = {
    'latin': 'English / Latin',
    'chinese': 'Chinese',
    'devanagari': 'Hindi / Devanagari',
    'japanese': 'Japanese',
    'korean': 'Korean',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _adService.loadInterstitialAd();
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _adService.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 0) {
      _classifyPagesIfNeeded();
    }
    setState(() {});
  }

  Future<void> _classifyPagesIfNeeded() async {
    if (_inputs.isEmpty) return;
    for (final path in _inputs) {
      if (!_pageTypeCache.containsKey(path)) {
        _classifyPage(path);
      }
    }
  }

  Future<void> _classifyPage(String path) async {
    try {
      final pages = await OcrPdfService.classifyPages([path]);
      if (pages.isNotEmpty && mounted) {
        setState(() {
          _pageTypeCache[path] = pages.first.type;
        });
      }
    } catch (e) {
      // Ignore classification errors
    }
  }

  Future<bool> _showOcrPreview() async {
    print('🔬 Starting OCR preview...');
    
    try {
      // Run OCR on first file to show preview
      final ocrEngine = MlKitOcrEngine(script: _language);
      final StringBuffer allText = StringBuffer();
      
      print('Processing ${_inputs.length} files for preview...');
      
      for (int i = 0; i < _inputs.length && i < 3; i++) {
        final path = _inputs[i];
        print('Preview: Processing file $i: $path');
        
        final lower = path.toLowerCase();
        Uint8List? imageBytes;
        
        if (lower.endsWith('.pdf')) {
          final doc = await PdfDocument.openFile(path);
          final page = await doc.getPage(1);
          final pageImage = await page.render(
            width: page.width * 2,
            height: page.height * 2,
            format: PdfPageImageFormat.png,
          );
          imageBytes = pageImage?.bytes;
          await page.close();
          await doc.close();
        } else {
          imageBytes = await File(path).readAsBytes();
        }
        
        if (imageBytes != null) {
          print('Image bytes: ${imageBytes.length}');
          final result = await ocrEngine.recognizeText(imageBytes, language: _language);
          allText.writeln('=== File ${i + 1}: ${p.basename(path)} ===');
          allText.writeln(result.text);
          allText.writeln('');
          print('Extracted ${result.text.length} characters, ${result.blocks.length} blocks');
        }
      }
      
      await ocrEngine.dispose();
      
      if (!mounted) return false;
      
      final extractedText = allText.toString();
      print('Total extracted text length: ${extractedText.length}');
      
      // Show dialog with extracted text
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('OCR Preview'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: SelectableText(
                extractedText.isEmpty 
                    ? 'No text detected. The pages might be blank or the OCR failed.'
                    : extractedText,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ),
          actions: [
            IconButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: extractedText));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Text copied to clipboard'),
                      ],
                    ),
                    duration: Duration(seconds: 2),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: const Icon(Icons.copy),
              tooltip: 'Copy to clipboard',
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue to Generate PDF'),
            ),
          ],
        ),
      );
      
      return result ?? false;
    } catch (e) {
      print('❌ OCR Preview error: $e');
      if (!mounted) return false;
      CustomSnackbar.showError(context, 'OCR preview failed: $e');
      return false;
    }
  }

  Future<void> _takePicture() async {
    final scanned = await DocumentScannerService.scanDocuments();
    if (scanned.isNotEmpty) {
      setState(() {
        _inputs.addAll(scanned);
        // Scanned images are always scanned type
        for (final img in scanned) {
          _pageTypeCache[img] = PageType.scanned;
        }
      });
    }
  }

  

  Future<void> _addImages() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Image'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Picture'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pick from Gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
          ],
        ),
      ),
    );

    if (choice == null) return;

    if (choice == 'camera') {
      await _takePicture();
    } else {
      final picked = await DocumentScannerService.pickFromFiles();
      if (picked.isNotEmpty) {
        setState(() {
          _inputs.addAll(picked);
          // Images are always scanned
          for (final img in picked) {
            _pageTypeCache[img] = PageType.scanned;
          }
        });
      }
    }
  }

  Future<void> _generate() async {
    if (_inputs.isEmpty) {
      CustomSnackbar.showError(context, 'Please add at least one PDF or image');
      return;
    }

    // First, show OCR preview
    // final shouldContinue = await _showOcrPreview();
    // if (!shouldContinue) return;

    setState(() {
      _loading = true;
      _progressText = 'Initializing OCR...';
      _progressValue = null;
    });

    OcrEngine? ocrEngine;
    try {
      ocrEngine = MlKitOcrEngine(script: _language);

      final task = OcrPdfService.generateSearchablePdf(
        inputs: _inputs,
        ocrEngine: ocrEngine,
        language: _language,
        forceOcrAll: _forceOcrAll,
        onProgress: (progress, message) {
          if (mounted) {
            setState(() {
              _progressValue = progress;
              _progressText = message;
            });
          }
        },
      );

      print('🎯 Starting PDF generation...');
      final file = await _adService.showAdWhileFuture(task);
      print('✅ PDF generation complete: ${file.path}');

      if (!mounted) return;
      setState(() {
        _loading = false;
        _progressText = null;
        _progressValue = null;
      });

      await showModalBottomSheet(
        context: context,
        builder: (ctx) => ExportDialog(
          // onPreviewPdf: () async {
          //   Navigator.pop(ctx);
          //   // Open PDF for preview
          //   // await (file);
          // },
          onSharePdf: () async {
            Navigator.pop(ctx);
            await FileService.shareFile(file, 'pdf');
          },
          onSavePdf: () async {
            Navigator.pop(ctx);
            final saved = await FileService.saveToDownloads(file);
            if (!mounted) return;
            CustomSnackbar.showSuccess(context, 'Saved to: ${saved.path}');
            // await FileService.openFileLocation(saved.path);
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _progressText = null;
        _progressValue = null;
      });
      CustomSnackbar.showError(context, 'OCR failed: $e');
    } finally {
      await ocrEngine?.dispose();
    }
  }

  void _showViewModePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('View Mode'),
        content: StatefulBuilder(
          builder: (context, setModalState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('List View'),
                leading: Radio<bool>(
                  value: false,
                  groupValue: _isGridView,
                  onChanged: (v) {
                    setState(() => _isGridView = false);
                    Navigator.pop(context);
                  },
                ),
              ),
              ListTile(
                title: const Text('Grid View'),
                leading: Radio<bool>(
                  value: true,
                  groupValue: _isGridView,
                  onChanged: (v) {
                    setState(() => _isGridView = true);
                    Navigator.pop(context);
                  },
                ),
              ),
              if (_isGridView) ...[
                const Divider(),
                const Text('Grid Columns', style: TextStyle(fontWeight: FontWeight.bold)),
                Slider(
                  min: 2,
                  max: 4,
                  divisions: 2,
                  label: '$_gridCount',
                  value: _gridCount.toDouble(),
                  onChanged: (v) {
                    setModalState(() => _gridCount = v.toInt());
                    setState(() => _gridCount = v.toInt());
                  },
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR'),
        actions: [
          if (_tabController.index == 0)
            IconButton(
              onPressed: _showViewModePicker,
              icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view, color: Colors.white),
              tooltip: 'View mode',
            ),
        ],
        // bottom: TabBar(
        //   controller: _tabController,
        //   tabs: [
        //     Tab(
        //       icon: const Icon(Icons.photo_library, color: Colors.white),
        //       child: Text("Pages", style: Tools.h3(context).copyWith(fontSize: 15)),
        //     ),
        //     Tab(
        //       icon: const Icon(Icons.settings, color: Colors.white),
        //       child: Text("How To", style: Tools.h3(context).copyWith(fontSize: 15)),
        //     ),
        //   ],
        // ),
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_progressValue != null)
                    CircularProgressIndicator(value: _progressValue)
                  else
                    const CircularProgressIndicator(),
                  if (_progressText != null) ...[
                    const SizedBox(height: 12),
                    Text(_progressText!),
                  ]
                ],
              ),
            )
          : 
                _buildPagesTab(),
                
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _generate,
        icon: const Icon(Icons.auto_fix_high),
        label: const Text('Generate'),
      ),
    );
  }

  Widget _buildPagesTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.surfaceVariant,
          child: Row(
            children: [
              //   Expanded(
              //   child: ElevatedButton.icon(
              //     onPressed: _loading ? null : () async {
              //       final picked = await DocumentScannerService.pickPdfFiles();
              //       if (picked.isNotEmpty) {
              //         setState(() {
              //           _inputs.addAll(picked);
              //           // PDFs need classification
              //         });
              //       }
              //     },
              //     icon: const Icon(Icons.picture_as_pdf),
              //     label: const Text('Add PDFs'),
              //     style: ElevatedButton.styleFrom(
              //     padding: const EdgeInsets.symmetric(vertical: 12),
              //     ),
              //   ),
              //   ),
              // const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _addImages,
                  icon: const Icon(Icons.image),
                  label: const Text('Add Images'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _inputs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_fix_high_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No files added yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add scanned PDFs or images to make them searchable',
                          style: TextStyle(color: Colors.grey.shade500),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : _isGridView
                  ? _buildGridView()
                  : _buildListView(),
        ),
      ],
    );
  }

  Widget _buildListView() {
    return ReorderableListView.builder(
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final item = _inputs.removeAt(oldIndex);
          _inputs.insert(newIndex, item);
        });
      },
      itemCount: _inputs.length,
      itemBuilder: (context, index) {
        final path = _inputs[index];
        final name = p.basename(path);
        final type = _pageTypeCache[path];
        
        return Card(
          key: ValueKey(path),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.drag_handle),
                const SizedBox(width: 8),
                Icon(_getFileIcon(path)),
                if (type != null) ...[
                  const SizedBox(width: 4),
                  _buildClassificationBadge(type),
                ],
              ],
            ),
            title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => setState(() {
                _inputs.removeAt(index);
                _pageTypeCache.remove(path);
                _thumbCache.remove(path);
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridView() {
    return ReorderableGridView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _inputs.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final item = _inputs.removeAt(oldIndex);
          _inputs.insert(newIndex, item);
        });
      },
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _gridCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.7,
      ),
      itemBuilder: (context, index) {
        final path = _inputs[index];
        final name = p.basename(path);
        final type = _pageTypeCache[path];
        
        return Card(
          key: ValueKey(path),
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: _buildThumbnail(path),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Icon(_getFileIcon(path), size: 16),
                        const SizedBox(width: 4),
                        if (type != null) _buildClassificationBadge(type),
                        const Spacer(),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                    onPressed: () => setState(() {
                      _inputs.removeAt(index);
                      _pageTypeCache.remove(path);
                      _thumbCache.remove(path);
                    }),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThumbnail(String path) {
    if (_thumbCache.containsKey(path)) {
      return Image.memory(_thumbCache[path]!, fit: BoxFit.contain);
    }

    _generateThumbnail(path);
    return Container(
      color: Colors.grey.shade200,
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Future<void> _generateThumbnail(String path) async {
    try {
      final lower = path.toLowerCase();
      Uint8List? thumb;

      if (lower.endsWith('.pdf')) {
        final doc = await PdfDocument.openFile(path);
        final page = await doc.getPage(1);
        final pageImage = await page.render(
          width: page.width * 0.5,
          height: page.height * 0.5,
          format: PdfPageImageFormat.png,
        );
        thumb = pageImage?.bytes;
        await page.close();
        await doc.close();
      } else {
        thumb = await File(path).readAsBytes();
      }

      if (thumb != null && mounted) {
        setState(() => _thumbCache[path] = thumb!);
      }
    } catch (e) {
      // Ignore thumbnail errors
    }
  }

  Widget _buildClassificationBadge(PageType type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: type == PageType.textBased ? Colors.green : Colors.orange,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type == PageType.textBased ? '✅ Text' : '📷 Scan',
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  IconData _getFileIcon(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf;
    return Icons.image;
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Language selection
        // Card(
        //   child: Padding(
        //     padding: const EdgeInsets.all(16),
        //     child: Column(
        //       crossAxisAlignment: CrossAxisAlignment.start,
        //       children: [
        //         Text(
        //           'Language',
        //           style: Theme.of(context).textTheme.titleMedium?.copyWith(
        //                 fontWeight: FontWeight.bold,
        //               ),
        //         ),
        //         const SizedBox(height: 8),
        //         const Text(
        //           'Select the primary language in your documents',
        //           style: TextStyle(color: Colors.grey),
        //         ),
        //         const SizedBox(height: 12),
        //         DropdownButtonFormField<String>(
        //           value: _language,
        //           decoration: const InputDecoration(
        //             border: OutlineInputBorder(),
        //             contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        //           ),
        //           items: _languageOptions.entries
        //               .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
        //               .toList(),
        //           onChanged: (v) => setState(() => _language = v ?? 'latin'),
        //         ),
        //       ],
        //     ),
        //   ),
        // ),
        // const SizedBox(height: 16),
        // // Force OCR all pages
        // Card(
        //   child: SwitchListTile(
        //     title: const Text('OCR All Pages'),
        //     subtitle: const Text(
        //       'Run OCR even on pages that already have text',
        //     ),
        //     value: _forceOcrAll,
        //     onChanged: (v) => setState(() => _forceOcrAll = v),
        //   ),
        // ),
        // const SizedBox(height: 24),
        // // Info card
        Card(
          color: Colors.blue.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'How it works',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  
                  '• Scan pages to be processed with OCR\n'
                  '• Output text can be copied\n'
                  // '• Processing runs in background without blocking UI\n'
                  // '• All OCR processing happens on your device',,
                  ,
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
