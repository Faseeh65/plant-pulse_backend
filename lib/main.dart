import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'l10n/app_localizations.dart';
import 'providers/locale_provider.dart';
import 'utils/app_theme.dart';
import 'utils/constants.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'services/causal_service.dart';
import 'services/database_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");

  // --- Session Guard Deployment ---
  final String supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final String supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    // Print which key is missing so it's easy to diagnose
    if (supabaseUrl.isEmpty) debugPrint('❌ .env: SUPABASE_URL is missing or empty.');
    if (supabaseAnonKey.isEmpty) debugPrint('❌ .env: SUPABASE_ANON_KEY is missing or empty.');
    debugPrint('⚠️ Supabase skipped — booting in full Offline Mode (SQLite + AI active).');
  } else {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      debugPrint('🎉 Supabase Initialized Successfully');
    } catch (e) {
      debugPrint('⚠️ Supabase Connection Failed: Booting in Offline Mode. Error: $e');
      // App continues so local features (SQLite & AI) remain active
    }
  }

  // --- Auth Session Guard Persistence ---
  // Only attach if Supabase was actually initialized (keys present)
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final Session? session = data.session;
        if (session != null) {
          debugPrint('👤 Active Session Found: ${session.user.email} (Ready for Offline Mode)');
        } else {
          debugPrint('🔓 No Active Session: Farmer redirected to login/auth.');
        }
      });
    } catch (e) {
      debugPrint('⚠️ Auth listener skipped: $e');
    }
  }

  final causalService = CausalService();
  await causalService.init();

  // Integrated sync remains safe; it handles null session internally
  final dbService = DatabaseService();
  await dbService.syncOfflineScans();

  final localeProvider = LocaleProvider();
  await localeProvider.loadSaved();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A1108),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    ChangeNotifierProvider.value(
      value: localeProvider,
      child: const PlantPulseApp(),
    ),
  );
}

class PlantPulseApp extends StatelessWidget {
  const PlantPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;

    return MaterialApp(
      title: 'PlantPulse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A1108),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6CFB7B),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/auth': (context) => const AuthScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
