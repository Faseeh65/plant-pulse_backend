import 'package:flutter/material.dart';
import '../../utils/app_assets.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/language_toggle.dart';
import '../scan/scan_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>(); // rebuild on locale change
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Image.asset(
                AppAssets.logo,
                width: 220,
              ),
              const SizedBox(height: 48),
              const LanguageToggle(),
              const SizedBox(height: 64),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ScanScreen(),
                      fullscreenDialog: true,
                    ),
                  );
                },
                child: Text(l10n.scanButton),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
