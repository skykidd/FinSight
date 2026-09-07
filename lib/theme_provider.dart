import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  // Default Settings
  bool _isDarkMode = false;
  int _colorValue = Colors.deepPurple.value; // Default to Purple

  bool get isDarkMode => _isDarkMode;
  Color get primaryColor => Color(_colorValue);

  // Load saved theme when app starts
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _colorValue = prefs.getInt('themeColor') ?? Colors.deepPurple.value;
    notifyListeners(); // Tell the app to update
  }

  // Change to Dark/Light Mode
  Future<void> toggleTheme(bool isDark) async {
    _isDarkMode = isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
    notifyListeners();
  }

  // Change the Main Color
  Future<void> updateColor(Color color) async {
    _colorValue = color.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeColor', _colorValue);
    notifyListeners();
  }
}

// Global variable so we can access it from anywhere
final themeProvider = ThemeProvider();
