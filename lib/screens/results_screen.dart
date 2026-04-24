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
import 'package:provider/provider.dart';
import 'dart:ui';

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

    return Scaffold(
      body: Stack(
        children: [
          // ── Background Layer ───────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE0F7FA), Color(0xFFF1F8E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Watermark leaf texture (faint)
          Opacity(
            opacity: 0.1,
            child: Icon(Icons.eco, size: 400, color: Colors.green.withOpacity(0.2)),
          ),

          // ── Main Content ───────────────────────────────────────────────────────
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 50),
                
                // 1. Header with Weather Badge
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plantType,
                              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Color(0xFF1B5E20), letterSpacing: -1.5),
                            ),
                            Text(
                              _rule?.urduName ?? '', 
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                            ),
                            Text(
                              cleanName,
                              style: TextStyle(fontSize: 18, color: Colors.black.withOpacity(0.5), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      if (weather != null) _buildWeatherBadge(weather),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 18),
                      const SizedBox(width: 8),
                      AnimatedBuilder(
                        animation: _countUpAnimation,
                        builder: (context, child) {
                          double val = disableAnimations ? widget.confidence : _countUpAnimation.value;
                          return Text(
                            'Confidence: ${(val * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // 2. Image Diagnosis Widget with Scanning Animation
                _buildAnalysisFrame(),

                const SizedBox(height: 30),

                // 3. Diagnosis Intelligence Grid/Scroll
                _buildIntelligenceSection(),

                const SizedBox(height: 24),

                // 4. Environmental Context
                if (weather != null) _buildEnvironmentalSection(weather),

                // 5. Treatment Action Tiles
                _buildTreatmentActions(),

                const SizedBox(height: 40),
              ],
            ),
          ),

          // Back Button
          Positioned(
            top: 50,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.5),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
                onPressed: () => Navigator.pop(context),
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
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(weather.locationName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(widget.imagePath), fit: BoxFit.cover),
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
                      boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(0.8), blurRadius: 10, spreadRadius: 2)],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrosshairs() {
    return Stack(
      children: [
        Center(child: Container(width: 40, height: 40, decoration: BoxDecoration(border: Border.all(color: Colors.white.withOpacity(0.5), width: 1)))),
        Center(child: Container(width: 2, height: 60, color: Colors.white.withOpacity(0.3))),
        Center(child: Container(width: 60, height: 2, color: Colors.white.withOpacity(0.3))),
      ],
    );
  }

  Widget _buildIntelligenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Icon(Icons.psychology_outlined, color: Color(0xFF1B5E20)),
              SizedBox(width: 10),
              Text('Diagnosis Intelligence', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1B5E20))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildIntelCard('Scientific', _rule?.scientificName ?? 'N/A', Icons.biotech, const Color(0xFF2E7D32)),
              _buildIntelCard('Symptoms', _rule?.symptoms ?? 'N/A', Icons.visibility, Colors.brown),
              _buildIntelCard('Cause', _rule?.cause ?? 'N/A', Icons.info, Colors.blueGrey),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntelCard(String title, String val, IconData icon, Color color) {
    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 16, bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.6)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 8),
                  Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  val,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnvironmentalSection(WeatherData weather) {
    final alert = RiceHealthLogic.getEnvironmentalAlert(weather.humidity, weather.temp);
    final isCritical = weather.humidity > 85;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cloud_outlined, color: Colors.blueGrey),
                SizedBox(width: 10),
                Text('Environmental Context', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.blueGrey)),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(weather.locationName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${weather.temp.toStringAsFixed(1)}°C  |  ${weather.humidity}% Humid', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  ],
                ),
                Icon(isCritical ? Icons.warning_amber_rounded : Icons.check_circle_outline, color: alert['color'], size: 30),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (alert['color'] as Color).withOpacity(0.15),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: alert['color']),
              ),
              child: Row(
                children: [
                  Icon(alert['icon'], color: alert['color'], size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      alert['message'],
                      style: TextStyle(color: alert['color'], fontWeight: FontWeight.bold, fontSize: 13),
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recommended Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1B5E20))),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildActionTile('Fungicide Application', 'Apply Tricyclazole', Icons.colorize_outlined, Colors.teal),
              const SizedBox(width: 12),
              _buildActionTile('Nitrogen Control', r'Adjust $N_2$ Levels', Icons.science_outlined, Colors.indigo),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Share Diagnostic Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontSize: 10, color: color.withOpacity(0.7), fontWeight: FontWeight.bold)),
            Text(action, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
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
        border: Border.all(color: color.withOpacity(0.2)),
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
                style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            en,
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 14, height: 1.5),
          ),
          const Divider(height: 24),
          Text(
            ur,
            style: const TextStyle(color: Color(0xFF2ECC71), fontSize: 15, height: 1.5, fontFamily: 'Jameel Noori'),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleInfoBox(String title, String en, {String? urduText, required IconData icon, Color color = Colors.grey}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Text(en, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.8), fontSize: 13, height: 1.4)),
          if (urduText != null && urduText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(urduText, style: const TextStyle(color: Color(0xFF2ECC71), fontSize: 12), textDirection: TextDirection.rtl),
          ],
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
              color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
