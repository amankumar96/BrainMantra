import 'package:flutter/foundation.dart';

import '../models/app_language.dart';
import 'storage_service.dart';

/// Holds the player's current [AppLanguage] and makes it reactive
/// app-wide via `Provider` (see `main.dart`, which wraps `MaterialApp` in
/// a `ChangeNotifierProvider` built from this). Changing language from
/// anywhere (the login screen, the Settings screen) persists it and
/// notifies every listening widget immediately — no restart needed.
class LanguageController extends ChangeNotifier {
  LanguageController(this._language);

  AppLanguage _language;
  AppLanguage get language => _language;

  /// Loads the persisted preference (defaulting to English) before
  /// `runApp` — same "resolve local state before the widget tree exists"
  /// pattern as `NotificationService.initialize()`.
  static Future<LanguageController> load() async {
    final language = await StorageService.getLanguage();
    return LanguageController(language);
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;
    _language = language;
    notifyListeners();
    await StorageService.setLanguage(language);
  }
}
