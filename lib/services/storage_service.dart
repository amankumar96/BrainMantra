import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_language.dart';
import '../models/game_session.dart';
import '../models/player_stats.dart';

/// A thin wrapper around the phone's local key-value storage
/// (`shared_preferences`), so the rest of the app never has to think
/// about JSON encoding or storage keys directly. Converts to/from the
/// same `toJson`/`fromJson` format the Phase 0 models already know.
abstract final class StorageService {
  static const String _statsKey = 'player_stats';
  static const String _lastSessionKey = 'last_session';
  static const String _hasSeenRulesKey = 'has_seen_rules';
  static const String _hasSeenPlayTutorialKey = 'has_seen_play_tutorial';
  static const String _languageKey = 'app_language';

  /// Persists [stats], overwriting whatever was saved before.
  static Future<void> saveStats(PlayerStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statsKey, jsonEncode(stats.toJson()));
  }

  /// Loads the last saved [PlayerStats]. Never throws: returns a fresh
  /// default `PlayerStats()` both when nothing has been saved yet (first
  /// launch) and when the stored data is somehow corrupted/unreadable —
  /// the app should never crash over a missing or bad save file.
  static Future<PlayerStats> loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_statsKey);
    if (raw == null) return PlayerStats();
    try {
      return PlayerStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupted or unexpectedly-shaped stored data — fall back to
      // defaults rather than propagate the parse error to the caller.
      return PlayerStats();
    }
  }

  /// Persists [session] as the most recent game session played.
  static Future<void> saveSession(GameSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSessionKey, jsonEncode(session.toJson()));
  }

  /// Whether the player has ever dismissed the rules dialog — checked
  /// once, right after they first reach the home screen, so it's shown
  /// automatically exactly once (an info icon lets them reopen it
  /// anytime afterward; see rules_dialog.dart).
  static Future<bool> hasSeenRules() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenRulesKey) ?? false;
  }

  static Future<void> markRulesSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenRulesKey, true);
  }

  /// Whether the player has ever completed (or dismissed) the one-time
  /// gameplay walkthrough — checked once, the very first time
  /// `GameScreen` opens in any mode (Play, Daily Challenge, or an
  /// Age-Group Test all share this one flag; the walkthrough covers
  /// controls common to all of them, so it only needs to show once ever,
  /// not per mode).
  static Future<bool> hasSeenPlayTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenPlayTutorialKey) ?? false;
  }

  static Future<void> markPlayTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenPlayTutorialKey, true);
  }

  /// The player's chosen UI/question language — a device setting, not
  /// account data (unlike `PlayerStats`), so it's kept separate and
  /// deliberately survives `clearAll()`/account deletion. Defaults to
  /// English on a fresh install or if nothing was ever saved.
  static Future<AppLanguage> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_languageKey);
    return AppLanguage.values.firstWhere(
      (l) => l.name == raw,
      orElse: () => AppLanguage.english,
    );
  }

  static Future<void> setLanguage(AppLanguage language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language.name);
  }

  /// Erases everything this service has saved (stats, last session, and
  /// the "seen rules"/"seen tutorial" flags) — deliberately NOT the
  /// language preference, which is a device setting that should survive
  /// a deleted account.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_statsKey);
    await prefs.remove(_lastSessionKey);
    await prefs.remove(_hasSeenRulesKey);
    await prefs.remove(_hasSeenPlayTutorialKey);
  }
}
