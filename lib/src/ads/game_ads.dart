import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

abstract class GameAds extends ChangeNotifier {
  bool get privacyOptionsRequired;

  Future<void> initialize();

  Future<void> showInterstitialAtNaturalBreak();

  Future<void> showPrivacyOptions();
}

class DisabledGameAds extends GameAds {
  @override
  bool get privacyOptionsRequired => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> showInterstitialAtNaturalBreak() async {}

  @override
  Future<void> showPrivacyOptions() async {}
}

class InterstitialFrequencyGate {
  InterstitialFrequencyGate({
    this.resultsPerAd = 3,
    this.minimumInterval = const Duration(minutes: 3),
    DateTime Function()? now,
  }) : assert(resultsPerAd > 0),
       assert(!minimumInterval.isNegative),
       _now = now ?? DateTime.now;

  final int resultsPerAd;
  final Duration minimumInterval;
  final DateTime Function() _now;
  int _terminalResults = 0;
  DateTime? _lastShownAt;

  bool registerResult() {
    _terminalResults += 1;
    if (_terminalResults % resultsPerAd != 0) return false;
    final lastShownAt = _lastShownAt;
    return lastShownAt == null ||
        _now().difference(lastShownAt) >= minimumInterval;
  }

  void markShown() => _lastShownAt = _now();
}

class GoogleGameAds extends GameAds {
  GoogleGameAds({
    InterstitialFrequencyGate? frequencyGate,
    MethodChannel? configurationChannel,
    DateTime Function()? now,
  }) : _frequencyGate = frequencyGate ?? InterstitialFrequencyGate(),
       _now = now ?? DateTime.now,
       _configurationChannel =
           configurationChannel ?? const MethodChannel(_channelName);

  static const _channelName = 'worde.com/ads_config';
  static const _configurationMethod = 'getConfig';
  static const _maximumCacheAge = Duration(hours: 1);

  final InterstitialFrequencyGate _frequencyGate;
  final DateTime Function() _now;
  final MethodChannel _configurationChannel;
  InterstitialAd? _interstitial;
  InterstitialAd? _presentedInterstitial;
  DateTime? _interstitialLoadedAt;
  String? _interstitialAdUnitId;
  int _loadGeneration = 0;
  bool _initializing = false;
  bool _initialized = false;
  bool _adsAllowed = false;
  bool _loading = false;
  bool _privacyOptionsRequired = false;
  bool _privacyOptionsShowing = false;
  bool _disposed = false;

  @override
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  @override
  Future<void> initialize() async {
    if (_disposed) return;
    if (_initialized) {
      if (_adsAllowed && !_privacyOptionsShowing) _loadInterstitial();
      return;
    }
    if (_initializing) return;
    _initializing = true;
    try {
      await _updateConsentInformation();
      await _refreshPrivacyOptionsRequirement();
      _adsAllowed = await _canRequestAds();
      if (_privacyOptionsShowing) {
        _adsAllowed = false;
        _discardInterstitial();
      } else if (_adsAllowed) {
        await _initializeAdsSdk();
      } else {
        _discardInterstitial();
      }
    } finally {
      _initializing = false;
    }
  }

