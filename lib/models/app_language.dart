/// The player's chosen content/UI language. English is the default for a
/// fresh install (see `StorageService.getLanguage()`).
///
/// Hindi here means basic, everyday Devanagari — simple vocabulary and
/// short sentence structures, not literary/formal Hindi — and currently
/// covers UI chrome and the math-question generators only; reasoning
/// questions (family tree, word puzzle, analogy, coding, direction sense,
/// statement/conclusion, seating arrangement, ranking) stay English-only
/// in both language modes for now (see the feature plan's "Known
/// limitations" for why).
enum AppLanguage {
  english,
  hindi;

  /// Display label for the language picker itself (login screen, Settings).
  String get label => switch (this) {
    AppLanguage.english => 'English',
    AppLanguage.hindi => 'हिंदी',
  };
}
