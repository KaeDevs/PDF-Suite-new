import 'dart:io';

import 'package:docu_scan/Modules/scan_settings.dart';
import 'package:docu_scan/Screens/about_screen.dart';
import 'package:docu_scan/Utils/tools.dart';
import 'package:docu_scan/Utils/app_theme.dart';
import 'package:flutter/material.dart';
// import '../models/scan_settings.dart';
import '../Modules/FeedBack/feedback_diaog.dart';
import '../Widgets/ListTilePrep.dart';
import '../services/ad_service.dart';
import '../services/document_scanner_service.dart';
import '../services/file_service.dart';
import '../services/pdf_service.dart';
import '../services/pdf_viewer_service.dart';
import '../widgets/common/custom_snackbar.dart';
import '../widgets/common/loading_overlay.dart';
import '../widgets/dialogs/export_dialog.dart';
// import '../widgets/dialogs/name_dialog.dart';
import '../widgets/dialogs/settings_dialog.dart';
import '../widgets/scan_grid.dart';
import 'package:path/path.dart' as p;
import 'merge_screen.dart';
import 'compress_screen.dart';
import 'numbered_pdf_screen.dart';
import 'ocr_pdf_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AdService _adService = AdService();
  final TextEditingController _nameController = TextEditingController();

  List<String> _scannedImages = [];
  bool _isEditing = false;
  bool _isLoading = false;
  String? _loadingText;
  ScanSettings _settings = const ScanSettings();

  @override
  void initState() {
    super.initState();
    _adService.loadInterstitialAd();
    // Intent handling moved to native Android (MainActivity) via MethodChannel
  }

  @override
  void dispose() {
    _adService.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _scanDocuments() async {
    try {
      final result = await DocumentScannerService.scanDocuments();
      if (result.isEmpty) return;

      setState(() {
        _scannedImages.addAll(result);
      });
      CustomSnackbar.showSuccess(context, 'Scanned ${result.length} page(s).');
    } catch (e) {
      CustomSnackbar.showError(context, 'Failed to scan documents: $e');
    }
  }

  Future<void> _pickFromFiles() async {
    try {
      final result = await DocumentScannerService.pickFromFiles();
      if (result.isEmpty) return;

      setState(() {
        _scannedImages.addAll(result);
      });
      CustomSnackbar.showSuccess(context, 'Added ${result.length} image(s).');
    } catch (e) {
      CustomSnackbar.showError(context, 'File picking failed: $e');
    }
  }

  Future<void> _pickAndViewPdf() async {
    try {
      final pdfFiles = await DocumentScannerService.pickPdfFiles();
      if (pdfFiles.isNotEmpty) {
        if (pdfFiles.length == 1) {
          await PdfViewerService.openPdf(context, pdfFiles.first);
        } else {
          _showPdfSelectionDialog(pdfFiles);
        }
      }
    } catch (e) {
      CustomSnackbar.showError(context, 'Failed to open PDF: $e');
    }
  }

  void _showPdfSelectionDialog(List<String> pdfFiles) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select PDF to view'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: pdfFiles.length,
            itemBuilder: (context, index) {
              final fileName = p.basename(pdfFiles[index]);
              return ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text(fileName),
                onTap: () {
                  Navigator.of(context).pop();
                  PdfViewerService.openPdf(context, pdfFiles[index]);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _chooseInputMethod() {
    showModalBottomSheet(

      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // const SizedBox(height: 16),
            Wrap(
              children: [
                
                ModernListTile(
      icon: Icons.document_scanner_outlined,
      title: 'Scan with Camera',
      subtitle: 'Use your camera to scan documents',
      onTap: () {
        Navigator.pop(context);
        _scanDocuments();
      },
    ),
    const SizedBox(height: 8),
    ModernListTile(
      icon: Icons.photo_library_outlined,
      title: 'Pick from Gallery',
      subtitle: 'Choose images from your device',
      onTap: () {
        Navigator.pop(context);
        _pickFromFiles();
      },
    ),
    // const SizedBox(height: 8),
    // ModernListTile(
    //   icon: Icons.merge_type_outlined,
    //   title: 'Merge PDFs',
    //   subtitle: 'Combine multiple PDFs into one',
    //   onTap: () {
    //     Navigator.pop(context);
    //     _mergePdfsFlow();
    //   },
    // ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _exportAsPdf() {
    if (_scannedImages.isEmpty) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => ExportDialog(
        
        onSharePdf: () {
          Navigator.pop(context);
          _exportPdfWithAd(saveOnly: false);
        },
        onSavePdf: () {
          Navigator.pop(context);
          _exportPdfWithAd(saveOnly: true);
        },
      ),
    );
  }

  Future<void> _exportPdfWithAd({required bool saveOnly}) async {
    if (_scannedImages.isEmpty) return;
    setState(() {
      _isLoading = true;
      _loadingText = 'Preparing export…';
    });

    try {
      // Start the conversion immediately and update progress text.
      final conversionFuture = PdfService.convertImagesToPdf(
        _scannedImages,
        _settings.documentName,
        _settings.compressionEnabled,
      );

      // Show an ad in the foreground while conversion runs in the background.
      final pdfFile = await _adService.showAdWhileFuture(conversionFuture);

      // After both ad is closed and conversion completed, proceed.
      if (saveOnly) {
        final savedFile = await FileService.saveToDownloads(pdfFile);
        if (mounted) {
          CustomSnackbar.showSuccess(context, 'Saved to: ${savedFile.path}');
        }
      } else {
        await FileService.shareFile(pdfFile, 'pdf');
        if (mounted) {
          CustomSnackbar.showSuccess(context, 'PDF exported.');
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, 'PDF export failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingText = null;
        });
      }
    }
  }

  

  

  Future<void> _exportImagesWithAd() async {
    if (_scannedImages.isEmpty) return;
    setState(() {
      _isLoading = true;
      _loadingText = 'Preparing export…';
    });

    final multiple = _scannedImages.length > 1;
    try {
      final prepFuture = multiple
          ? FileService.zipImages(_scannedImages, _settings.documentName)
          : Future.value(File(_scannedImages.first));

      final readyFile = await _adService.showAdWhileFuture(prepFuture);

      await FileService.shareFile(readyFile, multiple ? 'zip' : 'image');
      if (mounted) {
        CustomSnackbar.showSuccess(context, 'Export complete.');
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, 'Image export failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingText = null;
        });
      }
    }
  }

  // Handle drag-and-drop reordering from the grid
  void _reorderImages(int oldIndex, int newIndex) {
    setState(() {
      final moved = _scannedImages.removeAt(oldIndex);
      _scannedImages.insert(newIndex, moved);
    });
  }

  // Flow to merge multiple PDF files into one
  

  void _clearScans() {
    setState(() => _scannedImages = []);
    CustomSnackbar.showSuccess(context, 'Cleared scans.');
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(
        currentCompressionSetting: _settings.compressionEnabled,
        onCompressionChanged: (value) {
          setState(() {
            _settings = _settings.copyWith(compressionEnabled: value);
          });
        },
      ),
    );
  }

  // Removed name dialog in favor of inline editing in AppBar

  
@override
Widget build(BuildContext context) {
  final hasScans = _scannedImages.isNotEmpty;
  final theme = Theme.of(context);
  // final isDark = theme.brightness == Brightness.dark;

  return SafeArea(
    child: Scaffold(
      bottomNavigationBar: hasScans
          ? Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                    width: 1,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _ModernActionButton(
                        label: 'Export as PDF',
                        icon: Icons.picture_as_pdf_outlined,
                        isPrimary: true,
                        onPressed: _isLoading ? null : _exportAsPdf,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ModernActionButton(
                        label: 'Export as Images',
                        icon: Icons.image_outlined,
                        isPrimary: true,

                        onPressed: _isLoading ? null : _exportImagesWithAd,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      appBar: AppBar(
        elevation: 0,
        leading: hasScans
            ? IconButton(
                onPressed: _scanDocuments,
                icon: const Icon(Icons.camera_alt_outlined),
                tooltip: 'Scan',
              )
            : Row(
              children: [
                IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AboutPage(),
                      ),
                    ),
                    icon: const Icon(Icons.info_outline),
                    tooltip: 'AboutPage',
                  ),
              ],
            ),
            
        title: hasScans
            ? _isEditing
                ? TextField(
                    controller: _nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "Enter name",
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    onSubmitted: (val) {
                      setState(() {
                        _settings = _settings.copyWith(
                          documentName: val.isEmpty ? "Name" : val,
                        );
                        _isEditing = false;
                      });
                    },
                  )
                : GestureDetector(
                    onTap: () => setState(() => _isEditing = true),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _settings.documentName ?? "Name",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            fontFamily: "Oswald",

                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  )
            : Text(
                "PDF Suite",
                style: Tools.h2(context).copyWith(
                  fontWeight: FontWeight.w900,
                  fontFamily: "Oswald",
                  color: Colors.white,
                  fontSize: 22,
                ),
              ),
        centerTitle: true,
        actions: [
          hasScans ?
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Settings',
                  onPressed: _isLoading ? null : _showSettings,
                  icon: const Icon(Icons.settings_outlined),
                ),
                IconButton(
                  tooltip: 'Clear',
                  onPressed: _isLoading ? null : _clearScans,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ) : IconButton(
              tooltip: 'Feedback',
              onPressed: () {
                FeedbackDialog.show(context);
              },
              icon: const Icon(Icons.feedback_outlined),
            ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        loadingText: _loadingText,
        child: hasScans
            ? ScanGrid(
                imagePaths: _scannedImages,
                onImageDelete: (index) {
                  setState(() => _scannedImages.removeAt(index));
                },
                onReorder: _reorderImages,
              )
            : Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Choose an option below",
                        style: TextStyle(
                          fontSize: 18,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Scan Document Card
                      _ModernCard(
                        icon: Icons.document_scanner_rounded,
                        title: 'Scan Document',
                        subtitle: 'Scan using camera',
                        gradientIndex: 0,
                        rating: 4.5,
                        onPressed: _isLoading ? null : _chooseInputMethod,
                      ),
                      const SizedBox(height: 16),

                      // Open PDFs Card
                      _ModernCard(
                        icon: Icons.picture_as_pdf_rounded,
                        title: 'Open PDFs',
                        subtitle: 'View & manage',
                        gradientIndex: 0,
                        rating: 4.8,
                        onPressed: _isLoading ? null : _pickAndViewPdf,
                      ),
                      const SizedBox(height: 16),

                      // Merge PDFs Card
                      _ModernCard(
                        icon: Icons.merge_type_rounded,
                        title: 'Merge PDFs',
                        subtitle: 'Combine files',
                        gradientIndex: 0,
                        rating: 4.6,
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MergeScreen(),
                                  ),
                                ),
                      ),
                      const SizedBox(height: 16),

                      // Numbered PDF Card
                      // _ModernCard(
                      //   icon: Icons.format_list_numbered_rounded,
                      //   title: 'Numbered PDF',
                      //   subtitle: 'Add page numbers',
                      //   gradientIndex: 0,
                      //   rating: 4.6,
                      //   onPressed: _isLoading
                      //       ? null
                      //       : () => Navigator.push(
                      //             context,
                      //             MaterialPageRoute(
                      //               builder: (_) => const NumberedPdfScreen(),
                      //             ),
                      //           ),
                      // ),
                      // const SizedBox(height: 16),

                      // Compress PDFs Card
                      _ModernCard(
                        icon: Icons.compress_rounded,
                        title: 'Compress PDFs',
                        subtitle: 'Reduce file size',
                        gradientIndex: 0,
                        rating: 4.7,
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CompressScreen(),
                                  ),
                                ),
                      ),
                      const SizedBox(height: 16),

                      // OCR Card (Make PDF Searchable)
                      _ModernCard(
                        icon: Icons.auto_fix_high_rounded,
                        title: 'OCR',
                        subtitle: 'Extract text from images',
                        gradientIndex: 0,
                        rating: 4.8,
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const OcrPdfScreen(),
                                  ),
                                ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      floatingActionButton: hasScans
          ? FloatingActionButton.extended(
              onPressed: _isLoading ? null : _chooseInputMethod,
              elevation: 2,
              icon: const Icon(Icons.add),
              label: const Text(
                'Add Pages',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          : null,
    ),
  );
}}

