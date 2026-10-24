import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reading preferences, remembered between launches.
class Settings extends ChangeNotifier {
  Settings._(this._prefs);

  static Future<Settings> load() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      prefs = null;
    }
    return Settings._(prefs);
  }

  final SharedPreferences? _prefs;

  bool _bool(String key, bool fallback) => _prefs?.getBool(key) ?? fallback;

  bool get showTransliteration => _bool('showTransliteration', true);
  bool get showEnglish => _bool('showEnglish', true);
  bool get showPunjabi => _bool('showPunjabi', false);
  double get textScale => _prefs?.getDouble('textScale') ?? 1.0;

  /// Null until the user has been asked about notifications once.
  bool? get notifications => _prefs?.getBool('notifications');

  Future<void> set(String key, Object value) async {
    final prefs = _prefs;
    if (prefs != null) {
      if (value is bool) await prefs.setBool(key, value);
      if (value is double) await prefs.setDouble(key, value);
    }
    notifyListeners();
  }
}
