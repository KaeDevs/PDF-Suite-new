import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

class PdfViewPage extends StatefulWidget {
  final String filePath;
  final String? title;

  const PdfViewPage({
    super.key,
    required this.filePath,
    this.title,
  });

  @override
  State<PdfViewPage> createState() => _PdfViewPageState();
}

class _PdfViewPageState extends State<PdfViewPage> {
  late PdfControllerPinch _pdfController;
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _showControls = true;
  bool _isDraggingScrollbar = false;
  int? _dragDisplayPage; // shows page number live while dragging without jank
  DateTime _lastScrollbarJump = DateTime.fromMillisecondsSinceEpoch(0);
  bool _showPageHud = false; // transient page HUD at center
  Timer? _hudTimer;

  @override
  void initState() {
    super.initState();
    _initializePdfController();
  }

  Future<void> _initializePdfController() async {
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        setState(() {
          _error = 'PDF file not found at:\n${widget.filePath}';
          _isLoading = false;
        });
        return;
      }

      final document = await PdfDocument.openFile(widget.filePath);
      
      setState(() {
        _totalPages = document.pagesCount;
      });

      _pdfController = PdfControllerPinch(
        document: PdfDocument.openFile(widget.filePath),
        initialPage: 1,
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Unable to load PDF.\n\nDetails: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _goToPreviousPage() {
    if (_currentPage > 1) {
      _pdfController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNextPage() {
    if (_currentPage < _totalPages) {
      _pdfController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showPageJumpDialog() {
    final controller = TextEditingController(text: _currentPage.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Jump to Page'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Page number',
                hintText: '1-$_totalPages',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.numbers),
              ),
              onSubmitted: (value) {
                final pageNumber = int.tryParse(value);
                if (pageNumber != null && pageNumber >= 1 && pageNumber <= _totalPages) {
                  _pdfController.animateToPage(
                    pageNumber: pageNumber,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                  );
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final pageNumber = int.tryParse(controller.text);
              if (pageNumber != null && pageNumber >= 1 && pageNumber <= _totalPages) {
                _pdfController.animateToPage(
                  pageNumber: pageNumber,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                );
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please enter a number between 1 and $_totalPages'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  @override
  void dispose() {
    _hudTimer?.cancel();
    _pdfController.dispose();
    super.dispose();
  }

  Widget _buildCustomScrollbar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;
        final thumbHeight = (maxHeight / _totalPages).clamp(40.0, 100.0);
        final scrollRange = maxHeight - thumbHeight;
        final displayPage = (_dragDisplayPage ?? _currentPage).clamp(1, _totalPages);
        final currentPosition =
            (_totalPages > 1) ? ((displayPage - 1) / (_totalPages - 1)) * scrollRange : 0.0;

        return GestureDetector(
          onVerticalDragStart: (_) {
            setState(() {
              _isDraggingScrollbar = true;
            });
          },
          onVerticalDragUpdate: (details) {
            if (scrollRange <= 0) return;
            final position = (details.localPosition.dy / scrollRange).clamp(0.0, 1.0);
            final targetPage = (position * (_totalPages - 1) + 1).round().clamp(1, _totalPages);

            // Show the number live on the thumb while dragging
            if (targetPage != _dragDisplayPage) {
              setState(() => _dragDisplayPage = targetPage);
            }

            // Throttle navigation to avoid stop-and-go jank
            final now = DateTime.now();
            if (now.difference(_lastScrollbarJump).inMilliseconds >= 50) {
              _lastScrollbarJump = now;
              if (targetPage != _currentPage) {
                _pdfController.animateToPage(
                  pageNumber: targetPage,
                  duration: const Duration(milliseconds: 1),
                  curve: Curves.linear,
                );
              }
            }
          },
          onVerticalDragEnd: (_) {
            setState(() {
              _isDraggingScrollbar = false;
              _dragDisplayPage = null;
            });
          },
          child: Container(
            width: 50,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.0),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Stack(
                children: [
                // Subtle vertical track centered, balanced width/height look
                Positioned.fill(
                  child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 10,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.00),
                    borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  ),
                ),
                // Draggable thumb (centered, a bit wider and visually balanced)
                AnimatedPositioned(
                  duration: _isDraggingScrollbar
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  top: currentPosition,
                  left: 0,
                  right: 0,
                  child: Align(
                  alignment: Alignment.topCenter,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28, // a bit wider for better touch target
                    height: thumbHeight, // keep physics consistent
                    decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: _isDraggingScrollbar
                        ? [
                          Theme.of(context).colorScheme.primary.withOpacity(0.95),
                          Theme.of(context).colorScheme.primary.withOpacity(0.80),
                        ]
                        : [
                          Theme.of(context).colorScheme.primary.withOpacity(0.75),
                          Theme.of(context).colorScheme.primary.withOpacity(0.60),
                        ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                      ),
                    ],
                    ),
                    child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                      color: Colors.white,
                      fontSize: _isDraggingScrollbar ? 13 : 12,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      ),
                      child: Text('${_dragDisplayPage ?? _currentPage}'),
                    ),
                    ),
                  ),
                  ),
                ),
              ],
            ),
          ),
        );
    },
  );
}

