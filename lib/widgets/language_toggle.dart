import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../utils/app_theme.dart';

class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocaleProvider>();
    final isEn = provider.locale.languageCode == 'en';

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.toggleInactive,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Segment(
            label: 'EN',
            isActive: isEn,
            onTap: () => provider.setLocale(const Locale('en')),
          ),
          _Segment(
            label: 'UR',
            isActive: !isEn,
            onTap: () => provider.setLocale(const Locale('ur')),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        height: 44,
        decoration: BoxDecoration(
          color: isActive ? AppColors.accentGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