// Modern Card Widget - inspired by app store cards
class _ModernCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int gradientIndex;
  final double rating;
  final VoidCallback? onPressed;

  const _ModernCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientIndex,
    required this.rating,
    this.onPressed,
  });

  @override
  State<_ModernCard> createState() => _ModernCardState();
}

class _ModernCardState extends State<_ModernCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Get gradient based on index
    final gradients = AppTheme.getGridGradients(context);
    final gradient = gradients[widget.gradientIndex % gradients.length];
    
    // Theme-aware colors
    final cardBackground = isDark 
        ? AppTheme.darkSurface  // Dark red surface for dark mode
        : Colors.white;         // White for light mode
    
    final textColor = isDark
        ? AppTheme.darkOnSurface  // Light pinkish text for dark mode
        : AppTheme.lightPrimary;   // Crimson red for light mode
    
    final subtitleColor = isDark
        ? AppTheme.darkOnSurface.withOpacity(0.7)
        : AppTheme.lightPrimary.withOpacity(0.7);
    
  // final borderColor = isDark
  //     ? Colors.white.withOpacity(0.1)
  //     : Colors.grey.withOpacity(0.2);

    return GestureDetector(
      onTapDown: widget.onPressed != null ? (_) => _controller.forward() : null,
      onTapUp: widget.onPressed != null
          ? (_) {
              _controller.reverse();
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: widget.onPressed != null ? () => _controller.reverse() : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          height: 100,
          
          margin: const EdgeInsets.symmetric(vertical: 2, ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: cardBackground,
            // border: Border.all(
            //   color: borderColor,
            //   width: 1.5,
            // ),
            boxShadow: widget.onPressed != null
                ? [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.5)
                          : Colors.black.withOpacity(0.1),
                      offset: const Offset(0, 8),
                      blurRadius: 24,
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.3)
                          : Colors.black.withOpacity(0.05),
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.3)
                          : Colors.black.withOpacity(0.05),
                      offset: const Offset(0, 4),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onPressed,
                splashColor: isDark
                    ? Colors.white.withOpacity(0.1)
                    : AppTheme.lightPrimary.withOpacity(0.1),
                highlightColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : AppTheme.lightPrimary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      // Left side - Icon with gradient container
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: gradient,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.3 : 0.15),
                              offset: const Offset(0, 4),
                              blurRadius: 8,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Icon(
                          widget.icon,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Right side - Text content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Title
                            Text(
                              widget.title,
                              style: Tools.h3(context).copyWith(
                                color: textColor,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            
                            // Subtitle
                            Text(
                              widget.subtitle,
                              style: Tools.subtitle(context).copyWith(
                                color: subtitleColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
// Modern Action Button (for bottom bar)
class _ModernActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback? onPressed;

  const _ModernActionButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: isPrimary 
            ? AppTheme.getPrimaryGradient(context)
            : AppTheme.getSecondaryGradient(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            offset: const Offset(0, 4),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.white.withOpacity(0.2),
          highlightColor: Colors.white.withOpacity(0.1),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}