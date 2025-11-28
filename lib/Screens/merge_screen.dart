
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:path/path.dart' as p;
import '../Modules/page_ref.dart';
import '../Services/document_scanner_service.dart';
import '../Services/pdf_service.dart';
import '../Services/file_service.dart';
import '../Widgets/common/custom_snackbar.dart';
import '../services/ad_service.dart';
import '../Widgets/dialogs/name_dialog.dart';
import '../Widgets/dialogs/export_dialog.dart';

class MergeScreen extends StatefulWidget {
  const MergeScreen({super.key});

  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  final AdService _adService = AdService();
  final List<String> _pdfFiles = [];
  // Master list of all pages across selected PDFs
  final List<PageRef> _pagesAll = [];
  bool _loading = false;
  int _level = 0; // 0 = Files, 1 = Pages
  String? _filterFilePath; // When set, pages grid shows only this file
  final Map<String, Uint8List> _thumbCache = {}; // key: file::page
  // Zoom and grid state (zoom controls columns instead of pinch-zoom)
  double _zoom = 1.0; // 1.0 = default density
  bool _showZoomBar = false;
  int _gridCount = 3; // default columns in grid
  String? _progressText; // optional progress message when loading

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
    final picked = await DocumentScannerService.pickPdfFiles();
    if (picked.isNotEmpty) {
      setState(() => _pdfFiles.addAll(picked));
    }
  }

  Future<void> _expandPages({String? forFile}) async {
    setState(() => _loading = true);
    try {
      _pagesAll.clear();
      for (final file in _pdfFiles) {
        final doc = await PdfDocument.openFile(file);
        for (int i = 1; i <= doc.pagesCount; i++) {
          _pagesAll.add(PageRef(filePath: file, pageNumber: i));
        }
        await doc.close();
      }
      setState(() {
        _level = 1;
        _filterFilePath = forFile;
      });
    } catch (e) {
      CustomSnackbar.showError(context, 'Failed to expand pages: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _reorderFiles(int oldIndex, int newIndex) {
    setState(() {
      // ReorderableListView semantics: if moving down, newIndex includes the gap; decrement it
      if (newIndex > oldIndex) newIndex -= 1;
      final f = _pdfFiles.removeAt(oldIndex);
      _pdfFiles.insert(newIndex, f);
    });
  }

  Future<void> _confirmDeleteFile(int index) async {
    final file = _pdfFiles[index];
    final name = p.basename(file);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove PDF'),
        content: Text('Remove "$name" from the merge list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) {
      _deletePdfAt(index);
    }
  }

  void _deletePdfAt(int index) {
    setState(() {
      if (index < 0 || index >= _pdfFiles.length) return;
      final file = _pdfFiles.removeAt(index);
      // Remove any cached thumbs for this file
      _thumbCache.removeWhere((key, _) => key.startsWith('$file::'));
      // Remove any pages for this file if already expanded previously
      _pagesAll.removeWhere((p) => p.filePath == file);
      if (_filterFilePath == file) {
        _filterFilePath = null;
      }
    });
  }

  List<int> get _visibleIndices {
    if (_filterFilePath == null) {
      return List<int>.generate(_pagesAll.length, (i) => i);
    }
    final path = _filterFilePath!;
    final idx = <int>[];
    for (int i = 0; i < _pagesAll.length; i++) {
      if (_pagesAll[i].filePath == path) idx.add(i);
    }
    return idx;
  }

  List<PageRef> get _visiblePages => _visibleIndices.map((i) => _pagesAll[i]).toList(growable: false);

  void _reorderPages(int oldIndex, int newIndex) {
    setState(() {
      if (_filterFilePath == null) {
        // Reorder in the master list directly (ReorderableGridView semantics: no decrement)
        final item = _pagesAll.removeAt(oldIndex);
        _pagesAll.insert(newIndex, item);
      } else {
        // Reorder within the filtered subset while updating the master list
        final indicesBefore = _visibleIndices;
        final fromGlobal = indicesBefore[oldIndex];
        final item = _pagesAll.removeAt(fromGlobal);
        final indicesAfter = _visibleIndices; // recompute after removal
        int toGlobal;
        if (newIndex >= indicesAfter.length) {
          // Insert after the last visible item (or at end if none)
          toGlobal = indicesAfter.isEmpty ? _pagesAll.length : (indicesAfter.last + 1);
        } else {
          toGlobal = indicesAfter[newIndex];
        }
        _pagesAll.insert(toGlobal, item);
      }
    });
  }

  Future<void> _exportMerged() async {
    try {
      setState(() {
        _loading = true;
        _progressText = 'Preparing...';
      });
      // Ask for a base name first
      final baseName = await showDialog<String>(
        context: context,
        builder: (ctx) => NameDialog(
          currentName: null,
          onNameChanged: (_) {},
        ),
      );
      if (baseName == null) {
        setState(() => _loading = false);
        return;
      }

      // Start merge immediately so it can progress while the ad is showing
      final mergeFuture = _level == 0
          ? PdfService.mergePdfs(
              _pdfFiles,
              baseName: baseName,
              onProgress: (cur, total) {
                if (!mounted) return;
                if (cur % 1 == 0) {
                  setState(() => _progressText = 'Merging $cur / $total');
                }
              },
            )
          : PdfService.mergePages(
              _pagesAll,
              baseName: baseName,
              onProgress: (cur, total) {
                if (!mounted) return;
                if (cur % 1 == 0) {
                  setState(() => _progressText = 'Merging $cur / $total');
                }
              },
            );

      _adService.showAdAndRun(() async {
        // After ad is dismissed (or if ad not ready), finalize and show result
        try {
          final file = await mergeFuture;
          if (!mounted) return;
          setState(() {
            _loading = false;
            _progressText = null;
          });

          await showModalBottomSheet(
            context: context,
            builder: (ctx) => ExportDialog(
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
          CustomSnackbar.showError(context, 'Export failed: $e');
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _progressText = null;
      });
      CustomSnackbar.showError(context, 'Export failed: $e');
    }
  }

  Future<MemoryImage?> _getThumb(PageRef ref) async {
    final key = '${ref.filePath}::${ref.pageNumber}';
    final cached = _thumbCache[key];
    if (cached != null) return MemoryImage(cached);
    try {
      final doc = await PdfDocument.openFile(ref.filePath);
      final page = await doc.getPage(ref.pageNumber);
      // thumbnail size ~ 400px on the longest side
      final maxSide = 400.0;
      final aspect = page.width / page.height;
      double w, h;
      if (aspect >= 1) {
        w = maxSide; h = maxSide / aspect;
      } else {
        h = maxSide; w = maxSide * aspect;
      }
      final img = await page.render(
        width: w,
        height: h,
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );
      await page.close();
      await doc.close();
      if (img == null) return null;
      _thumbCache[key] = img.bytes;
      return MemoryImage(img.bytes);
    } catch (_) {
      return null;
    }
  }

  void _deletePageAt(int visibleIndex) {
    setState(() {
      final indices = _visibleIndices;
      if (visibleIndex < 0 || visibleIndex >= indices.length) return;
      final globalIndex = indices[visibleIndex];
      final ref = _pagesAll.removeAt(globalIndex);
      _thumbCache.remove('${ref.filePath}::${ref.pageNumber}');
    });
  // void _duplicatePageAt(int visibleIndex) {
  //   setState(() {
  //     final indices = _visibleIndices;
  //     if (visibleIndex < 0 || visibleIndex >= indices.length) return;
  //     final globalIndex = indices[visibleIndex];
  //     final ref = _pagesAll[globalIndex];
  //     _pagesAll.insert(globalIndex + 1, PageRef(filePath: ref.filePath, pageNumber: ref.pageNumber));
  //   });
  // }
  }

  Color _colorForFile(String filePath) {
    final hash = filePath.hashCode;
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(0.85, hue, 0.5, 0.6).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_level == 1) {
          setState(() {
            _level = 0;
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Merge PDFs'),
          leading: _level == 1
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _level = 0;
                    });
                  },
                )
              : null,
          actions: [
            if (_level == 0)
              IconButton(
                onPressed: _loading ? null : _pickPdfs,
                icon: const Icon(Icons.add),
                tooltip: 'Add PDFs',
              ),
            if (_level == 1) ...[
              // IconButton(
              //   onPressed: () => setState(() => _showZoomBar = !_showZoomBar),
              //   icon: const Icon(Icons.zoom_in),
              //   tooltip: 'Zoom',
              // ),
              IconButton(
                onPressed: _showGridPicker,
                icon: const Icon(Icons.grid_view),
                tooltip: 'Grid columns',
              ),
            ],
          ],
        ),
        floatingActionButton: null,
        body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  if (_progressText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _progressText!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            )
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _level == 0 ? _buildFilesLevel() : _buildPagesLevel(),
            ),
      ),
    );
  }

  Widget _buildFilesLevel() {
    if (_pdfFiles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Add PDFs to merge'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _pickPdfs,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Pick PDFs'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ReorderableListView.builder(
            onReorder: _reorderFiles,
            padding: const EdgeInsets.all(12),
            itemCount: _pdfFiles.length,
            itemBuilder: (context, index) {
              final file = _pdfFiles[index];
              final name = p.basename(file);
              return ListTile(
                key: ValueKey(file),
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Remove PDF',
                      onPressed: () => _confirmDeleteFile(index),
                    ),
                    const Icon(Icons.drag_handle),
                  ],
                ),
                onTap: () => _expandPages(forFile: file),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _expandPages,
                    icon: const Icon(Icons.grid_view),
                    label: const Text('View Pages'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _exportMerged,
                    icon: const Icon(Icons.merge_type),
                    label: const Text('Merge'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPagesLevel() {
    final visible = _visiblePages;
    if (visible.isEmpty) {
      return const Center(child: Text('No pages to show'));
    }

    return Column(
      children: [
        if (_showZoomBar)
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () => _setZoom((_zoom - 0.1).clamp(0.5, 3.0)),
                    tooltip: 'Zoom out',
                  ),
                  Expanded(
                    child: Slider(
                      value: _zoom,
                      min: 0.5,
                      max: 3.0,
                      divisions: 25,
                      label: _zoom.toStringAsFixed(2),
                      onChanged: (v) => _setZoom(v),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _setZoom((_zoom + 0.1).clamp(0.5, 3.0)),
                    tooltip: 'Zoom in',
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: ReorderableGridView.count(
            onReorder: _reorderPages,
            padding: const EdgeInsets.all(12),
            crossAxisCount: _gridCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              for (int index = 0; index < visible.length; index++)
                _buildPageTile(index, visible[index]),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _level = 0),
                    icon: const Icon(Icons.folder),
                    label: const Text('Back to Files'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _exportMerged,
                    icon: const Icon(Icons.merge_type),
                    label: const Text('Merge'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageTile(int visibleIndex, PageRef ref) {
    final key = ValueKey('${ref.filePath}:${ref.pageNumber}:$visibleIndex');
  final badgeColor = _colorForFile(ref.filePath);
    return Container(
      key: key,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: FutureBuilder<MemoryImage?>(
              future: _getThumb(ref),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                }
                if (snap.data == null) {
                  return const Center(child: Icon(Icons.image_not_supported));
                }
                return Image(image: snap.data!, fit: BoxFit.cover);
              },
            ),
          ),
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Pg ${ref.pageNumber}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Row(
              children: [
                // IconButton(
                //   icon: const Icon(Icons.copy, color: Colors.white),
                //   onPressed: () => _duplicatePageAt(visibleIndex),
                //   tooltip: 'Duplicate',
                // ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deletePageAt(visibleIndex),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _setZoom(double value) {
    setState(() {
      _zoom = value;
      // Map zoom to columns: lower zoom -> more columns, higher zoom -> fewer columns
      int cols;
      if (_zoom <= 0.75) {
        cols = 5;
      } else if (_zoom <= 1.25) {
        cols = 4;
      } else if (_zoom <= 2.0) {
        cols = 3;
      } else {
        cols = 2;
      }
      _gridCount = cols;
    });
  }

  Future<void> _showGridPicker() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Grid columns'),
              ),
              for (final n in [2, 3, 4, 5])
                ListTile(
                  leading: Icon(n == _gridCount ? Icons.radio_button_checked : Icons.radio_button_off),
                  title: Text('$n per row'),
                  onTap: () => Navigator.pop(context, n),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (selected != null && selected != _gridCount) {
      setState(() {
        _gridCount = selected;
      });
    }
  }
}
