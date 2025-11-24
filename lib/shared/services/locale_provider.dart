import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');
  bool _initialized = false;
  
  Locale get locale {
    // Lazy initialization on first access
    if (!_initialized) {
      _loadSavedLocale();
    }
    return _locale;
  }
  
  /// Load saved locale from Hive (called automatically on first access)
  void _loadSavedLocale() {
    _initialized = true;
    try {
      if (Hive.isBoxOpen('settings')) {
        final settingsBox = Hive.box('settings');
        final savedLanguageCode = settingsBox.get('language') as String?;
        if (savedLanguageCode != null) {
          _locale = Locale(savedLanguageCode);
          // Schedule a notification after the current frame to update UI
          WidgetsBinding.instance.addPostFrameCallback((_) {
            notifyListeners();
          });
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