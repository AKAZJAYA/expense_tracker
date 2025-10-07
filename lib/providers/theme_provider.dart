import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  static const String _themePrefKey = 'theme_mode';

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString(_themePrefKey) ?? 'System';
    _themeMode = _getThemeModeFromString(themeName);
    notifyListeners();
  }

  Future<void> setThemeMode(String themeName) async {
    _themeMode = _getThemeModeFromString(themeName);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePrefKey, themeName);
    notifyListeners();
  }

  ThemeMode _getThemeModeFromString(String themeName) {
    switch (themeName) {
      case 'Light':
        return ThemeMode.light;
      case 'Dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String get themeModeName {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      default:
        return 'System';
    }
  }
}