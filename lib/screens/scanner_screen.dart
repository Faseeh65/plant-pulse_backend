import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/causal_service.dart';
import '../services/database_service.dart';
import '../services/scan_guard.dart';
import 'package:geolocator/geolocator.dart';
import '../models/causal_logic.dart';
import '../models/disease_result.dart';
import 'results_screen.dart';
import 'history_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import '../widgets/questionnaire_overlay.dart';
import '../utils/string_extensions.dart';
import 'profile_screen.dart';
import 'package:google_fonts/google_fonts.dart';

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
  final DatabaseService _dbService = DatabaseService();

  // Animations
  late AnimationController _scanLineController;
  late AnimationController _cornersController;
  late AnimationController _flashController;
  late AnimationController _leafRotationController;

  late Animation<double> _scanLineAnimation;
  late Animation<double> _cornersAnimation;
  late Animation<double> _flashAnimation;
  late AnimationController _shutterPulseController;
  bool _isNavigationInProgress = false;

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

    // 4. Shutter pulse
    _shutterPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    
    // 5. Loading state rotating leaf
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
    _shutterPulseController.dispose();
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
                'Unsupported image format or quality.',
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
                'Unsupported image format or quality. Image is too small.',
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
                  ? 'Unsupported image format or quality.'
                  : 'Scan Error: Unable to reach server. Please check your connection.',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
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

  Future<Uint8List> compressImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;
    final resized = img.copyResize(image, width: 800);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
  }

  Future<Map<String, dynamic>> _predictViaApi(File imageFile) async {
    final uri = Uri.parse('${ApiService.baseUrl}/predict');
    final request = http.MultipartRequest('POST', uri);
    final compressedBytes = await compressImage(imageFile);
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        compressedBytes,
        filename: 'scan.jpg',
        contentType: MediaType('image', 'jpeg'),
      ),
    );
    request.headers['Accept'] = 'application/json';

    http.StreamedResponse? streamedResponse;
    for (int i = 0; i < 2; i++) {
      try {
        final newRequest = http.MultipartRequest('POST', uri);
        newRequest.files.add(
          http.MultipartFile.fromBytes(
            'file',
            compressedBytes,
            filename: 'scan.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        );
        newRequest.headers['Accept'] = 'application/json';
        streamedResponse = await newRequest.send().timeout(const Duration(seconds: 30));
        break;
      } catch (e) {
        if (i == 1) rethrow;
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    
    if (streamedResponse == null) throw Exception('API_TIMEOUT');

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

      // New: Capture GPS for Historical Mapping
      double? lat, lng;
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (e) {
        debugPrint('GPS capture skipped: $e');
      }

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
          lat: lat,
          lng: lng,
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
                if (_isNavigationInProgress) return;
                _isNavigationInProgress = true;
                
                final refined = _causalService.refineResult(
                  label: label,
                  originalConfidence: confidence,
                  answers: answers,
                );
                Navigator.pop(ctx);
                _navigateToResults(photo.path, refined, lat: lat, lng: lng);
              },
              onSkip: () {
                if (_isNavigationInProgress) return;
                _isNavigationInProgress = true;

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
                  lat: lat,
                  lng: lng,
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

        final String errStr = e.toString().toUpperCase();
        final isConnError = errStr.contains('CONNECT') ||
            errStr.contains('SOCKETEXCEPTION') ||
            errStr.contains('TIMEOUTEXCEPTION') ||
            errStr.contains('CONNECTION_FAILED') ||
            errStr.contains('REFUSED');

        if (isConnError) {
          _showConnectionErrorDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Scan Error: $e',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  void _navigateToResults(String imagePath, RefinedResult result, {double? lat, double? lng}) async {
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
        instruction: 'Treatment data is currently unavailable. Please consult a local agricultural expert.',
        dosagePerAcre: 'N/A',
        recommendations: [],
      );
    }

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      
      // 1. Save to Local DB (Priority - for Stats & Offline View)
      try {
        await _dbService.saveScan(
          diseaseName: result.label,
          confidence: result.refinedConfidence,
          causalFactor: result.answers.isNotEmpty 
              ? "Refined via ${result.answers.where((a)=>a).length} positive symptoms" 
              : "Direct Image Analysis",
          imagePath: imagePath,
          lat: lat,
          lng: lng,
        );
      } catch (e) {
        debugPrint('Local history save error: $e');
      }

      // 2. Save to Remote Backend (Optional Background Sync)
      if (userId.isNotEmpty) {
        try {
          await _apiService.saveScanResult(
            userId: userId,
            plantName: result.label.toDisplayCrop(),
            diseaseResult: result.label,
            confidenceScore: result.refinedConfidence,
          );
        } catch (e) {
          debugPrint('Remote history save error (non-fatal): $e');
        }
      }
    } catch (e) {
      debugPrint('Persistence failure: $e');
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
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isNavigationInProgress = false;
        });
      }
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
            Text(
              'Unable to Analyze Image',
              style: TextStyle(
                color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),
            const SizedBox(height: 1),
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
                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF152213) : const Color(0xFFF1F8E9),
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
                  const SizedBox(height: 1),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.camera_alt_outlined, size: 20),
                label: const Text(
                  'Try Again',
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
          Icon(icon, color: Theme.of(context).primaryColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8), 
                  fontSize: 13, 
                  height: 1.4
                )),
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
            SizedBox(width: 12),
            Flexible(
              child: Text(
                'Connection Error',
                style: TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              Text(
                'Please verify your network status to sync crop data.',
                style: TextStyle(fontSize: 15),
              ),
              Text(
                'The server could not be reached. Please check your internet connection.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFF2ECC71), fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — Feature Coming Soon',
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
          RepaintBoundary(
            child: CameraPreview(_controller!),
          ),

          // Premium HUD Overlay (Top & Corners)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.0),
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Field Scanner',
                                  style: GoogleFonts.playfairDisplay(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedBuilder(
                                      animation: _shutterPulseController,
                                      builder: (context, child) {
                                        return Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF6CFB7B).withOpacity(0.4 + (0.6 * _shutterPulseController.value)),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF6CFB7B).withOpacity(0.5 * _shutterPulseController.value),
                                                blurRadius: 8,
                                                spreadRadius: 2,
                                              )
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'SYSTEM READY',
                                      style: GoogleFonts.rajdhani(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 2.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Central Scanning UI
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.75,
                  height: MediaQuery.of(context).size.width * 0.9,
                  child: Stack(
                    children: [
                      // HUD Status Labels at corners
                      Positioned(
                        top: -20,
                        left: 0,
                        child: Text('AF-C / LEAF', 
                          style: GoogleFonts.rajdhani(color: const Color(0xFF6CFB7B).withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      Positioned(
                        top: -20,
                        right: 0,
                        child: Text('ISO AUTO', 
                          style: GoogleFonts.rajdhani(color: const Color(0xFF6CFB7B).withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      Positioned(
                        bottom: -20,
                        left: 0,
                        child: Text('RICE_MODEL_V2.4', 
                          style: GoogleFonts.rajdhani(color: const Color(0xFF6CFB7B).withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      
                      AnimatedBuilder(
                        animation: Listenable.merge([_scanLineController, _cornersController]),
                        builder: (context, child) {
                          return CustomPaint(
                            painter: _ScannerFramePainter(
                              scanLineProgress: disableAnimations ? 0.5 : _scanLineAnimation.value,
                              cornersProgress: disableAnimations ? 1.0 : _cornersAnimation.value,
                              color: const Color(0xFF6CFB7B),
                            ),
                            size: Size.infinite,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
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
              color: Colors.black87,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                        'PRECISION ANALYSIS IN PROGRESS',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.rajdhani(
                          color: const Color(0xFF6CFB7B), 
                          fontSize: 12, 
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Decoding leaf pathology patterns...',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white70, 
                          fontSize: 10, 
                          fontWeight: FontWeight.w500
                        ),
                      ),
                    ],
                  ),
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
        height: 90,
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(45),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(45),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavIcon(Icons.home_filled, () => Navigator.pop(context)),
                  _buildNavIcon(Icons.collections_rounded, _pickFromGallery),
                  
                  // Capture Button
                  GestureDetector(
                    onTap: _isProcessing ? null : _captureAndAnalyze,
                    child: AnimatedBuilder(
                      animation: _shutterPulseController,
                      builder: (context, child) {
                        return Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF6CFB7B).withOpacity(0.3 * (1 - _shutterPulseController.value)),
                              width: 3 * _shutterPulseController.value,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2E7D32), Color(0xFF6CFB7B)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6CFB7B).withOpacity(0.4),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                            child: _isProcessing
                                ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                                : const Icon(Icons.camera_rounded, color: Colors.white, size: 32),
                          ),
                        );
                      },
                    ),
                  ),

                  _buildNavIcon(Icons.history_edu_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()))),
                  _buildNavIcon(Icons.account_circle_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen()))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: Colors.white.withOpacity(0.8), size: 28),
      onPressed: onTap,
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

    // Horizontal Scanning Beam
    final double y = size.height * scanLineProgress;
    
    final beamPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.0),
          color.withOpacity(0.4),
          color,
          color.withOpacity(0.4),
          color.withOpacity(0.0),
        ],
        stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(0, y - 25, size.width, 50));

    canvas.drawRect(Rect.fromLTWH(0, y - 25, size.width, 50), beamPaint);

    // Sharp center line
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);

    // Glowing Corners Effect
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    
    // (We reuse corner logic for glow)
    final double gLen = cornerLen + 4;
    canvas.drawLine(Offset(pathGap, pathGap), Offset(pathGap + gLen, pathGap), glowPaint);
    canvas.drawLine(Offset(pathGap, pathGap), Offset(pathGap, pathGap + gLen), glowPaint);
    canvas.drawLine(Offset(size.width - pathGap, pathGap), Offset(size.width - pathGap - gLen, pathGap), glowPaint);
    canvas.drawLine(Offset(size.width - pathGap, pathGap), Offset(size.width - pathGap, pathGap + gLen), glowPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerFramePainter oldDelegate) {
    return oldDelegate.scanLineProgress != scanLineProgress || oldDelegate.cornersProgress != cornersProgress;
  }
}

