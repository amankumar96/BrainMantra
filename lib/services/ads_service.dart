import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../utils/constants.dart';

/// Wraps `google_mobile_ads` (banner, interstitial, and rewarded — see
/// ARCHITECTURE.md's Phase 4 write-up; rewarded was originally out of
/// scope for lack of a real reward to attach it to, revisited once
/// "Watch Ad for Hint" gave it one) plus its bundled UMP consent flow
/// (required for EEA/UK users since Jan 2024).
///
/// Every public method is deliberately defensive: `google_mobile_ads` has
/// no Flutter Web support at all (this project's dev loop runs via
/// `flutter run -d chrome`), and its platform channel isn't registered
/// under `flutter test` either — so every SDK touch-point is wrapped so a
/// missing platform/plugin never breaks app startup or an existing widget
/// test. Same "best-effort, never load-bearing" precedent already set for
/// every Supabase call in this codebase (see `game_screen.dart`'s
/// `_persistAndShowResults`).
class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  // Real Android ad units — Brain Mantra's own AdMob account
  // (ca-app-pub-8749509325638633/...), created once the app was renamed
  // and its package ID finalized (AdMob registers an app by package
  // name, so this had to wait for that rename — see the rebrand plan).
  static const String _realInterstitialAndroid =
      'ca-app-pub-8749509325638633/4818322143';
  static const String _realBannerAndroid =
      'ca-app-pub-8749509325638633/5794071478';
  static const String _realRewardedAndroid =
      'ca-app-pub-8749509325638633/9879077134';

  // iOS: no AdMob app/ad units registered yet (this project is
  // Android-first) — TUNABLE, still Google's published TEST ad-unit IDs.
  // MUST be swapped for real ones before any iOS release build.
  static const String _testInterstitialIOS =
      'ca-app-pub-3940256099942544/4411468910';
  static const String _testBannerIOS = 'ca-app-pub-3940256099942544/2934735716';
  static const String _testRewardedIOS =
      'ca-app-pub-3940256099942544/1712485313';

  static String get _interstitialAdUnitId =>
      defaultTargetPlatform == TargetPlatform.iOS
      ? _testInterstitialIOS
      : _realInterstitialAndroid;

  static String get _bannerAdUnitId =>
      defaultTargetPlatform == TargetPlatform.iOS
      ? _testBannerIOS
      : _realBannerAndroid;

  static String get _rewardedAdUnitId =>
      defaultTargetPlatform == TargetPlatform.iOS
      ? _testRewardedIOS
      : _realRewardedAndroid;

  // Play Console's Target Audience declaration is a legal/business call —
  // flip this if that declaration ever includes children. Sexual/mature
  // ad-content filtering is deliberately NOT set here at all — handled
  // entirely via the AdMob dashboard's Blocking controls > Sensitive
  // categories, which is managed there directly rather than in code.
  static const bool isChildDirectedTreatment = false;

  InterstitialAd? _interstitialAd;
  bool _isLoadingInterstitial = false;
  RewardedAd? _rewardedAd;
  bool _isLoadingRewarded = false;

  // TEMPORARY, debug-only: registers specific physical devices as AdMob
  // "test devices" so they always get guaranteed test ad fill instead of
  // real inventory — real ad units can show `ERROR_CODE_NO_FILL` for
  // hours/days on a brand-new AdMob account before real demand ramps up,
  // and this is how placement/frequency/UMP behavior gets verified on a
  // real device in the meantime. Hashed device IDs (not personal data),
  // logged by the SDK itself on first run — see logcat's own
  // `addTestDeviceHashedId(...)` suggestion. Guarded by kDebugMode below
  // so this can never affect a real release build; remove entries once
  // real ad fill is confirmed working and this is no longer needed.
  static const List<String> _debugTestDeviceIds = [
    'B70BE1903265316E13E37EACC45AD7B4', // 2311DRN14I
  ];

  /// Call once from `main()`, after `Supabase.initialize(...)`, before
  /// `runApp`. Never throws — an ad SDK failing to initialize must not
  /// block the app from starting.
  Future<void> initialize() async {
    if (kIsWeb) return; // no web support in google_mobile_ads at all
    try {
      await MobileAds.instance.initialize();
      if (isChildDirectedTreatment || kDebugMode) {
        MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(
            ageRestrictedTreatment: isChildDirectedTreatment
                ? AgeRestrictedTreatment.child
                : null,
            testDeviceIds: kDebugMode ? _debugTestDeviceIds : null,
          ),
        );
      }
      await _requestConsentIfNeeded();
      loadInterstitial();
      loadRewarded();
    } catch (_) {
      // Ads are best-effort — see class doc comment.
    }
  }

  /// UMP: requests a consent-info update, then shows the consent form if
  /// one is required (EEA/UK) before any ad is ever requested. Bounded by
  /// a timeout so a stalled consent flow can never hang app startup.
  Future<void> _requestConsentIfNeeded() async {
    final completer = Completer<void>();
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () {
          ConsentForm.loadAndShowConsentFormIfRequired((_) {
            if (!completer.isCompleted) completer.complete();
          });
        },
        (FormError _) {
          if (!completer.isCompleted) completer.complete();
        },
      );
    } catch (_) {
      if (!completer.isCompleted) completer.complete();
    }
    await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {},
    );
  }

  Future<bool> _canRequestAds() async {
    if (kIsWeb) return false;
    try {
      return await ConsentInformation.instance.canRequestAds();
    } catch (_) {
      return false;
    }
  }

  /// Pre-caches the next interstitial. Safe to call repeatedly — a no-op
  /// while one is already loaded or a load is already in flight.
  void loadInterstitial() {
    if (kIsWeb || _interstitialAd != null || _isLoadingInterstitial) return;
    _isLoadingInterstitial = true;
    _canRequestAds()
        .then((allowed) {
          if (!allowed) {
            _isLoadingInterstitial = false;
            return;
          }
          InterstitialAd.load(
            adUnitId: _interstitialAdUnitId,
            request: const AdRequest(),
            adLoadCallback: InterstitialAdLoadCallback(
              onAdLoaded: (ad) {
                _isLoadingInterstitial = false;
                _interstitialAd = ad;
              },
              onAdFailedToLoad: (_) {
                _isLoadingInterstitial = false;
              },
            ),
          );
        })
        .catchError((_) {
          _isLoadingInterstitial = false;
        });
  }

  /// Shows the pre-cached interstitial if one is ready. Returns `true` if
  /// a show was actually attempted, `false` if none was loaded yet — an
  /// ad that isn't ready must never block or delay gameplay, so this is
  /// always a no-op rather than a wait.
  ///
  /// [onDismissed] fires once the shown ad is actually closed — and is
  /// deliberately **not** called at all when this returns `false`, or if
  /// the ad fails to actually display. Callers (the frequency-cap trigger
  /// in `game_screen.dart`) should reset their "last shown" counter from
  /// [onDismissed], not from the return value — that's what keeps the
  /// cap accurate: a question boundary where nothing was actually shown
  /// must not consume this session's ad allowance.
  bool showInterstitialIfLoaded({VoidCallback? onDismissed}) {
    final ad = _interstitialAd;
    if (kIsWeb || ad == null) return false;
    _interstitialAd = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadInterstitial(); // pre-cache the next one
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        // The ad never actually displayed — deliberately not calling
        // onDismissed, so the caller's frequency-cap counter stays "due"
        // and tries again at the next question boundary.
        ad.dispose();
        loadInterstitial();
      },
    );
    try {
      ad.show();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Pre-caches the next rewarded ad. Safe to call repeatedly — a no-op
  /// while one is already loaded or a load is already in flight.
  void loadRewarded() {
    if (kIsWeb || _rewardedAd != null || _isLoadingRewarded) return;
    _isLoadingRewarded = true;
    _canRequestAds()
        .then((allowed) {
          if (!allowed) {
            _isLoadingRewarded = false;
            return;
          }
          RewardedAd.load(
            adUnitId: _rewardedAdUnitId,
            request: const AdRequest(),
            rewardedAdLoadCallback: RewardedAdLoadCallback(
              onAdLoaded: (ad) {
                _isLoadingRewarded = false;
                _rewardedAd = ad;
              },
              onAdFailedToLoad: (_) {
                _isLoadingRewarded = false;
              },
            ),
          );
        })
        .catchError((_) {
          _isLoadingRewarded = false;
        });
  }

  /// Shows the pre-cached rewarded ad if one is ready. Returns `true` if
  /// a show was actually attempted, `false` if none was loaded yet.
  ///
  /// [onReward] fires only if the player actually watches to completion
  /// — [RewardedAd]'s own semantics, never for closing/skipping early —
  /// and is what callers (e.g. the "Watch Ad for Hint" button in
  /// `game_screen.dart`) should gate the actual reward on, not the
  /// return value. Unlike the interstitial, callers here are expected to
  /// have their own free fallback for "no ad ready" (this method never
  /// blocks on a load), matching the rest of this codebase's "ads are
  /// best-effort, never load-bearing" precedent — a hint feature must
  /// still work when ad infrastructure hiccups.
  bool showRewardedIfLoaded({required VoidCallback onReward}) {
    final ad = _rewardedAd;
    if (kIsWeb || ad == null) return false;
    _rewardedAd = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadRewarded(); // pre-cache the next one
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        loadRewarded();
      },
    );
    try {
      ad.show(onUserEarnedReward: (ad, reward) => onReward());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// The shared banner slot (Home and the Play/game screen — see
  /// ARCHITECTURE.md's Phase 4 write-up). Always safe to embed: collapses
  /// to nothing on web, in tests, or while unloaded — never throws.
  ///
  /// [showPlaceholder] controls what renders while no real ad is loaded
  /// yet (or one failed to load, e.g. `ERROR_CODE_NO_FILL`): `true` shows
  /// a designed "Your Ad Here" placeholder card instead of collapsing to
  /// nothing — used by both Home and the Play screen, so the ad slot
  /// always reads as an intentional part of the layout rather than a gap.
  /// Default `false` is only for callers (tests, mainly) that want the
  /// old collapse-to-nothing behavior.
  Widget bannerAdWidget({bool showPlaceholder = false}) {
    if (kIsWeb) return const SizedBox.shrink();
    return _BannerAdSlot(showPlaceholder: showPlaceholder);
  }
}

