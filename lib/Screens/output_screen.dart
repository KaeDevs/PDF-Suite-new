import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import '../Utils/app_theme.dart';

class OutputScreen extends StatefulWidget {
  final File pdfFile;
  final String? customTitle;
  final VoidCallback? onCompress;
  final VoidCallback? onProtect;
  final VoidCallback? onPrint;
  final VoidCallback? onDiscard;

  const OutputScreen({
    Key? key,
    required this.pdfFile,
    this.customTitle,
    this.onCompress,
    this.onProtect,
    this.onPrint,
    this.onDiscard,
  }) : super(key: key);

  @override
  State<OutputScreen> createState() => _OutputScreenState();
}

class _OutputScreenState extends State<OutputScreen> {
  pdfx.PdfDocument? _pdfDocument;
  int _totalPages = 0;
  int _currentPreviewPage = 1;
  bool _isLoading = true;
  String _fileSize = '';
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadPdfPreview();
    _calculateFileSize();
  }

  Future<void> _loadPdfPreview() async {
    try {
      final bytes = await widget.pdfFile.readAsBytes();
      final doc = await pdfx.PdfDocument.openData(bytes);
      setState(() {
        _pdfDocument = doc;
        _totalPages = doc.pagesCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading PDF preview: $e');
    }
  }

  void _calculateFileSize() {
    final bytes = widget.pdfFile.lengthSync();
    final kb = bytes / 1024;
    final mb = kb / 1024;
    
    setState(() {
      _fileSize = mb >= 1 ? '${mb.toStringAsFixed(1)} MB' : '${kb.toStringAsFixed(0)} KB';
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pdfDocument?.close();
    super.dispose();
  }

  Future<void> _sharePdf() async {
    try {
      await Share.shareXFiles(
        [XFile(widget.pdfFile.path)],
        subject: 'PDF Document',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: $e')),
        );
      }
    }
  }

  Future<void> _saveToFiles() async {
    try {
      // Open the file which will trigger the save dialog
      await OpenFilex.open(widget.pdfFile.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF ready to save')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _handleDiscard() {
    if (widget.onDiscard != null) {
      widget.onDiscard!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Output'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Done',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // PDF Preview
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _pdfDocument == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.picture_as_pdf,
                                size: 64,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'PDF Preview Unavailable',
                                style: theme.textTheme.titleMedium,
                              ),
                            ],
                          ),
                        )
                      : Stack(
                          children: [
                            // PageView for swipeable PDF pages
                            PageView.builder(
                              controller: _pageController,
                              itemCount: _totalPages,
                              onPageChanged: (page) {
                                setState(() {
                                  _currentPreviewPage = page + 1;
                                });
                              },
                              itemBuilder: (context, index) {
                                return Center(
                                  child: FutureBuilder<pdfx.PdfPage>(
                                    future: _pdfDocument!.getPage(index + 1),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return const CircularProgressIndicator();
                                      }

                                      final page = snapshot.data!;
                                      return FutureBuilder<pdfx.PdfPageImage?>(
                                        future: page.render(
                                          width: page.width * 2,
                                          height: page.height * 2,
                                        ),
                                        builder: (context, imgSnapshot) {
                                          if (!imgSnapshot.hasData) {
                                            return const CircularProgressIndicator();
                                          }

                                          return Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: Image.memory(
                                                imgSnapshot.data!.bytes,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                            // Page indicator
                            if (_totalPages > 1)
                              Positioned(
                                bottom: 16,
                                right: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$_currentPreviewPage/$_totalPages',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            // Swipe hint on first page
                            if (_currentPreviewPage == 1 && _totalPages > 1)
                              Positioned(
                                bottom: 60,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.swipe,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Swipe to view pages',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
            ),
          ),

          // File info
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.description,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '$_fileSize • $_totalPages Page${_totalPages != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // File name
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.dividerColor,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.insert_drive_file,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.customTitle ?? widget.pdfFile.path.split('/').last,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: _handleDiscard,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Share PDF Button
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _sharePdf,
              icon: const Icon(Icons.share),
              label: const Text('Share PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Save to Files Button
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _saveToFiles,
              icon: const Icon(Icons.download),
              label: const Text('Save to Files'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Quick Actions
          // Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: 16),
          //   child: Column(
          //     crossAxisAlignment: CrossAxisAlignment.start,
          //     children: [
          //       Text(
          //         'QUICK ACTIONS',
          //         style: theme.textTheme.labelSmall?.copyWith(
          //           fontWeight: FontWeight.w600,
          //           letterSpacing: 1.2,
          //           color: theme.textTheme.bodySmall?.color,
          //         ),
          //       ),
          //       const SizedBox(height: 16),
          //       Row(
          //         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          //         children: [
          //           if (widget.onCompress != null)
          //             _QuickActionButton(
          //               icon: Icons.compress,
          //               label: 'Compress',
          //               onTap: widget.onCompress!,
          //             ),
          //           if (widget.onProtect != null)
          //             _QuickActionButton(
          //               icon: Icons.lock,
          //               label: 'Protect',
          //               onTap: widget.onProtect!,
          //             ),
          //           if (widget.onPrint != null)
          //             _QuickActionButton(
          //               icon: Icons.print,
          //               label: 'Print',
          //               onTap: widget.onPrint!,
          //             ),
          //           _QuickActionButton(
          //             icon: Icons.delete,
          //             label: 'Discard',
          //             onTap: _handleDiscard,
          //             isDestructive: true,
          //           ),
          //         ],
          //       ),
          //     ],
          //   ),
          // ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _QuickActionButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isDestructive
                    ? Colors.red.withOpacity(0.1)
                    : theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isDestructive ? Colors.red : theme.colorScheme.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
