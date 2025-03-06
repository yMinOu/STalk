// frontAd.dart
import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';

class FrontAdManager {
  InterstitialAd? _interstitialAd;
  bool isAdLoaded = false;

  /// 전면 광고 로드
  void loadAd({VoidCallback? onAdLoaded, Function(LoadAdError)? onAdFailedToLoad}) {
    InterstitialAd.load(
      adUnitId: "ca-app-pub-3940256099942544/1033173712", // 테스트 광고 ID (실제 ID로 변경)
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          isAdLoaded = true;
          onAdLoaded?.call();
          // 광고가 닫히거나 실패하면 새 광고 로드
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              ad.dispose();
              isAdLoaded = false;
              loadAd(onAdLoaded: onAdLoaded, onAdFailedToLoad: onAdFailedToLoad);
            },
            onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
              ad.dispose();
              isAdLoaded = false;
              loadAd(onAdLoaded: onAdLoaded, onAdFailedToLoad: onAdFailedToLoad);
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          isAdLoaded = false;
          onAdFailedToLoad?.call(error);
        },
      ),
    );
  }

  /// 전면 광고 보여주기
  Future<void> showAd() async {
    if (_interstitialAd != null && isAdLoaded) {
      Completer<void> completer = Completer();
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          ad.dispose();
          isAdLoaded = false;
          loadAd();
          completer.complete();
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          ad.dispose();
          isAdLoaded = false;
          loadAd();
          completer.complete();
        },
      );
      _interstitialAd!.show();
      await completer.future;
    }
  }
}
