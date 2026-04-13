import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../services/causal_service.dart';
import '../services/database_service.dart';
import '../services/scan_guard.dart';
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

  // ── Gallery picker ──────────────────────────────────────────────────────
  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;

    // On Android 13+ (API 33+) we need READ_MEDIA_IMAGES.
    // On older Android we need READ_EXTERNAL_STORAGE.
    final Permission storagePermission =
        (await Permission.photos.status).isGranted ||
                (await Permission.photos.request()).isGranted
            ? Permission.photos
            : Permission.storage;

    final PermissionStatus status = await storagePermission.status;

    if (status.isGranted) {
      // ── Permission granted — open native gallery ──
      final ImagePicker picker = ImagePicker();
      final XFile? picked =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);

      if (picked == null) return; // user cancelled

      final File imageFile = File(picked.path);
      setState(() => _isProcessing = true);

      try {
        final rawResult = await _predictViaApi(imageFile);
        final String label      = rawResult['label'] as String;
        final double confidence = rawResult['confidence'] as double;

        // ── Two-layer defence: background class + 85% confidence gate ──
        ScanGuard.instance.validate(label, confidence);

        if (!mounted) return;

        final bool isHealthy = label.toLowerCase().contains('healthy');
        final rule = _causalService.getRuleForLabel(label);

        if (isHealthy || rule == null) {
          _navigateToResults(
            picked.path,
            RefinedResult(
              label: label,
              originalConfidence: confidence,
              refinedConfidence: confidence,
              secondaryInspectionRequired: false,
              answers: [],
            ),
          );
        } else {
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
                  Navigator.pop(ctx);
                  _navigateToResults(picked.path, refined);
                },
                onSkip: () {
                  Navigator.pop(ctx);
                  _navigateToResults(
                    picked.path,
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
        debugPrint('GALLERY SCAN ERROR: $e');
        if (mounted) {
          setState(() => _isProcessing = false);
          if (e is UnrecognizedScanException) {
            _showRejectionSheet(e);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Scan Error: $e'),
                backgroundColor: Colors.redAccent,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } else if (status.isPermanentlyDenied) {
      // ── Permanently denied — guide user to Settings ──
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Gallery permission denied. Enable it in Settings.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    } else {
      // ── Denied (first time or temporary) — request permission ──
      final PermissionStatus newStatus = await storagePermission.request();
      if (newStatus.isGranted) {
        _pickFromGallery(); // retry after grant
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'گیلری تک رسائی کی اجازت درکار ہے۔',
              style: TextStyle(fontWeight: FontWeight.bold),
              textDirection: TextDirection.rtl,
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
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
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: MediaType('image', 'jpeg'),
      ),
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

      // ── Two-layer defence: background class + 85% confidence gate ──
      ScanGuard.instance.validate(label, confidence);

      if (!mounted) return;

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

        if (e is UnrecognizedScanException) {
          // Professional rejection sheet — never a raw SnackBar
          _showRejectionSheet(e);
          return;
        }

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

  // ── Professional Rejection Sheet ────────────────────────────────────────
  /// Shown whenever [ScanGuard] throws [UnrecognizedScanException].
  /// Displays a clear, bilingual, actionable error so the user knows
  /// exactly what went wrong and what to do next.
  void _showRejectionSheet(UnrecognizedScanException e) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        decoration: BoxDecoration(
          color: const Color(0xFF111F0F),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.redAccent.withOpacity(0.35), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Icon ──
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: Colors.redAccent,
                size: 46,
              ),
            ),
            const SizedBox(height: 18),

            // ── Title ──
            const Text(
              'Unrecognized Scan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'ناقابلِ شناخت اسکین',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),

            // ── Confidence badge (only if below threshold) ──
            if (e.confidence > 0 && e.confidence < ScanGuard.kConfidenceThreshold)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
                ),
                child: Text(
                  'Confidence: ${(e.confidence * 100).toStringAsFixed(1)}%  '  
                  '(min ${(ScanGuard.kConfidenceThreshold * 100).toStringAsFixed(0)}% required)',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),

            const SizedBox(height: 20),

            // ── Instructions ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF152213),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _tipRow(Icons.wb_sunny_outlined,
                      'Ensure good natural lighting on the leaf.'),
                  const SizedBox(height: 10),
                  _tipRow(Icons.center_focus_strong_outlined,
                      'Point camera at a single leaf, filling the frame.'),
                  const SizedBox(height: 10),
                  _tipRow(Icons.do_not_disturb_alt_outlined,
                      'Avoid backgrounds, hands, or mixed objects.'),
                  const SizedBox(height: 14),
                  const Divider(color: Color(0xFF1E3A1A)),
                  const SizedBox(height: 10),
                  const Text(
                    'براہ کرم یقینی بنائیں کہ ایک حقیقی، واضح اور روشن پتہ فریم میں ہو۔',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Retry button ──
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6CFB7B),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.camera_alt_outlined, size: 20),
                label: const Text(
                  'Try Again  •  دوبارہ کوشش کریں',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tipRow(IconData icon, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF6CFB7B), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
          ),
        ],
      );

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

            // Gallery — opens native image picker with permission handling
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _pickFromGallery,
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
