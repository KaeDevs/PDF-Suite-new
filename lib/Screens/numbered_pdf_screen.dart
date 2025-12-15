import 'dart:io';
import 'dart:typed_data';
import 'package:docu_scan/Utils/tools.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import '../Services/document_scanner_service.dart';
import '../Services/file_service.dart';
import '../Services/numbered_pdf_service.dart';
import '../services/ad_service.dart';
import '../Widgets/common/custom_snackbar.dart';
import '../Widgets/dialogs/export_dialog.dart';

class NumberedPdfScreen extends StatefulWidget {
  const NumberedPdfScreen({super.key});

  @override
  State<NumberedPdfScreen> createState() => _NumberedPdfScreenState();
}

class _NumberedPdfScreenState extends State<NumberedPdfScreen> with SingleTickerProviderStateMixin {
  final AdService _adService = AdService();
  final List<String> _inputs = [];
  bool _loading = false;
  String? _progressText;

  // Tab controller
  late TabController _tabController;

  // View mode settings
  bool _isGridView = false; // false = list, true = grid
  int _gridCount = 3; // columns when in grid mode (2-5)
  final Map<String, Uint8List> _thumbCache = {}; // thumbnail cache for grid view

  // Numbering options
  PageNumberFormat _format = PageNumberFormat.bottomRight;
  NumberingType _numberingType = NumberingType.continuous;
  bool _insertSpacer = false;
  double _customDx = 24;
  double _customDy = 24;
  int _rangeStart = 1;
  int _rangeEnd = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _adService.loadInterstitialAd();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _adService.dispose();
    super.dispose();
  }

  Future<void> _addPdfs() async {
    final picked = await DocumentScannerService.pickPdfFiles();
    if (picked.isNotEmpty) {
      setState(() => _inputs.addAll(picked));
    }
  }

  Future<void> _addImages() async {
    final picked = await DocumentScannerService.pickFromFiles();
    if (picked.isNotEmpty) {
      setState(() => _inputs.addAll(picked));
    }
  }

  Future<void> _generate() async {
    if (_inputs.isEmpty) {
      CustomSnackbar.showError(context, 'Please add at least one PDF or image');
      return;
    }
    setState(() {
      _loading = true;
      _progressText = 'Generating…';
    });

    try {
      final task = NumberedPdfService.generateNumberedPdf(
        inputs: _inputs,
        numberFormat: _format,
        numberingType: _numberingType,
        rangeStart: _numberingType == NumberingType.customRange ? _rangeStart : null,
        rangeEnd: _numberingType == NumberingType.customRange ? _rangeEnd : null,
        insertBlankAfterEveryPage: _insertSpacer,
        customOffset: _format == PageNumberFormat.customOffset
            ? (dx: _customDx, dy: _customDy)
            : null,
        spacerPdf: null, // Always use blank pages, not custom PDF
      );

      final file = await _adService.showAdWhileFuture(task);

      if (!mounted) return;
      setState(() {
        _loading = false;
        _progressText = null;
      });

      await showModalBottomSheet(
        context: context,
        builder: (ctx) => ExportDialog(
          onPreviewPdf: () async {
            Navigator.pop(ctx);
            // await FileService.openFile(file);
          },
          onSharePdf: () async {
            Navigator.pop(ctx);
            await FileService.shareFile(file, 'pdf');
          },
          onSavePdf: () async {
            Navigator.pop(ctx);
            final saved = await FileService.saveToDownloads(file);
            if (!mounted) return;
            CustomSnackbar.showSuccess(context, 'Saved to: ${saved.path}');
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _progressText = null;
      });
      CustomSnackbar.showError(context, 'Generation failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Numbered PDF'),
        actions: [
          // Show view mode picker only when on Pages tab
          if (_tabController.index == 0)
            IconButton(
              onPressed: _showViewModePicker,
              icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view, color: Colors.white,),
              tooltip: 'View mode',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          
          tabs: [
            Tab(icon: const Icon(Icons.photo_library, color: Colors.white,), child: Text("Pages", style: Tools.h3(context).copyWith(fontSize: 15),), ),
            Tab(icon: const Icon(Icons.settings, color: Colors.white,), child: Text("Settings", style: Tools.h3(context).copyWith(fontSize: 15),), ),
          ],
        ),
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  if (_progressText != null) ...[
                    const SizedBox(height: 12),
                    Text(_progressText!),
                  ]
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // Pages Tab
                _buildPagesTab(),
                // Settings Tab
                _buildSettingsTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _generate,
        icon: const Icon(Icons.format_list_numbered),
        label: const Text('Generate'),
      ),
    );
  }

  // Pages Tab - File selection and management
  Widget _buildPagesTab() {
    return Column(
      children: [
        // Add buttons toolbar
        Container(
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.surfaceVariant,
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _addPdfs,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Add PDFs'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
        // Files list
        Expanded(
          child: _inputs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No files added yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add PDFs or images to begin',
                          style: TextStyle(color: Colors.grey.shade500),
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

  // List view for files
  Widget _buildListView() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _inputs.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final f = _inputs.removeAt(oldIndex);
          _inputs.insert(newIndex, f);
        });
      },
      itemBuilder: (context, index) {
        final path = _inputs[index];
        final name = p.basename(path);
        final isPdf = path.toLowerCase().endsWith('.pdf');
        return Card(
          key: ValueKey(path),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              isPdf ? Icons.picture_as_pdf : Icons.image,
              color: isPdf ? Colors.red : Colors.blue,
              size: 32,
            ),
            title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text('${index + 1} of ${_inputs.length}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => setState(() => _inputs.removeAt(index)),
                  tooltip: 'Remove',
                ),
                const Icon(Icons.drag_handle, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }

  // Grid view for files
  Widget _buildGridView() {
    return ReorderableGridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _gridCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemCount: _inputs.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          final f = _inputs.removeAt(oldIndex);
          _inputs.insert(newIndex, f);
        });
      },
      itemBuilder: (context, index) {
        final path = _inputs[index];
        final isPdf = path.toLowerCase().endsWith('.pdf');
        return _buildGridTile(index, path, isPdf);
      },
    );
  }

  // Build individual grid tile with preview
  Widget _buildGridTile(int index, String path, bool isPdf) {
    return Card(
      key: ValueKey(path),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Preview image
          FutureBuilder<ImageProvider?>(
            future: _getPreview(path, isPdf),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                return Image(
                  image: snapshot.data!,
                  fit: BoxFit.cover,
                );
              } else if (snapshot.hasError) {
                return Container(
                  color: Colors.grey.shade200,
                  child: Icon(
                    isPdf ? Icons.picture_as_pdf : Icons.image,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                );
              } else {
                return Container(
                  color: Colors.grey.shade100,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
            },
          ),
          // Overlay with page number
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          // Delete button
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.red,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: () => setState(() {
                  _thumbCache.remove(path);
                  _inputs.removeAt(index);
                }),
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Get preview/thumbnail for file
  Future<ImageProvider?> _getPreview(String path, bool isPdf) async {
    // Check cache first
    if (_thumbCache.containsKey(path)) {
      return MemoryImage(_thumbCache[path]!);
    }

    try {
      if (isPdf) {
        // Generate PDF thumbnail
        final doc = await PdfDocument.openFile(path);
        final page = await doc.getPage(1);
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: PdfPageImageFormat.png,
        );
        await page.close();
        await doc.close();
        
        if (pageImage != null) {
          _thumbCache[path] = pageImage.bytes;
          return MemoryImage(pageImage.bytes);
        }
      } else {
        // Load image file
        final file = File(path);
        final bytes = await file.readAsBytes();
        _thumbCache[path] = bytes;
        return MemoryImage(bytes);
      }
    } catch (e) {
      // Return null if thumbnail generation fails
      return null;
    }
    return null;
  }

  // Show view mode picker modal
  Future<void> _showViewModePicker() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Flexible(
            fit: FlexFit.loose,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'View Mode',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    _isGridView ? Icons.radio_button_off : Icons.radio_button_checked,
                    color: !_isGridView ? Theme.of(context).primaryColor : null,
                  ),
                  title: const Text('List View'),
                  subtitle: const Text('Traditional list with details'),
                  onTap: () => Navigator.pop(context, {'mode': 'list'}),
                ),
                ListTile(
                  leading: Icon(
                    !_isGridView ? Icons.radio_button_off : Icons.radio_button_checked,
                    color: _isGridView ? Theme.of(context).primaryColor : null,
                  ),
                  title: const Text('Grid View'),
                  subtitle: const Text('Visual grid layout'),
                  onTap: () => Navigator.pop(context, {'mode': 'grid'}),
                ),
                if (_isGridView) ...[
                  const Divider(height: 1),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Items per row',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  for (final n in [2, 3, 4, 5])
                    ListTile(
                      leading: Icon(
                        n == _gridCount ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: n == _gridCount ? Theme.of(context).primaryColor : null,
                      ),
                      title: Text('$n per row'),
                      onTap: () => Navigator.pop(context, {'mode': 'grid', 'count': n}),
                    ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        if (result['mode'] == 'list') {
          _isGridView = false;
        } else if (result['mode'] == 'grid') {
          _isGridView = true;
          if (result['count'] != null) {
            _gridCount = result['count'];
          }
        }
      });
    }
  }

  // Settings Tab - Numbering configuration
  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Numbering type section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.format_list_numbered, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      const Text(
                        'Numbering Type',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildNumberingTypeChip(NumberingType.continuous, 'All Pages', Icons.format_list_numbered),
                      _buildNumberingTypeChip(NumberingType.oddOnly, 'Odd Only', Icons.looks_one),
                      _buildNumberingTypeChip(NumberingType.evenOnly, 'Even Only', Icons.looks_two),
                      // _buildNumberingTypeChip(NumberingType.customRange, 'Custom Range', Icons.space_bar),
                    ],
                  ),
                  if (_numberingType == NumberingType.customRange) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Start Page',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.first_page),
                            ),
                            keyboardType: TextInputType.number,
                            initialValue: _rangeStart.toString(),
                            onChanged: (v) {
                              final parsed = int.tryParse(v);
                              if (parsed != null && parsed > 0) {
                                setState(() => _rangeStart = parsed);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'End Page',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.last_page),
                            ),
                            keyboardType: TextInputType.number,
                            initialValue: _rangeEnd.toString(),
                            onChanged: (v) {
                              final parsed = int.tryParse(v);
                              if (parsed != null && parsed > 0) {
                                setState(() => _rangeEnd = parsed);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Position section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.place, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      const Text(
                        'Number Position',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Show grid only if NOT custom position
                  if (_format != PageNumberFormat.customOffset) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildPositionButton(PageNumberFormat.topLeft, 'TL', Icons.north_west),
                              _buildPositionButton(PageNumberFormat.topCenter, 'TC', Icons.north),
                              _buildPositionButton(PageNumberFormat.topRight, 'TR', Icons.north_east),
                            ],
                          ),
                          const SizedBox(height: 32),
                          const Center(
                            child: Text(
                              'Page Preview',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildPositionButton(PageNumberFormat.bottomLeft, 'BL', Icons.south_west),
                              _buildPositionButton(PageNumberFormat.bottomCenter, 'BC', Icons.south),
                              _buildPositionButton(PageNumberFormat.bottomRight, 'BR', Icons.south_east),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Custom position toggle/option
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _format == PageNumberFormat.customOffset,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _format = PageNumberFormat.customOffset;
                        } else {
                          _format = PageNumberFormat.bottomRight;
                        }
                      });
                    },
                    title: const Text('Use Custom Position'),
                    subtitle: _format == PageNumberFormat.customOffset
                        ? const Text('Set exact coordinates below')
                        : null,
                  ),
                  if (_format == PageNumberFormat.customOffset) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'X Position (pt)',
                              border: OutlineInputBorder(),
                              helperText: 'Horizontal',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            initialValue: _customDx.toStringAsFixed(0),
                            onChanged: (v) {
                              final parsed = double.tryParse(v);
                              if (parsed != null) setState(() => _customDx = parsed);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Y Position (pt)',
                              border: OutlineInputBorder(),
                              helperText: 'Vertical',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            initialValue: _customDy.toStringAsFixed(0),
                            onChanged: (v) {
                              final parsed = double.tryParse(v);
                              if (parsed != null) setState(() => _customDy = parsed);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Spacer option
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.space_bar, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      const Text(
                        'Page Spacing',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _insertSpacer,
                    onChanged: (v) => setState(() => _insertSpacer = v),
                    title: const Text('Insert blank page after each page'),
                    subtitle: const Text('Adds empty pages between content'),
                  ),
                ],
              ),
            ),
          ),
                  const SizedBox(height: 200)
        ],
      ),
    );
  }

  Widget _buildNumberingTypeChip(NumberingType type, String label, IconData icon) {
    final isSelected = _numberingType == type;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: isSelected ? Colors.white : null),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _numberingType = type);
        }
      },
      selectedColor: Theme.of(context).primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildPositionButton(PageNumberFormat position, String label, IconData icon) {
    final isSelected = _format == position;
    return InkWell(
      onTap: () => setState(() => _format = position),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade700,
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