@override
Widget build(BuildContext context) {
    return Scaffold(
      appBar: _showControls
          ? AppBar(
              title: Text(widget.title ?? 'PDF Viewer'),
              actions: [
                if (!_isLoading && _error == null && _totalPages > 0) ...[
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () async {
                      try {
                      final file = File(widget.filePath);
                      if (!await file.exists()) {
                        ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('File not found')),
                        );
                        return;
                      }

                      await Share.shareXFiles(
                        [
                        XFile(
                          file.path,
                          mimeType: 'application/pdf',
                          name: widget.title ?? 'document.pdf',
                        ),
                        ],
                        subject: widget.title ?? 'PDF Document',
                        text: widget.title ?? 'PDF Document',
                      );
                      } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Unable to share: $e')),
                      );
                      }
                    
                    },
                    tooltip: 'Share',
                  ),
                  IconButton(
                    icon: const Icon(Icons.first_page),
                    onPressed: _currentPage > 1
                        ? () => _pdfController.animateToPage(
                              pageNumber: 1,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                            )
                        : null,
                    tooltip: 'First page',
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            )
          : null,
      body: _buildBody(),
      bottomNavigationBar: !_isLoading && _error == null && _totalPages > 0 && _showControls
          // ? _buildBottomBar()
          ? null
          : null,
      floatingActionButton: !_isLoading && _error == null && _totalPages > 0
          ? FloatingActionButton.small(
              onPressed: _toggleControls,
              child: Icon(_showControls ? Icons.fullscreen : Icons.fullscreen_exit),
              tooltip: _showControls ? 'Hide controls' : 'Show controls',
            )
          : null,
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton.filled(
              icon: const Icon(Icons.chevron_left),
              onPressed: _currentPage > 1 ? _goToPreviousPage : null,
              tooltip: 'Previous page',
            ),
            Expanded(
              child: GestureDetector(
                onTap: _showPageJumpDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Page $_currentPage',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        ' of $_totalPages',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: Theme.of(context).primaryColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton.filled(
              icon: const Icon(Icons.chevron_right),
              onPressed: _currentPage < _totalPages ? _goToNextPage : null,
              tooltip: 'Next page',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Loading PDF...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.picture_as_pdf_outlined,
                size: 80,
                color: Colors.red[300],
              ),
              const SizedBox(height: 24),
              Text(
                'Cannot Open PDF',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _error = null;
                      });
                      _initializePdfController();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        GestureDetector(
          onTap: _toggleControls,
          child: PdfViewPinch(
            controller: _pdfController,
            padding: 2,
            backgroundDecoration: BoxDecoration(
              color: Colors.grey[300],
            ),
            scrollDirection: Axis.vertical,
            onDocumentLoaded: (document) {
              setState(() {
                _totalPages = document.pagesCount;
              });
            },
            onPageChanged: (page) {
              setState(() {
                _currentPage = page;
                _showPageHud = true;
              });
              _hudTimer?.cancel();
              _hudTimer = Timer(const Duration(milliseconds: 800), () {
                if (mounted) {
                  setState(() => _showPageHud = false);
                }
              });
            },
          ),
        ),
        // Center page HUD that appears briefly when page changes
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _showPageHud ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_currentPage / $_totalPages',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Custom scrollbar on the right
        if (_totalPages > 1 && _showControls)
          Positioned(
            right: 8,
            top: 20,
            bottom: 20,
            child: _buildCustomScrollbar(),
          ),
      ],
    );
  }
}