import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'l10n/app_localizations.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/reminder_screen.dart';
import 'screens/scanner_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/stats_screen.dart';
import 'services/causal_service.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'providers/map_provider.dart';
import 'providers/weather_provider.dart';
import 'screens/map_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init notification channel + timezone DB before anything else
  await NotificationService.instance.init();
  
  await dotenv.load(fileName: ".env");

  // --- Session Guard Deployment ---
  final String supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final String supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
    } catch (e) {
      debugPrint('⚠️ Supabase Connection Failed: $e');
    }
  }

  final causalService = CausalService();
  await causalService.init();

  final dbService = DatabaseService();
  await dbService.syncOfflineScans();

  final localeProvider = LocaleProvider();
  await localeProvider.loadSaved();

  final bool savedIsDark = await ThemeProvider.getSavedTheme();
  final themeProvider = ThemeProvider(savedIsDark);

  // Theme and Locale will be managed inside the build method via Providers
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: localeProvider),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => MapProvider()),
        ChangeNotifierProvider(create: (_) => WeatherProvider()),
      ],
      child: const PlantPulseApp(),
    ),
  );
}

class PlantPulseApp extends StatelessWidget {
  const PlantPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final locale = context.watch<LocaleProvider>().locale;

    // Apply dynamic status bar/nav bar brightness based on current theme
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: themeProvider.isDarkMode ? Brightness.light : Brightness.dark,
        statusBarBrightness: themeProvider.isDarkMode ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: themeProvider.isDarkMode ? const Color(0xFF0A1108) : Colors.white,
        systemNavigationBarIconBrightness: themeProvider.isDarkMode ? Brightness.light : Brightness.dark,
      ),
    );

    return MaterialApp(
      title: 'PlantPulse',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.currentTheme,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/auth': (context) => const AuthScreen(),
        '/home': (context) => const HomeScreen(),
        '/map': (context) => const MapScreen(),
        '/scanner': (context) => const ScannerScreen(),
        '/history': (context) => const HistoryScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/reminders': (context) => const ReminderScreen(),
        '/stats': (context) => const StatsScreen(),
      },
    );
  }
}
