/// Decides when an interstitial ad is "due", based on how many questions
/// have been answered since the last one was shown. Pure counting logic —
/// no ad SDK dependency at all — so it's fully unit-testable without
/// mocking `google_mobile_ads`, matching `ARCHITECTURE.md`'s own
/// requirement that the frequency-cap "due" calculation be verifiable
/// independently of the actual ad SDK call.
///
/// Not a singleton/static class like most other services here — it holds
/// small mutable per-session counter state, so `AdsService` owns one
/// instance per game session (mirrors why `GameController` itself isn't
/// static).
class AdFrequencyCap {
  AdFrequencyCap({this.questionsBetweenAds = _defaultQuestionsBetweenAds});

  // TUNABLE — product rule: an interstitial at most once per 10 questions
  // answered, applied uniformly to both modes, to avoid ad fatigue.
  // Daily Challenge's fixed 10 questions means exactly one interstitial
  // right at the end; Play (infinite) gets one every 10 questions
  // throughout the session. Deliberately question-count-based, not
  // round/session-based — a "round" isn't a meaningful unit for Play,
  // which can run indefinitely without ever reaching a round-end.
  static const int _defaultQuestionsBetweenAds = 10;

  final int questionsBetweenAds;
  int _questionsSinceLastAd = 0;

  /// Call once per question answered (correct, wrong, or skipped) —
  /// deliberately a separate step from checking [isDue], so "counting"
  /// and "showing" stay independent actions.
  void recordQuestionAnswered() => _questionsSinceLastAd++;

  /// True once [questionsBetweenAds] questions have been recorded since
  /// the last time an ad was actually shown (or since construction, if
  /// none has been shown yet this session).
  bool get isDue => _questionsSinceLastAd >= questionsBetweenAds;

  /// Call after actually showing the interstitial — resets the counter so
  /// the next one isn't due again immediately.
  void recordAdShown() => _questionsSinceLastAd = 0;
}
