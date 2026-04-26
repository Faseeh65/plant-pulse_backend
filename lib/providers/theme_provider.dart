import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = "isDarkMode";
  static const Color lightPrimary = Color(0xFF245C34);
  static const Color lightPrimaryDeep = Color(0xFF173F26);
  static const Color lightAccent = Color(0xFF7CA63B);
  static const Color lightBackground = Color(0xFFF3F7EE);
  static const Color lightSurface = Color(0xFFFCFEF8);
  static const Color lightSurfaceRaised = Color(0xFFE6F0DE);
  static const Color lightText = Color(0xFF1F3125);
  static const Color lightTextMuted = Color(0xFF627564);
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
    return prefs.getBool(_themeKey) ?? false; // Defaults to light mode
  }

  static final CardThemeData _cardTheme = CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0x2FFFFFFF), width: 1.25),
    ),
    margin: EdgeInsets.zero,
  );

  static final ElevatedButtonThemeData _buttonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 16),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 15,
        letterSpacing: 0.5,
      ),
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
      cardTheme: _cardTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.14), width: 1.25),
        ),
      ),
      elevatedButtonTheme: _buttonTheme,
      dividerColor: Colors.white.withOpacity(0.14),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: const Color(0xFFE0E0E0),
        displayColor: const Color(0xFFE0E0E0),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData(brightness: Brightness.light);

    return base.copyWith(
      primaryColor: lightPrimary,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: lightPrimary,
        secondary: lightAccent,
        tertiary: Color(0xFFD7A83C),
        surface: lightSurface,
        onPrimary: Colors.white,
        onSurface: lightText,
      ),
      canvasColor: lightBackground,
      shadowColor: const Color(0x120F2416),
      cardColor: lightSurface,
      cardTheme: _cardTheme.copyWith(
        elevation: 0,
        color: lightSurface,
        shadowColor: const Color(0x140F2416),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: lightPrimary.withOpacity(0.18), width: 1.25),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: lightText),
        titleTextStyle: TextStyle(
          color: lightText,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceRaised.withOpacity(0.82),
        hintStyle: const TextStyle(color: lightTextMuted, fontSize: 13),
        labelStyle: const TextStyle(color: lightTextMuted, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: lightPrimary.withOpacity(0.16),
            width: 1.2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: lightPrimary.withOpacity(0.16),
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: lightPrimary.withOpacity(0.34),
            width: 1.6,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightPrimaryDeep,
          side: BorderSide(color: lightPrimary.withOpacity(0.22), width: 1.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lightPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      dividerColor: lightPrimaryDeep.withOpacity(0.16),
      textTheme: GoogleFonts.interTextTheme(
        base.textTheme,
      ).apply(bodyColor: lightText, displayColor: lightText),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
