import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/causal_service.dart';
import '../services/database_service.dart';
import '../services/scan_guard.dart';
import '../models/causal_logic.dart';
import '../models/disease_result.dart';
import 'results_screen.dart';
import 'history_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/questionnaire_overlay.dart';
import '../utils/string_extensions.dart';
import 'profile_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with TickerProviderStateMixin {
  CameraController? _controller;
  bool _isProcessing = false;
  final CausalService _causalService = CausalService();
  final ApiService _apiService = ApiService();

  // Animations
  late AnimationController _scanLineController;
  late AnimationController _cornersController;
  late AnimationController _flashController;
  late AnimationController _leafRotationController;

  late Animation<double> _scanLineAnimation;
  late Animation<double> _cornersAnimation;
  late Animation<double> _flashAnimation;

  @override
  void initState() {
    super.initState();
    _initializeCamera();

    // 1. Scanning frame corners drawing
    _cornersController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _cornersAnimation = CurvedAnimation(parent: _cornersController, curve: Curves.easeOut);
    _cornersController.forward();

    // 2. Scanning line sweeping
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );
    _scanLineController.repeat();

    // 3. Flash effect
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _flashAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.3), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 0.3, end: 0.0), weight: 50),
    ]).animate(_flashController);

    // 4. Loading state rotating leaf
    _leafRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _leafRotationController.repeat();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _scanLineController.dispose();
    _cornersController.dispose();
    _flashController.dispose();
    _leafRotationController.dispose();
    super.dispose();
  }

  // Gallery → Auto-Predict Flow
  // Picks image, validates format, immediately triggers the entropy-fusion pipeline.
  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (picked == null) return; // User cancelled

      // ── Format & Quality Validation ──────────────────────────────────────
      final String ext = picked.path.split('.').last.toLowerCase();
      const Set<String> supportedFormats = {'jpg', 'jpeg', 'png', 'webp', 'bmp'};

      if (!supportedFormats.contains(ext)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Unsupported image format or quality.\nغیر معاون تصویر فارمیٹ۔',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
        return;
      }

      final File imageFile = File(picked.path);
      final int fileSize = await imageFile.length();

      // Reject tiny thumbnails (< 5KB) or corrupt files (0 bytes)
      if (fileSize < 5120) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Unsupported image format or quality. Image is too small.\nتصویر بہت چھوٹی ہے۔',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
        return;
      }

      // ── Immediately enter loading state & predict ──────────────────────
      setState(() => _isProcessing = true);

      final rawResult = await _predictViaApi(imageFile);
      final String label      = rawResult['label'] as String;
      final double confidence = rawResult['confidence'] as double;

      ScanGuard.instance.validate(label, confidence);

      if (!mounted) return;

      final bool isHealthy = label.toLowerCase().contains('healthy');
      final rule = _causalService.getRuleForLabel(label);

      if (isHealthy || rule == null || !rule.questionsNeeded) {
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
              questions: _causalService.staticQuestions,
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
    } on UnrecognizedScanException catch (e) {
      debugPrint('GALLERY SCAN REJECTED: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        _showRejectionSheet(e);
      }
    } catch (e) {
      debugPrint('GALLERY SCAN ERROR: $e');
      if (mounted) {
        setState(() => _isProcessing = false);

        // Detect image decode / format errors from the backend
        final String errStr = e.toString().toLowerCase();
        final bool isFormatError = errStr.contains('decode') ||
            errStr.contains('format') ||
            errStr.contains('400') ||
            errStr.contains('could not decode');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFormatError
                  ? 'Unsupported image format or quality.\nغیر معاون تصویر فارمیٹ یا کوالٹی۔'
                  : 'Scan Error: $e\nسکین میں خرابی آ گئی۔ دوبارہ کوشش کریں۔',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    
    // --- DIAGNOSTIC LOGGING ---
    debugPrint('--- API DIAGNOSTICS ---');
    debugPrint('Target URL: $uri');
    debugPrint('Image Info: ${imageFile.path} (Size: ${imageFile.lengthSync()} bytes)');
    debugPrint('Response Status: ${streamedResponse.statusCode}');
    debugPrint('Raw Body: $responseBody');
    debugPrint('-----------------------');

    if (streamedResponse.statusCode == 200) {
      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final label = decoded['class_name'] as String? ?? decoded['disease'] as String? ?? decoded['label'] as String? ?? 'Unknown';
      final confidence = (decoded['confidence'] as num?)?.toDouble() ?? 0.0;
      return {'label': label, 'confidence': confidence};
    } else {
      debugPrint('Predict API error ${streamedResponse.statusCode}: $responseBody');
      throw Exception('PREDICT_API_ERROR_${streamedResponse.statusCode}');
    }
  }

  void _captureAndAnalyze() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) return;

    // Trigger flash effect
    _flashController.forward(from: 0.0);

    setState(() => _isProcessing = true);

    try {
      final XFile photo = await _controller!.takePicture();
      final File imageFile = File(photo.path);

      final rawResult = await _predictViaApi(imageFile);
      final String label = rawResult['label'] as String;
      final double confidence = rawResult['confidence'] as double;

      ScanGuard.instance.validate(label, confidence);

      if (!mounted) return;

      final bool isHealthy = label.toLowerCase().contains('healthy');
      final rule = _causalService.getRuleForLabel(label);

      if (isHealthy || rule == null || !rule.questionsNeeded) {
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
        if (!mounted) return;
        showGeneralDialog(
          context: context,
          barrierDismissible: false,
          pageBuilder: (ctx, anim1, anim2) {
            return QuestionnaireOverlay(
              label: label,
              questions: _causalService.staticQuestions,
              onCompleted: (answers) {
                final refined = _causalService.refineResult(
                  label: label,
                  originalConfidence: confidence,
                  answers: answers,
                );
                Navigator.pop(ctx);
                _navigateToResults(photo.path, refined);
              },
              onSkip: () {
                Navigator.pop(ctx);
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
                style: const TextStyle(fontWeight: FontWeight.w900),
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

    try {
      final lang = Localizations.localeOf(context).languageCode;
      diseaseResult = await _apiService.fetchDiagnosisDetails(
        result.label,
        lang: lang,
      );
    } catch (e) {
      debugPrint('FastAPI fetch failed (using fallback): $e');
      diseaseResult = DiseaseResult(
        disease: result.label,
        language: 'en',
        instruction: 'Treatment data is currently unavailable. Please consult a local agricultural expert.\nعلاج کی معلومات دستیاب نہیں۔ مقامی زرعی ماہر سے مشورہ کریں۔',
        dosagePerAcre: 'N/A',
        recommendations: [],
      );
    }

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      if (userId.isNotEmpty) {
        await _apiService.saveScanResult(
          userId: userId,
          plantName: result.label.toDisplayCrop(),
          diseaseResult: result.label,
          confidenceScore: result.refinedConfidence,
        );
      }
    } catch (e) {
      debugPrint('History save error (non-fatal): $e');
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultsScreen(
          imagePath: imagePath,
          diseaseNameEnglish: result.label,
          diseaseNameUrdu: '',
          confidence: result.refinedConfidence,
          isRefined: result.answers.isNotEmpty,
          secondaryInspectionRequired: result.secondaryInspectionRequired,
          diagnosisData: diseaseResult!,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() => _isProcessing = false);
    });
  }

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
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: Theme.of(context).cardTheme.elevation != 0 
            ? [BoxShadow(color: Theme.of(context).cardTheme.shadowColor ?? Colors.black12, blurRadius: 12, offset: const Offset(0, 4))] 
            : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            const Text(
              'Unable to Analyze Image',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
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
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
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
            Text('Please verify your network status to sync crop data.'),
            SizedBox(height: 15),
            Text(
              'سرور سے رابطہ نہیں ہو سکا۔ براہ کرم یقینی بنائیں کہ آپ کا نیٹ ورک آن ہے۔',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK / ٹھیک ہے', style: TextStyle(color: Color(0xFF2ECC71), fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — Feature Coming Soon\n$feature — جلد آ رہا ہے',
          style: const TextStyle(fontWeight: FontWeight.w900)),
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

    final disableAnimations = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),

          // Animated Scanning Frame and Sweeping Line
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
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: frameW,
                        height: frameH,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_scanLineController, _cornersController]),
                          builder: (context, child) {
                            return CustomPaint(
                              painter: _ScannerFramePainter(
                                scanLineProgress: disableAnimations ? 0.5 : _scanLineAnimation.value,
                                cornersProgress: disableAnimations ? 1.0 : _cornersAnimation.value,
                                color: const Color(0xFF6CFB7B),
                              ),
                            );
                          },
                        ),
                      ),
                      const Spacer(flex: 2),
                    ],
                  ),
                );
              },
            ),
          ),

          // 3. Flash Effect Overlay
          AnimatedBuilder(
            animation: _flashAnimation,
            builder: (context, child) {
              return Container(
                color: Colors.white.withOpacity(disableAnimations ? 0.0 : _flashAnimation.value),
              );
            },
          ),

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
                    // 4. Loading state: rotating leaf icon
                    AnimatedBuilder(
                      animation: _leafRotationController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: disableAnimations ? 0.0 : _leafRotationController.value * 2 * 3.14159,
                          child: child,
                        );
                      },
                      child: const Icon(Icons.eco, color: Color(0xFF6CFB7B), size: 48),
                    ),
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
    final disableAnimations = MediaQuery.of(context).disableAnimations;

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
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.home_outlined, color: Colors.white60, size: 28),
              ),
            ),

            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _pickFromGallery,
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.grid_view_outlined, color: Colors.white60, size: 28),
              ),
            ),

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
                    ? AnimatedBuilder(
                        animation: _leafRotationController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: disableAnimations ? 0.0 : _leafRotationController.value * 2 * 3.14159,
                            child: child,
                          );
                        },
                        child: const Icon(Icons.eco, color: Colors.black, size: 30),
                      )
                    : const Icon(Icons.add_a_photo, color: Colors.black, size: 30),
              ),
            ),

            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.history, color: Colors.white60, size: 28),
              ),
            ),

            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen())),
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

