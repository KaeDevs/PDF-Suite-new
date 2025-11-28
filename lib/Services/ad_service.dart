import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/ad_constants.dart';

class AdService {
  InterstitialAd? _interstitialAd;
  bool _isAdReady = false;

  bool get isAdReady => _isAdReady;

  void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: AdConstants.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _isAdReady = true;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _isAdReady = false;
          _interstitialAd = null;
        },
      ),
    );
  }

  void showAdAndRun(Function task) {
    if (_isAdReady && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          ad.dispose();
          _interstitialAd = null;
          _isAdReady = false;
          loadInterstitialAd();
          task();
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, _) {
          ad.dispose();
          _interstitialAd = null;
          _isAdReady = false;
          loadInterstitialAd();
          task();
        },
      );

      _interstitialAd!.show();
      _isAdReady = false;
      _interstitialAd = null;
    } else {
      task();
    }
  }

  void dispose() {
    _interstitialAd?.dispose();
  }

  /// Shows an interstitial ad (if ready) while a background [taskFuture]
  /// is running. Returns the task result after BOTH the ad has closed and
  /// the task has completed. If the ad isn't ready, simply awaits the task.
  Future<T> showAdWhileFuture<T>(Future<T> taskFuture) async {
    final adClosed = Completer<void>();

    if (_isAdReady && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          ad.dispose();
          _interstitialAd = null;
          _isAdReady = false;
          adClosed.complete();
          // Preload the next ad for subsequent operations
          loadInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, _) {
          ad.dispose();
          _interstitialAd = null;
          _isAdReady = false;
          adClosed.complete();
          loadInterstitialAd();
        },
      );

      _interstitialAd!.show();
      _isAdReady = false;
      _interstitialAd = null;
    } else {
      // No ad available; consider it "closed" immediately.
      adClosed.complete();
    }

    // Wait for the task to complete and the ad to finish.
    final result = await taskFuture;
    await adClosed.future;
    return result;
  }
}