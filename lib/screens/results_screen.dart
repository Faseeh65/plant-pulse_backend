import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/causal_logic.dart';
import '../models/disease_result.dart';
import '../services/api_service.dart';
import '../services/causal_service.dart';
import '../utils/string_extensions.dart';
import 'treatment_detail_screen.dart';

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
  late final CausalRule? _rule;

  // Animations
  late AnimationController _typewriterController;
  late AnimationController _countUpController;
  late AnimationController _badgeController;
  late AnimationController _sectionsController;

  late Animation<int> _typewriterAnimation;
  late Animation<double> _countUpAnimation;
  late Animation<double> _badgeScaleAnimation;

  @override
  void initState() {
    super.initState();
    _rule = CausalService().getRuleForLabel(widget.diseaseNameEnglish);
    _saveToCloudSilently();

    final String cleanName = widget.diseaseNameEnglish.toDiseaseOnly();
    
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

  Animation<Offset> _getSectionSlide(int index) {
    double start = index * 0.15;
    double end = (start + 0.4).clamp(0.0, 1.0);
    return Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _sectionsController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ),
    );
  }

  Animation<double> _getSectionFade(int index) {
    double start = index * 0.15;
    double end = (start + 0.4).clamp(0.0, 1.0);
    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sectionsController,
        curve: Interval(start, end, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void dispose() {
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
    final bool isHealthy = widget.diseaseNameEnglish.toLowerCase().contains('healthy') || (_rule?.severity == 'none');
    final String cleanName = widget.diseaseNameEnglish.toDiseaseOnly();
    final String plantType = widget.diseaseNameEnglish.toDisplayCrop();
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              child: Stack(
                children: [
                  Image.file(
                    File(widget.imagePath),
                    height: 350,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 50,
                    left: 20,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  if (_rule != null)
                    Positioned(
                      top: 60,
                      right: 20,
                      child: ScaleTransition(
                        scale: disableAnimations ? const AlwaysStoppedAnimation(1.0) : _badgeScaleAnimation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getSeverityColor(_rule!.severity),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getSeverityLabel(_rule!.severity),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          plantType,
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (_rule != null)
                        Text(
                          _rule!.urduName,
                          style: const TextStyle(
                            color: Color(0xFF2ECC71),
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  AnimatedBuilder(
                    animation: _typewriterAnimation,
                    builder: (context, child) {
                      String sub = cleanName.substring(0, disableAnimations ? cleanName.length : _typewriterAnimation.value);
                      return Text(
                        sub,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.6),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.verified_outlined, size: 16, color: const Color(0xFF2ECC71).withOpacity(0.8)),
                      const SizedBox(width: 6),
                      AnimatedBuilder(
                        animation: _countUpAnimation,
                        builder: (context, child) {
                          double val = disableAnimations ? widget.confidence : _countUpAnimation.value;
                          return Text(
                            'Confidence: ${(val * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: const Color(0xFF2ECC71).withOpacity(0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            if (widget.secondaryInspectionRequired)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Secondary Inspection Required',
                              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 14),
                            ),
                            Text(
                              'تفصیلی معائنے کی ضرورت ہے',
                              style: TextStyle(color: Colors.redAccent, fontSize: 12, fontFamily: 'Jameel Noori'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (widget.secondaryInspectionRequired) const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  if (_rule != null) ...[
                    // Scientific Name
                    if (_rule!.scientificName.isNotEmpty && _rule!.scientificName != 'N/A')
                      _buildAnimatedSection(0, _buildSimpleInfoBox(
                        'Scientific Name',
                        _rule!.scientificName,
                        icon: Icons.biotech_outlined,
                        color: Colors.tealAccent,
                      )),
                    // Symptoms
                    if (_rule!.symptoms.isNotEmpty)
                      _buildAnimatedSection(1, _buildSimpleInfoBox(
                        'Symptoms / علامات',
                        _rule!.symptoms,
                        icon: Icons.visibility_outlined,
                        color: Colors.amberAccent,
                      )),
                    // Cause
                    _buildAnimatedSection(2, _buildSimpleInfoBox(
                      'Cause / وجہ',
                      _rule!.cause,
                      icon: Icons.info_outline,
                      color: Colors.blueAccent,
                    )),
                    // Favorable Conditions
                    if (_rule!.favorableConditions.isNotEmpty)
                      _buildAnimatedSection(3, _buildSimpleInfoBox(
                        'Favorable Conditions',
                        _rule!.favorableConditions,
                        icon: Icons.thermostat_outlined,
                        color: Colors.deepOrangeAccent,
                      )),
                    // Treatment (Bilingual)
                    _buildAnimatedSection(4, _buildDualReportBox(
                      'Treatment / علاج',
                      _rule!.treatmentEn,
                      _rule!.treatmentUr,
                      Icons.medical_services_outlined,
                      const Color(0xFF2ECC71),
                    )),
                    // Prevention
                    if (_rule!.prevention.isNotEmpty)
                      _buildAnimatedSection(5, _buildSimpleInfoBox(
                        'Prevention / احتیاط',
                        _rule!.prevention,
                        icon: Icons.shield_outlined,
                        color: const Color(0xFF2ECC71),
                      )),
                  ] else ...[
                    _buildReportRow('Status', 'Analysis Complete'),
                    _buildReportRow('Details', 'Exact treatment data for this label is pending updates.'),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 40),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TreatmentDetailScreen(
                        diseaseLabel: widget.diseaseNameEnglish,
                        plantName: widget.diseaseNameEnglish.toDisplayCrop(),
                        preFetchedData: widget.diagnosisData,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 5,
                ),
                child: Text(
                  isHealthy ? 'Maintenance Care' : 'View Full Treatment Plan',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
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
