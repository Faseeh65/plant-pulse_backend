import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../services/causal_service.dart';
import '../services/database_service.dart';
import '../models/causal_logic.dart';
import '../models/disease_result.dart';
import 'results_screen.dart';
import '../widgets/questionnaire_overlay.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _isProcessing = false;
  final CausalService _causalService = CausalService();
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _controller = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Sends the captured image to FastAPI /predict endpoint via HTTP POST multipart.
  /// Returns {'label': String, 'confidence': double} or throws on failure.
  Future<Map<String, dynamic>> _predictViaApi(File imageFile) async {
    final uri = Uri.parse('${ApiService.baseUrl}/predict');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );
    request.headers['Accept'] = 'application/json';

    final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode == 200) {
      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      // Expected response: {"label": "...", "confidence": 0.87}
      final label = decoded['label'] as String? ?? 'Unknown';
      final confidence = (decoded['confidence'] as num?)?.toDouble() ?? 0.0;
      return {'label': label, 'confidence': confidence};
    } else {
      debugPrint('Predict API error ${streamedResponse.statusCode}: $responseBody');
      throw Exception('PREDICT_API_ERROR_${streamedResponse.statusCode}');
    }
  }

  void _captureAndAnalyze() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final XFile photo = await _controller!.takePicture();
      final File imageFile = File(photo.path);

      // Send image to FastAPI backend
      final rawResult = await _predictViaApi(imageFile);
      final String label = rawResult['label'] as String;
      final double confidence = rawResult['confidence'] as double;

      if (!mounted) return;

      // --- Confidence Gate (Anti-Garbage Logic) ---
      // If confidence < 45%, DO NOT proceed to results
      if (confidence < 0.45 || label == 'Unknown') {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'براہ کرم پودے کے پتے پر فوکس کریں۔',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              textDirection: TextDirection.rtl,
            ),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        return;
      }

      // Check if we should show the questionnaire
      final bool isHealthy = label.toLowerCase().contains('healthy');
      final rule = _causalService.getRuleForLabel(label);

      if (isHealthy || rule == null) {
        _navigateToResults(
          photo.path,
          RefinedResult(
            label: label,
            originalConfidence: confidence,
            refinedConfidence: confidence,
            secondaryInspectionRequired: false,
            answers: [],
          ),
        );
      } else {
        // Show Questionnaire overlay
        if (!mounted) return;
        showGeneralDialog(
          context: context,
          barrierDismissible: false,
          pageBuilder: (ctx, anim1, anim2) {
            return QuestionnaireOverlay(
              label: label,
              questions: rule.questions,
              onCompleted: (answers) {
                final refined = _causalService.refineResult(
                  label: label,
                  originalConfidence: confidence,
                  answers: answers,
                );
                Navigator.pop(ctx); // Close Overlay
                _navigateToResults(photo.path, refined);
              },
              onSkip: () {
                Navigator.pop(ctx); // Close Overlay
                _navigateToResults(
                  photo.path,
                  RefinedResult(
                    label: label,
                    originalConfidence: confidence,
                    refinedConfidence: confidence,
                    secondaryInspectionRequired: false,
                    answers: [],
                  ),
                );
              },
            );
          },
        );
      }
    } catch (e) {
      debugPrint('SCAN ERROR: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        final isConnError = e.toString().contains('CONNECT') ||
            e.toString().contains('SocketException') ||
            e.toString().contains('TimeoutException') ||
            e.toString().contains('CONNECTION_FAILED');

        if (isConnError) {
          _showConnectionErrorDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Scan Error: $e\nسکین میں خرابی آ گئی۔ دوبارہ کوشش کریں۔',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  void _navigateToResults(String imagePath, RefinedResult result) async {
    if (!mounted) return;

    setState(() => _isProcessing = true);

    DiseaseResult? diseaseResult;
    Map<String, dynamic>? diseaseDetails;

    try {
      final lang = Localizations.localeOf(context).languageCode;

      // Fetch data from FastAPI
      diseaseResult = await _apiService.fetchDiagnosisDetails(
        result.label,
        lang: lang,
      );
    } catch (e) {
      debugPrint('FastAPI fetch failed (using fallback): $e');
      // Create a fallback DiseaseResult so the user can still see results
      diseaseResult = DiseaseResult(
        disease: result.label,
        language: 'en',
        instruction: 'Treatment data is currently unavailable. Please consult a local agricultural expert.\nعلاج کی معلومات دستیاب نہیں۔ مقامی زرعی ماہر سے مشورہ کریں۔',
        dosagePerAcre: 'N/A',
        recommendations: [],
      );
    }

    try {
      final dbService = DatabaseService();
      diseaseDetails = await dbService.getDiseaseWithCausalChain(result.label);

      // Save to local history
      await dbService.saveScan(
        diseaseName: result.label,
        confidence: result.refinedConfidence,
        causalFactor: diseaseDetails != null ? 'Knowledge Base Sync' : 'Direct AI',
        imagePath: imagePath,
      );
    } catch (e) {
      debugPrint('DB save error (non-fatal): $e');
    }

    // --- Critical: Guard against widget being unmounted during async gap ---
    if (!mounted) {
      return; // Cannot setState or navigate; widget is gone
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultsScreen(
          imagePath: imagePath,
          diseaseNameEnglish: result.label,
          diseaseNameUrdu: diseaseDetails?['name_ur'] ?? 'تشخیص شدہ بیماری',
          confidence: result.refinedConfidence,
          isRefined: result.answers.isNotEmpty,
          secondaryInspectionRequired: result.secondaryInspectionRequired,
          diagnosisData: diseaseResult!,
        ),
      ),
    ).then((_) {
      // Always reset processing state when user returns from ResultsScreen
      if (mounted) setState(() => _isProcessing = false);
    });
  }

  void _showConnectionErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.wifi_off_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Connection Error'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Cannot reach the PlantPulse server. Please ensure your laptop is running and connected to the same network.'),
            SizedBox(height: 15),
            Text(
              'سرور سے رابطہ نہیں ہو سکا۔ براہ کرم یقینی بنائیں کہ آپ کا لیپ ٹاپ آن ہے اور اسی نیٹ ورک سے منسلک ہے۔',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK / ٹھیک ہے', style: TextStyle(color: Color(0xFF2ECC71), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — Feature Coming Soon\n$feature — جلد آ رہا ہے',
          style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2ECC71),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Color(0xFF6CFB7B))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          CameraPreview(_controller!),

          // Glassmorphism Overlay (Clear & Interactive-Safe)
          IgnorePointer(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final frameW = constraints.maxWidth * 0.7;
                final frameH = frameW * 1.2;
                return Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 60),
                      const Text(
                        'Scanner',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          width: frameW,
                          height: frameH,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                          ),
                        ),
                      ),
                      const Spacer(flex: 2),
                    ],
                  ),
                );
              },
            ),
          ),

          // Bottom Navigation Style Bar
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomBar(),
          ),

          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF6CFB7B)),
                    const SizedBox(height: 16),
                    Text(
                      'Analyzing leaf...\nپتے کا تجزیہ ہو رہا ہے...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        height: 100,
        margin: const EdgeInsets.only(bottom: 12, left: 20, right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A).withOpacity(0.9),
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Home Button
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.home_outlined, color: Colors.white60, size: 28),
              ),
            ),

            // Gallery — wired with SnackBar
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showComingSoon('Gallery Upload'),
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.grid_view_outlined, color: Colors.white60, size: 28),
              ),
            ),

            // Main Scan Button — always ready (no model init required)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _isProcessing ? null : _captureAndAnalyze,
              child: Container(
                height: 70,
                width: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6CFB7B), Color(0xFF2ECC71)],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x442ECC71),
                      blurRadius: 12,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.add_a_photo, color: Colors.black, size: 30),
              ),
            ),

            // History — wired with SnackBar
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showComingSoon('Scan History'),
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.history, color: Colors.white60, size: 28),
              ),
            ),

            // Profile — wired with SnackBar
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showComingSoon('Profile'),
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.person_outline, color: Colors.white60, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
