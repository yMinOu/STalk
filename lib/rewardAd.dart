import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 구글 애드몹 리워드 광고 매니저 (싱글톤)
class RewardAdManager {
  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;

  static final RewardAdManager _instance = RewardAdManager._internal();
  factory RewardAdManager() => _instance;
  RewardAdManager._internal();

  /// 리워드 광고 로드 (테스트 광고 ID 사용)
  void loadRewardAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917', // 테스트용 리워드 광고 ID
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          print('Rewarded ad loaded.');
          _rewardedAd = ad;
          _isAdLoaded = true;
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('Rewarded ad failed to load: $error');
          _isAdLoaded = false;
        },
      ),
    );
  }

  /// 리워드 광고 표시
  /// onUserEarnedReward: 사용자가 리워드를 획득했을 때 호출될 콜백
  void showRewardAd({required VoidCallback onUserEarnedReward}) {
    if (!_isAdLoaded || _rewardedAd == null) {
      print('Rewarded ad is not ready yet.');
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        print('Rewarded ad is shown.');
      },
      onAdDismissedFullScreenContent: (ad) {
        print('Rewarded ad dismissed.');
        ad.dispose();
        loadRewardAd(); // 광고가 닫힌 후 새로운 광고 로드
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        print('Rewarded ad failed to show: $error');
        ad.dispose();
        loadRewardAd();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        print('User earned reward: ${reward.amount} ${reward.type}');
        onUserEarnedReward();
      },
    );

    _rewardedAd = null;
    _isAdLoaded = false;
  }
}
