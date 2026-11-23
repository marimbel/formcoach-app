// User settings from the Settings tab, saved on the phone with shared_preferences.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  SharedPreferences? _prefs;

  bool audioFeedback = true;
  bool frontCamera = true;
  ThemeMode themeMode = ThemeMode.light;
  String profileName = '';
  // Testing options (base-vs-tuned demos, evaluation runs)
  String coachModel = 'tuned'; // tuned | base | mock
  String scenario = '';

  static Future<AppSettings> load() async {
    final s = AppSettings();
    try {
      final p = await SharedPreferences.getInstance();
      s._prefs = p;
      s.audioFeedback = p.getBool('audio') ?? true;
      s.frontCamera = p.getBool('frontCamera') ?? true;
      s.themeMode = ThemeMode.values[(p.getInt('theme') ?? ThemeMode.light.index).clamp(0, 2)];
      s.profileName = p.getString('profileName') ?? '';
      s.coachModel = p.getString('coachModel') ?? 'tuned';
      s.scenario = p.getString('scenario') ?? '';
    } catch (_) {
      // Settings still work for this run; they just won't be remembered.
    }
    return s;
  }

  void setAudio(bool v) {
    audioFeedback = v;
    _prefs?.setBool('audio', v);
    notifyListeners();
  }

  void setFrontCamera(bool v) {
    frontCamera = v;
    _prefs?.setBool('frontCamera', v);
    notifyListeners();
  }

  void setTheme(ThemeMode m) {
    themeMode = m;
    _prefs?.setInt('theme', m.index);
    notifyListeners();
  }

  void setProfileName(String v) {
    profileName = v.trim();
    _prefs?.setString('profileName', profileName);
    notifyListeners();
  }

  void setCoachModel(String v) {
    coachModel = v;
    _prefs?.setString('coachModel', v);
    notifyListeners();
  }

  void setScenario(String v) {
    scenario = v.trim();
    _prefs?.setString('scenario', scenario);
    notifyListeners();
  }
}
