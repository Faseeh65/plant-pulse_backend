import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = "isDarkMode";
  late bool _isDarkMode;

  ThemeProvider(bool isDark) {
    _isDarkMode = isDark;
  }

  bool get isDarkMode => _isDarkMode;

  ThemeData get currentTheme => _isDarkMode ? darkTheme : lightTheme;

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
    notifyListeners();
  }

  static Future<bool> getSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themeKey) ?? true; // Defaults to dark mode
  }

  static final CardThemeData _cardTheme = CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    margin: EdgeInsets.zero,
  );

  static final ElevatedButtonThemeData _buttonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 16),
      textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5),
    ),
  );

  static ThemeData get darkTheme {
    final base = ThemeData(brightness: Brightness.dark);
    return base.copyWith(
      primaryColor: const Color(0xFF6CFB7B), // Neon Lime
      scaffoldBackgroundColor: const Color(0xFF0A0E0A), // Rich Black
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF6CFB7B),
        secondary: Color(0xFF6CFB7B),
        surface: Color(0xFF121A12), // Charcoal Forest
        onPrimary: Colors.black,
        onSurface: Color(0xFFE0E0E0),
      ),
      cardColor: const Color(0xFF121A12),
      cardTheme: _cardTheme,
      elevatedButtonTheme: _buttonTheme,
      dividerColor: Colors.white.withOpacity(0.08),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: const Color(0xFFE0E0E0),
        displayColor: const Color(0xFFE0E0E0),
      ),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData(brightness: Brightness.light);
    return base.copyWith(
      primaryColor: const Color(0xFF1B5E20),
      scaffoldBackgroundColor: const Color(0xFFF4FAF4), // Morning Mist
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF1B5E20),
        secondary: Color(0xFF2E7D32),
        surface: Color(0xFFFFFFFF),
        onPrimary: Colors.white,
        onSurface: Color(0xFF1A1A1A),
      ),
      cardColor: const Color(0xFFFFFFFF),
      cardTheme: _cardTheme.copyWith(
        elevation: 20,
        shadowColor: const Color(0xFF1B5E20).withOpacity(0.08),
      ),
      elevatedButtonTheme: _buttonTheme,
      dividerColor: Colors.black.withOpacity(0.06),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: const Color(0xFF1A1A1A),
        displayColor: const Color(0xFF1A1A1A),
      ),
    );
  }
}
