import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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

  /// Erases everything this service has saved (stats, last session, and
  /// the "seen rules" flag).
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_statsKey);
    await prefs.remove(_lastSessionKey);
    await prefs.remove(_hasSeenRulesKey);
  }
}
