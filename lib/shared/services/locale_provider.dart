import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');

  LocaleProvider() {
    // Load saved locale immediately on construction
    _loadSavedLocale();
  }

  Locale get locale => _locale;

  /// Load saved locale from Hive (called on construction)
  void _loadSavedLocale() {
    try {
      if (Hive.isBoxOpen('settings')) {
        final settingsBox = Hive.box('settings');
        final savedLanguageCode = settingsBox.get('language') as String?;
        if (savedLanguageCode != null) {
          _locale = Locale(savedLanguageCode);
        }
      }
    } catch (e) {
      // If loading fails, use default locale
      _locale = const Locale('en');
    }
  }

  /// Change locale and persist to Hive
  Future<void> changeLocale(Locale locale) async {
    if (_locale != locale) {
      _locale = locale;
      notifyListeners();

      // Save to Hive
      try {
        if (Hive.isBoxOpen('settings')) {
          final settingsBox = Hive.box('settings');
          await settingsBox.put('language', locale.languageCode);
        }
      } catch (e) {
        // Persist failed, but locale change still applied in memory
      }
    }
  }
}