class _BannerAdSlot extends StatefulWidget {
  const _BannerAdSlot({required this.showPlaceholder});

  final bool showPlaceholder;

  @override
  State<_BannerAdSlot> createState() => _BannerAdSlotState();
}

class _BannerAdSlotState extends State<_BannerAdSlot> {
  BannerAd? _bannerAd;
  bool _requestedLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery is only reliably available once dependencies are ready —
    // guarded to only ever fire the load request once per widget.
    if (!_requestedLoad) {
      _requestedLoad = true;
      _loadAd();
    }
  }

  Future<void> _loadAd() async {
    try {
      final allowed = await AdsService.instance._canRequestAds();
      if (!allowed || !mounted) return;
      final width = MediaQuery.sizeOf(context).width.truncate();
      final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
      if (size == null || !mounted) return;
      final ad = BannerAd(
        adUnitId: AdsService._bannerAdUnitId,
        request: const AdRequest(),
        size: size,
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (mounted) setState(() => _bannerAd = ad as BannerAd);
          },
          onAdFailedToLoad: (ad, _) => ad.dispose(),
        ),
      );
      await ad.load();
    } catch (_) {
      // No banner shown this session — never break Home over this.
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    if (ad == null) {
      return widget.showPlaceholder
          ? const _AdPlaceholderCard()
          : const SizedBox.shrink();
    }
    final adWidget = SafeArea(
      top: false,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
    if (!widget.showPlaceholder) return adWidget;
    // Home only — wrap the real, loaded ad in the same rounded/padded
    // card shape _AdPlaceholderCard uses, so this slot doesn't visually
    // "jump" in shape once a real ad actually loads and replaces the
    // placeholder.
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.adPlaceholderCard,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: adWidget,
    );
  }
}