  Future<void> _updateConsentInformation() async {
    final update = Completer<bool>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        if (!update.isCompleted) update.complete(true);
      },
      (error) {
        debugPrint('AdMob consent update failed: ${error.errorCode}');
        if (!update.isCompleted) update.complete(false);
      },
    );
    final updated = await update.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => false,
    );
    if (!updated || _disposed) return;
    await ConsentForm.loadAndShowConsentFormIfRequired((error) {
      if (error != null) {
        debugPrint('AdMob consent form failed: ${error.errorCode}');
      }
    }).timeout(
      const Duration(minutes: 2),
      onTimeout: () => debugPrint('AdMob consent form timed out.'),
    );
  }

  Future<bool> _canRequestAds() async {
    try {
      return await ConsentInformation.instance.canRequestAds();
    } on PlatformException catch (error) {
      debugPrint('AdMob consent status unavailable: ${error.code}');
      return false;
    }
  }

  Future<void> _refreshPrivacyOptionsRequirement() async {
    try {
      final required =
          await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
      if (!_disposed && _privacyOptionsRequired != required) {
        _privacyOptionsRequired = required;
        notifyListeners();
      }
    } on PlatformException catch (error) {
      debugPrint('AdMob privacy options unavailable: ${error.code}');
    }
  }

  Future<void> _initializeAdsSdk() async {
    if (_disposed || _initialized) return;
    final config = await _readConfiguration();
    final adUnitId = config['interstitialAdUnitId'];
    if (adUnitId == null ||
        !RegExp(r'^ca-app-pub-[0-9]{16}/[0-9]{10}$').hasMatch(adUnitId)) {
      debugPrint('AdMob interstitial ID is missing or invalid.');
      return;
    }
    _interstitialAdUnitId = adUnitId;
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(maxAdContentRating: MaxAdContentRating.t),
    );
    await MobileAds.instance.initialize();
    if (_disposed) return;
    _initialized = true;
    _loadInterstitial();
  }

  Future<Map<String, String>> _readConfiguration() async {
    try {
      final raw = await _configurationChannel.invokeMapMethod<String, Object?>(
        _configurationMethod,
      );
      return <String, String>{
        for (final entry in (raw ?? const <String, Object?>{}).entries)
          if (entry.value is String) entry.key: entry.value! as String,
      };
    } on PlatformException catch (error) {
      debugPrint('AdMob configuration unavailable: ${error.code}');
      return const <String, String>{};
    } on MissingPluginException {
      return const <String, String>{};
    }
  }

  void _loadInterstitial() {
    final adUnitId = _interstitialAdUnitId;
    if (_disposed ||
        !_adsAllowed ||
        _privacyOptionsShowing ||
        !_initialized ||
        _loading ||
        _interstitial != null ||
        adUnitId == null) {
      return;
    }
    final generation = _loadGeneration;
    _loading = true;
    unawaited(
      InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            if (generation != _loadGeneration) {
              ad.dispose();
              return;
            }
            _loading = false;
            if (_disposed || !_adsAllowed) {
              ad.dispose();
              return;
            }
            _interstitial = ad;
            _interstitialLoadedAt = _now();
          },
          onAdFailedToLoad: (error) {
            if (generation == _loadGeneration) _loading = false;
            debugPrint('AdMob interstitial load failed: ${error.code}');
          },
        ),
      ).catchError((Object error) {
        if (generation == _loadGeneration) _loading = false;
        debugPrint('AdMob interstitial request failed.');
      }),
    );
  }

  @override
  Future<void> showInterstitialAtNaturalBreak() async {
    if (_disposed) return;
    if (!_initialized || !_adsAllowed) {
      await initialize();
      if (_disposed || !_initialized || !_adsAllowed) return;
    }
    if (!_frequencyGate.registerResult()) return;
    final loadedAt = _interstitialLoadedAt;
    if (loadedAt != null && _now().difference(loadedAt) >= _maximumCacheAge) {
      _discardInterstitial();
      _loadInterstitial();
      return;
    }
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    _interstitial = null;
    _interstitialLoadedAt = null;
    _presentedInterstitial = ad;
    final dismissed = Completer<void>();
    var shown = false;
    var finalized = false;
    void finish() {
      if (!dismissed.isCompleted) dismissed.complete();
    }

    void finalizeAd({required bool reload}) {
      if (finalized) return;
      finalized = true;
      if (identical(_presentedInterstitial, ad)) {
        _presentedInterstitial = null;
      }
      ad.dispose();
      finish();
      if (reload) _loadInterstitial();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdShowedFullScreenContent: (_) {
        shown = true;
        _frequencyGate.markShown();
      },
      onAdDismissedFullScreenContent: (_) => finalizeAd(reload: true),
      onAdFailedToShowFullScreenContent: (_, error) {
        debugPrint('AdMob interstitial show failed: ${error.code}');
        finalizeAd(reload: true);
      },
    );
    try {
      await ad.show();
      await dismissed.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          finalizeAd(reload: true);
        },
      );
    } on Object {
      finalizeAd(reload: true);
    }
    if (!shown) finish();
  }

  @override
  Future<void> showPrivacyOptions() async {
    if (_disposed || _privacyOptionsShowing) return;
    _privacyOptionsShowing = true;
    _adsAllowed = false;
    _discardInterstitial();
    try {
      await ConsentForm.showPrivacyOptionsForm((error) {
        if (error != null) {
          debugPrint('AdMob privacy form failed: ${error.errorCode}');
        }
      }).timeout(
        const Duration(minutes: 2),
        onTimeout: () => debugPrint('AdMob privacy form timed out.'),
      );
      if (_disposed) return;

      // Invalidate anything that may have completed while the form was open,
      // then re-evaluate the user's latest consent before requesting again.
      _discardInterstitial();
      await _refreshPrivacyOptionsRequirement();
      _adsAllowed = await _canRequestAds();
      if (_adsAllowed && !_initialized) {
        await _initializeAdsSdk();
      }
    } finally {
      _privacyOptionsShowing = false;
      if (!_disposed && _adsAllowed) _loadInterstitial();
    }
  }

  void _discardInterstitial() {
    _loadGeneration += 1;
    _loading = false;
    _interstitialLoadedAt = null;
    _interstitial?.dispose();
    _interstitial = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _adsAllowed = false;
    _discardInterstitial();
    _presentedInterstitial?.dispose();
    _presentedInterstitial = null;
    super.dispose();
  }
}
