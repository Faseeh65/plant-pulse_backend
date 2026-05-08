import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/causal_logic.dart';
import '../models/disease_result.dart';
import '../services/api_service.dart';
import '../services/causal_service.dart';
import '../utils/string_extensions.dart';
import '../utils/rice_health_logic.dart';
import '../providers/weather_provider.dart';
import '../models/weather_data.dart';
import 'treatment_detail_screen.dart';
import 'reminder_screen.dart';
import '../providers/locale_provider.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:share_plus/share_plus.dart';

class ResultsScreen extends StatefulWidget {
  final String imagePath;
  final String diseaseNameEnglish;
  final String diseaseNameUrdu;
  final double confidence;
  final bool isRefined;
  final bool secondaryInspectionRequired;
  final DiseaseResult diagnosisData;

  const ResultsScreen({
    super.key,
    required this.imagePath,
    required this.diseaseNameEnglish,
    required this.diseaseNameUrdu,
    required this.confidence,
    this.isRefined = false,
    this.secondaryInspectionRequired = false,
    required this.diagnosisData,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> with TickerProviderStateMixin {
  CausalRule? _rule;
  late AnimationController _scanningController;
  late Animation<double> _scanLineAnimation;
  late AnimationController _typewriterController;
  late Animation<int> _typewriterAnimation;
  late AnimationController _countUpController;
  late Animation<double> _countUpAnimation;
  late AnimationController _badgeController;
  late Animation<double> _badgeScaleAnimation;
  late AnimationController _sectionsController;

  @override
  void initState() {
    super.initState();
    _rule = CausalService().getRuleForLabel(widget.diseaseNameEnglish);
    _saveToCloudSilently();

    final String cleanName = widget.diseaseNameEnglish.toDiseaseOnly();
    
    _scanningController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _scanLineAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _scanningController, curve: Curves.easeInOut),
    );

    _typewriterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _typewriterAnimation = StepTween(begin: 0, end: cleanName.length).animate(
      CurvedAnimation(parent: _typewriterController, curve: Curves.easeIn),
    );
    _typewriterController.forward();

    _countUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _countUpAnimation = Tween<double>(begin: 0.0, end: widget.confidence).animate(
      CurvedAnimation(parent: _countUpController, curve: Curves.easeOutCubic),
    );
    _countUpController.forward();

    _badgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _badgeScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.2), weight: 70),
      TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _badgeController, curve: Curves.easeInOut));
    _badgeController.forward();

    _sectionsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _sectionsController.forward();
  }

  @override
  void dispose() {
    _scanningController.dispose();
    _typewriterController.dispose();
    _countUpController.dispose();
    _badgeController.dispose();
    _sectionsController.dispose();
    super.dispose();
  }

  Future<void> _saveToCloudSilently() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return; 

    final plantName = widget.diseaseNameEnglish.toDisplayCrop();
    await ApiService().saveScanResult(
      userId:          userId,
      plantName:       plantName,
      diseaseResult:   widget.diseaseNameEnglish,
      confidenceScore: widget.confidence,
    );
  }

  void _shareReport() {
    final String plantType = widget.diseaseNameEnglish.toDisplayCrop();
    final String cleanName = widget.diseaseNameEnglish.toDiseaseOnly();
    final String confidence = (widget.confidence * 100).toStringAsFixed(1);
    final weather = Provider.of<WeatherProvider>(context, listen: false).currentWeather;
    
    String reportText = '🌿 *Plant Pulse Diagnosis Report*\n\n';
    reportText += '🔸 *Crop:* $plantType\n';
    reportText += '🔸 *Health Status:* $cleanName\n';
    reportText += '🔸 *Confidence:* $confidence%\n';
    
    if (weather != null) {
      reportText += '📍 *Location:* ${weather.locationName}\n';
      reportText += '🌡️ *Temp:* ${weather.temp.toStringAsFixed(1)}°C\n';
    }
    
    if (_rule != null) {
      reportText += '\n📋 *Symptoms:*\n${_rule!.symptoms}\n';
      if (_rule!.treatmentEn.isNotEmpty) {
        reportText += '\n🧪 *Recommended Treatment:*\n${_rule!.treatmentEn}\n';
      }
    }
    
    reportText += '\n_Generated by Plant Pulse AI_';

    Share.share(reportText, subject: 'Plant Pulse Diagnosis - $plantType');
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'none':      return const Color(0xFF2ECC71);
      case 'moderate':  return const Color(0xFFFFB300);
      case 'high':      return const Color(0xFFFF6D00);
      case 'very_high': return const Color(0xFFFF5252);
      default:          return Colors.grey;
    }
  }

  String _getSeverityLabel(String severity) {
    switch (severity.toLowerCase()) {
      case 'none':      return 'Healthy';
      case 'moderate':  return 'Moderate';
      case 'high':      return 'Serious';
      case 'very_high': return 'Critical';
      default:          return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String cleanName = widget.diseaseNameEnglish.toDiseaseOnly();
    final String plantType = widget.diseaseNameEnglish.toDisplayCrop();
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final weather = context.watch<WeatherProvider>().currentWeather;
    final primaryColor = Theme.of(context).primaryColor;
    final locale = context.watch<LocaleProvider>().locale;
    final isUrdu = locale.languageCode == 'ur';

    final String displayCrop = isUrdu && _rule?.nameUr != null && _rule!.nameUr.isNotEmpty ? _rule!.nameUr.split(' ').first : plantType;
    final String displayDisease = isUrdu && _rule?.nameUr != null && _rule!.nameUr.isNotEmpty ? _rule!.nameUr : cleanName;

    return Scaffold(
      body: Stack(
        children: [
          // ── Background Layer ───────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).scaffoldBackgroundColor,
                  primaryColor.withValues(alpha: 0.05),
                ],
              ),
            ),
          ),
          
          // Watermark leaf texture (faint)
          Positioned(
            right: -100,
            top: -50,
            child: Opacity(
              opacity: 0.05,
              child: Icon(Icons.eco, size: 400, color: primaryColor),
            ),
          ),

          // ── Main Content ───────────────────────────────────────────────────────
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 110),
                
                // 1. Header with Weather Badge
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                            Text(
                              displayCrop,
                              style: GoogleFonts.poppins(
                                fontSize: 44, 
                                fontWeight: FontWeight.w900, 
                                color: primaryColor, 
                                letterSpacing: -1.5,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                displayDisease.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 12, 
                                  color: primaryColor, 
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(width: 16),
                      Flexible(child: weather != null ? _buildWeatherBadge(weather) : const SizedBox.shrink()),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_user_rounded, color: primaryColor, size: 18),
                        const SizedBox(width: 10),
                        AnimatedBuilder(
                          animation: _countUpAnimation,
                          builder: (context, child) {
                            double val = disableAnimations ? widget.confidence : _countUpAnimation.value;
                            return Text(
                              'DIAGNOSTIC CONFIDENCE: ${(val * 100).toStringAsFixed(1)}%',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w900, 
                                color: primaryColor,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // 2. Image Diagnosis Widget with Scanning Animation
                _buildAnalysisFrame(),

                const SizedBox(height: 40),

                // 3. Diagnosis Intelligence Grid/Scroll
                _buildIntelligenceSection(),

                const SizedBox(height: 32),

                // 4. Environmental Context
                if (weather != null) _buildEnvironmentalSection(weather),

                const SizedBox(height: 12),

                // 5. Treatment Action Tiles
                _buildTreatmentActions(),

                const SizedBox(height: 60),
              ],
            ),
          ),

          // Back Button
          Positioned(
            top: 50,
            left: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).textTheme.bodyLarge?.color, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherBadge(WeatherData weather) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                weather.locationName, 
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${weather.temp.toStringAsFixed(1)}°C', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -1)),
                  const SizedBox(width: 8),
                  const Icon(Icons.thermostat, size: 14, color: Colors.redAccent),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${weather.humidity}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                  const SizedBox(width: 4),
                  const Icon(Icons.water_drop, size: 12, color: Colors.blueAccent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisFrame() {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        height: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(File(widget.imagePath), fit: BoxFit.cover, cacheWidth: 800),
              // Target Crosshairs
              _buildCrosshairs(),
              // Scanning Line Animation
              AnimatedBuilder(
                animation: _scanLineAnimation,
                builder: (context, child) {
                  return Positioned(
                    top: 280 * _scanLineAnimation.value,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        boxShadow: [BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.8), blurRadius: 10, spreadRadius: 2)],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCrosshairs() {
    return Stack(
      children: [
        Center(child: Container(width: 40, height: 40, decoration: BoxDecoration(border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1)))),
        Center(child: Container(width: 2, height: 60, color: Colors.white.withValues(alpha: 0.3))),
        Center(child: Container(width: 60, height: 2, color: Colors.white.withValues(alpha: 0.3))),
      ],
    );
  }

  Widget _buildIntelligenceSection() {
    final primaryColor = Theme.of(context).primaryColor;
    final locale = context.read<LocaleProvider>().locale;
    final isUrdu = locale.languageCode == 'ur';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.psychology_outlined, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                isUrdu ? 'تشخیصی معلومات' : 'Diagnosis Intelligence', 
                style: GoogleFonts.poppins(
                  fontSize: 20, 
                  fontWeight: FontWeight.w900, 
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 160,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildIntelCard(isUrdu ? 'سائنسی نام' : 'Scientific', _rule?.scientificName ?? 'N/A', Icons.biotech_rounded, primaryColor),
              _buildIntelCard(isUrdu ? 'علامات' : 'Symptoms', isUrdu && _rule?.symptoms != null ? _rule!.symptoms : (_rule?.symptoms ?? 'N/A'), Icons.visibility_rounded, Colors.orangeAccent),
              _buildIntelCard(isUrdu ? 'بنیادی وجہ' : 'Primary Cause', isUrdu && _rule?.cause != null ? _rule!.cause : (_rule?.cause ?? 'N/A'), Icons.info_outline_rounded, Colors.blueAccent),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntelCard(String title, String val, IconData icon, Color accentColor) {
    return Container(
      width: 190,
      margin: const EdgeInsets.only(right: 16, bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04), 
            blurRadius: 15, 
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: accentColor),
                    const SizedBox(width: 8),
                    Text(
                      title.toUpperCase(), 
                      style: GoogleFonts.inter(
                        fontSize: 10, 
                        fontWeight: FontWeight.w900, 
                        color: accentColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Text(
                    val,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12, 
                      fontWeight: FontWeight.w500, 
                      height: 1.4,
                      color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnvironmentalSection(WeatherData weather) {
    final alert = RiceHealthLogic.getEnvironmentalAlert(weather.humidity, weather.temp);
    final isCritical = weather.humidity > 85;
    final primaryColor = Theme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_sync_rounded, color: primaryColor, size: 20),
                const SizedBox(width: 12),
                Text(
                  'Environmental Context', 
                  style: GoogleFonts.poppins(
                    fontSize: 18, 
                    fontWeight: FontWeight.w900, 
                    color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      weather.locationName.toUpperCase(), 
                      style: GoogleFonts.inter(
                        fontSize: 10, 
                        fontWeight: FontWeight.w900, 
                        color: primaryColor,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${weather.temp.toStringAsFixed(1)}°C', 
                          style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Container(width: 1, height: 15, color: Theme.of(context).dividerColor),
                        ),
                        Text(
                          '${weather.humidity}% Humid', 
                          style: GoogleFonts.poppins(
                            fontSize: 18, 
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (alert['color'] as Color).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCritical ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded, 
                    color: alert['color'], 
                    size: 28,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (alert['color'] as Color).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: (alert['color'] as Color).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(alert['icon'], color: alert['color'], size: 20),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      alert['message'],
                      style: GoogleFonts.inter(
                        color: alert['color'], 
                        fontWeight: FontWeight.w800, 
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTreatmentActions() {
    final locale = context.read<LocaleProvider>().locale;
    final isUrdu = locale.languageCode == 'ur';
    final String treatment = isUrdu && _rule != null && _rule!.treatmentUr.isNotEmpty ? _rule!.treatmentUr : (_rule?.treatmentEn ?? widget.diagnosisData.instruction);
    final String prevention = isUrdu && _rule != null && _rule!.prevention.isNotEmpty ? _rule!.prevention : (_rule?.prevention ?? 'Monitor crop regularly.');
    final primaryColor = Theme.of(context).primaryColor;
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recommended Actions', 
            style: GoogleFonts.poppins(
              fontSize: 20, 
              fontWeight: FontWeight.w900, 
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildActionTile(
                isUrdu ? 'علاج' : 'Primary Treatment', 
                treatment.split('.').first,
                Icons.health_and_safety_rounded, 
                Colors.tealAccent.shade700
              ),
              const SizedBox(width: 16),
              _buildActionTile(
                isUrdu ? 'احتیاط' : 'Prevention', 
                prevention.split('.').first, 
                Icons.shield_rounded, 
                Colors.indigoAccent
              ),
            ],
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReminderScreen(
                    initialPlant: widget.diseaseNameEnglish.toDisplayCrop(),
                    initialDisease: widget.diseaseNameEnglish.toDiseaseOnly(),
                    initialTreatment: _rule?.treatmentEn,
                  ),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withBlue(100)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.alarm_add_rounded, size: 22, color: Colors.black),
                  const SizedBox(width: 12),
                  Text(
                    'SCHEDULE TREATMENT REMINDER',
                    style: GoogleFonts.orbitron(
                      fontWeight: FontWeight.w900, 
                      letterSpacing: 0.5,
                      fontSize: 13,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: OutlinedButton.icon(
              onPressed: _shareReport,
              icon: Icon(Icons.share_rounded, size: 20, color: primaryColor),
              label: Text(
                'SHARE DIAGNOSTIC REPORT',
                style: GoogleFonts.orbitron(
                  fontWeight: FontWeight.w900, 
                  letterSpacing: 0.5, 
                  color: primaryColor,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: primaryColor, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(String title, String action, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(
              title, 
              style: GoogleFonts.orbitron(
                fontSize: 9, 
                color: color.withValues(alpha: 0.8), 
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              action, 
              style: GoogleFonts.rajdhani(
                fontSize: 14, 
                fontWeight: FontWeight.w700, 
                color: color,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedSection(int index, Widget child) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    if (disableAnimations) return child;

    return FadeTransition(
      opacity: _getSectionFade(index),
      child: SlideTransition(
        position: _getSectionSlide(index),
        child: child,
      ),
    );
  }

  Animation<double> _getSectionFade(int index) {
    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sectionsController,
        curve: Interval(
          (0.1 * index).clamp(0.0, 0.8),
          (0.1 * index + 0.2).clamp(0.0, 1.0),
          curve: Curves.easeIn,
        ),
      ),
    );
  }

  Animation<Offset> _getSectionSlide(int index) {
    return Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _sectionsController,
        curve: Interval(
          (0.1 * index).clamp(0.0, 0.8),
          (0.1 * index + 0.2).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }

  Widget _buildDualReportBox(String title, String en, String ur, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.orbitron(color: color, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            en,
            style: GoogleFonts.rajdhani(
              color: Theme.of(context).textTheme.bodyLarge?.color, 
              fontSize: 15, 
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleInfoBox(String title, String en, {required IconData icon, Color color = Colors.grey}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(
                title, 
                style: GoogleFonts.orbitron(color: color, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            en, 
            style: GoogleFonts.rajdhani(
              color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.9), 
              fontSize: 14, 
              height: 1.3,
              fontWeight: FontWeight.w500,
            )
          ),
        ],
      ),
    );
  }

  Widget _buildReportRow(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