/// Shown in the banner slot whenever a real ad hasn't loaded yet (or
/// failed to — e.g. `ERROR_CODE_NO_FILL` while a brand-new AdMob account
/// is still propagating) — a designed placeholder instead of leaving a
/// blank gap in the Home layout. Purely decorative: "Advertise Now" is
/// not a real, tappable call-to-action.
class _AdPlaceholderCard extends StatelessWidget {
  const _AdPlaceholderCard();

  @override
  Widget build(BuildContext context) {
    return DottedAdBorder(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.adPlaceholderCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -4,
              left: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Ad',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                children: [
                  const Icon(
                    Icons.campaign,
                    size: 40,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Your Ad Here',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Reach thousands of learners daily',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Advertise Now',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A dashed-border frame around [child] — `BoxDecoration.border` has no
/// dashed style built in, so this hand-paints one via `CustomPaint`,
/// matching this project's established convention (`diagram_painter.dart`,
/// `feedback_overlay.dart`) of a small hand-rolled painter rather than a
/// new package for a single decorative border.
class DottedAdBorder extends StatelessWidget {
  const DottedAdBorder({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DashedBorderPainter(), child: child);
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(16),
    );
    final path = Path()..addRRect(rrect);
    const dashWidth = 6.0;
    const dashGap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => false;
}