class _ScannerFramePainter extends CustomPainter {
  final double scanLineProgress;
  final double cornersProgress;
  final Color color;

  _ScannerFramePainter({
    required this.scanLineProgress,
    required this.cornersProgress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final double cornerLen = 30 * cornersProgress;
    final double pathGap = 0; // Padding from edge

    // Top Left
    canvas.drawLine(Offset(pathGap, pathGap), Offset(pathGap + cornerLen, pathGap), paint);
    canvas.drawLine(Offset(pathGap, pathGap), Offset(pathGap, pathGap + cornerLen), paint);

    // Top Right
    canvas.drawLine(Offset(size.width - pathGap, pathGap), Offset(size.width - pathGap - cornerLen, pathGap), paint);
    canvas.drawLine(Offset(size.width - pathGap, pathGap), Offset(size.width - pathGap, pathGap + cornerLen), paint);

    // Bottom Left
    canvas.drawLine(Offset(pathGap, size.height - pathGap), Offset(pathGap + cornerLen, size.height - pathGap), paint);
    canvas.drawLine(Offset(pathGap, size.height - pathGap), Offset(pathGap, size.height - pathGap - cornerLen), paint);

    // Bottom Right
    canvas.drawLine(Offset(size.width - pathGap, size.height - pathGap), Offset(size.width - pathGap - cornerLen, size.height - pathGap), paint);
    canvas.drawLine(Offset(size.width - pathGap, size.height - pathGap), Offset(size.width - pathGap, size.height - pathGap - cornerLen), paint);

    // Horizontal Scanning Line
    final linePaint = Paint()
      ..color = color.withOpacity(0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.fill;
    
    final double y = size.height * scanLineProgress;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);

    // Sweep Glow Effect
    final glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.0), color.withOpacity(0.3), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, y - 20, size.width, 40));
    
    canvas.drawRect(Rect.fromLTWH(0, y - 20, size.width, 40), glowPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerFramePainter oldDelegate) {
    return oldDelegate.scanLineProgress != scanLineProgress || oldDelegate.cornersProgress != cornersProgress;
  }
}

