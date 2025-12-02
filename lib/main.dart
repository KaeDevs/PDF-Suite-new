import 'package:docu_scan/Services/init_services/app_update.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'Services/pdf_viewer_service.dart';
import 'Screens/home_screen.dart';
import 'constants/app_constants.dart';
import 'Utils/app_theme.dart';

final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
String? _pendingPdfPath;

void main() async {   
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Transparent status bar
      statusBarIconBrightness: Brightness.dark, // Dark icons for light theme
      statusBarBrightness: Brightness.light, // For iOS
      systemNavigationBarColor: Colors.white, // Navigation bar color
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Set preferred orientations if needed
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  checkForUpdate();
  await MobileAds.instance.initialize();
  // Listen for Android intents from MainActivity and open PDFs
  const intentChannel = MethodChannel('com.example.pdfscanner/intents');
  intentChannel.setMethodCallHandler((call) async {
    if (call.method == 'openPdf') {
      final path = call.arguments as String?;
      final ctx = _navKey.currentContext;
      if (path != null && ctx != null) {
        await PdfViewerService.openPdf(ctx, path);
      } else if (path != null && ctx == null) {
        // Defer until first frame if context isn't ready yet
        _pendingPdfPath = path;
      }
    }
  });
  // After first frame, check if there's a pending path from native or from early channel callback
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      final initial = await intentChannel.invokeMethod<String>('getInitialPdfPath');
      _pendingPdfPath ??= initial;
      final ctx = _navKey.currentContext;
      final path = _pendingPdfPath;
      if (ctx != null && path != null) {
        _pendingPdfPath = null;
        await PdfViewerService.openPdf(ctx, path);
      }
    } catch (_) {
      // Ignore if method not implemented on other platforms
      final ctx = _navKey.currentContext;
      final path = _pendingPdfPath;
      if (ctx != null && path != null) {
        _pendingPdfPath = null;
        await PdfViewerService.openPdf(ctx, path);
      }
    }
  });
  runApp(const SafeArea(child: const DocuScanApp()));
}

class DocuScanApp extends StatelessWidget {
  const DocuScanApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navKey,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
// class DocuScanApp extends StatelessWidget {
//   const DocuScanApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       navigatorKey: _navKey,
//       title: AppConstants.appName,
//       debugShowCheckedModeBanner: false,
//       themeMode: ThemeMode.system,
//       theme: ThemeData(
//         useMaterial3: true,
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
//       ),
//       darkTheme: ThemeData(
//         useMaterial3: true,
//         colorScheme: ColorScheme.fromSeed(
//           seedColor: Colors.blue, 
//           brightness: Brightness.dark,
//         ),
//       ),
//       home: const HomeScreen(),
//     );
//   }
// }