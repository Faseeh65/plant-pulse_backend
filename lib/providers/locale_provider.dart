import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  Future<void> loadSaved() async {
    // Force English always
    _locale = const Locale('en');
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    // Ignore requests to change from English
    _locale = const Locale('en');
    notifyListeners();
  }
}
