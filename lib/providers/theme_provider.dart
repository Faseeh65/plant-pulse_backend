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
      primaryColor: const Color(0xFF81C784),
      scaffoldBackgroundColor: const Color(0xFF121212),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF81C784),
        secondary: Color(0xFF81C784),
        surface: Color(0xFF1E1E1E),
        onPrimary: Colors.black,
        onSurface: Color(0xFFE0E0E0),
      ),
      cardColor: const Color(0xFF1E1E1E),
      cardTheme: _cardTheme,
      elevatedButtonTheme: _buttonTheme,
      dividerColor: Colors.white.withOpacity(0.08),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF121212),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.2, color: Color(0xFFE0E0E0)),
      ),
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(
        bodyColor: const Color(0xFFE0E0E0),
        displayColor: const Color(0xFFE0E0E0),
      ),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData(brightness: Brightness.light);
    return base.copyWith(
      primaryColor: const Color(0xFF1B5E20),
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF1B5E20),
        secondary: Color(0xFF1B5E20),
        surface: Color(0xFFFFFFFF),
        onPrimary: Colors.white,
        onSurface: Color(0xFF212121),
      ),
      cardColor: const Color(0xFFFFFFFF),
      cardTheme: _cardTheme.copyWith(
        elevation: 12,
        shadowColor: Colors.black.withOpacity(0.06),
      ),
      elevatedButtonTheme: _buttonTheme,
      dividerColor: Colors.black.withOpacity(0.06),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFAFAFA),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.2, color: Color(0xFF212121)),
      ),
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(
        bodyColor: const Color(0xFF212121),
        displayColor: const Color(0xFF212121),
      ),
    );
  }
}
