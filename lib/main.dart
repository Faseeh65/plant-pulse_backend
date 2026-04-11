import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'l10n/app_localizations.dart';
import 'providers/locale_provider.dart';
import 'utils/app_theme.dart';
import 'utils/constants.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  final localeProvider = LocaleProvider();
  await localeProvider.loadSaved();

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
      theme: AppTheme.light, // Set to luxury Light Theme
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      initialRoute: Supabase.instance.client.auth.currentSession != null 
          ? '/home' 
          : '/auth',
      routes: {
        '/auth': (context) => const AuthScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
