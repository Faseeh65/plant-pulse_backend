import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';
import 'package:provider/provider.dart';

class PlantIdentifyScreen extends StatefulWidget {
  const PlantIdentifyScreen({super.key});

  @override
  State<PlantIdentifyScreen> createState() => _PlantIdentifyScreenState();
}

class _PlantIdentifyScreenState extends State<PlantIdentifyScreen>
    with TickerProviderStateMixin {
  CameraController? _controller;
  bool _isProcessing = false;
  Map<String, dynamic>? _result;
  String? _capturedImagePath;
  String? _errorMessage;

  late AnimationController _scanLineController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _initializeCamera();

    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _scanLineController.dispose();
    _pulseController.dispose();
    super.dispose();
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

  Future<Map<String, dynamic>> _identifyViaApi(File imageFile) async {
    final uri = Uri.parse('${ApiService.baseUrl}/identify');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: MediaType('image', 'jpeg'),
      ),
    );
    request.headers['Accept'] = 'application/json';

    final streamedResponse =
        await request.send().timeout(const Duration(seconds: 30));
    final responseBody = await streamedResponse.stream.bytesToString();

    debugPrint('--- IDENTIFY API DIAGNOSTICS ---');
    debugPrint('Target URL: $uri');
    debugPrint('Response Status: ${streamedResponse.statusCode}');
    debugPrint('Raw Body: $responseBody');
    debugPrint('--------------------------------');

    if (streamedResponse.statusCode == 200) {
      return jsonDecode(responseBody) as Map<String, dynamic>;
    } else {
      throw Exception(
          'IDENTIFY_API_ERROR_${streamedResponse.statusCode}: $responseBody');
    }
  }

  void _captureAndIdentify() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _result = null;
      _errorMessage = null;
    });

    try {
      final XFile photo = await _controller!.takePicture();
      final File imageFile = File(photo.path);

      setState(() => _capturedImagePath = photo.path);

      final apiResult = await _identifyViaApi(imageFile);

      if (!mounted) return;
      setState(() {
        _result = apiResult;
        _isProcessing = false;
      });
    } catch (e) {
      debugPrint('IDENTIFY ERROR: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e.toString().contains('CONNECT') ||
                  e.toString().contains('SocketException') ||
                  e.toString().contains('TimeoutException')
              ? 'Unable to reach server. Please check your connection.'
              : 'Identification failed. Please try again.';
        });
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null) return;

      setState(() {
        _isProcessing = true;
        _result = null;
        _errorMessage = null;
        _capturedImagePath = picked.path;
      });

      final File imageFile = File(picked.path);
      final apiResult = await _identifyViaApi(imageFile);

      if (!mounted) return;
      setState(() {
        _result = apiResult;
        _isProcessing = false;
      });
    } catch (e) {
      debugPrint('GALLERY IDENTIFY ERROR: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Identification failed. Please try again.';
        });
      }
    }
  }

  void _resetToCamera() {
    setState(() {
      _result = null;
      _capturedImagePath = null;
      _errorMessage = null;
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        context.watch<ThemeProvider>().isDarkMode;

    // Show result screen if we have results
    if (_result != null && _capturedImagePath != null) {
      return _buildResultView(isDark);
    }

    // Show error screen
    if (_errorMessage != null && _capturedImagePath != null) {
      return _buildErrorView(isDark);
    }

    // Camera not ready
    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF81C784)),
              const SizedBox(height: 16),
              Text(
                'Initializing Camera...',
                style: GoogleFonts.inter(color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }

    return _buildCameraView(isDark);
  }

  // ── CAMERA VIEW ─────────────────────────────────────────────────────────────
  Widget _buildCameraView(bool isDark) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),

          // Top gradient + header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _buildBackButton(),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Plant Identify',
                              style: GoogleFonts.playfairDisplay(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    return Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF81C784)
                                            .withOpacity(0.4 +
                                                (0.6 *
                                                    _pulseController.value)),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF81C784)
                                                .withOpacity(0.5 *
                                                    _pulseController.value),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          )
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'AI-Powered Recognition',
                                  style: GoogleFonts.inter(
                                    color: Colors.white54,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Scan frame overlay
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: const Color(0xFF81C784).withValues(alpha: 0.5), width: 2),
              ),
              child: Stack(
                children: [
                  // Scanning line
                  AnimatedBuilder(
                    animation: _scanLineController,
                    builder: (context, child) {
                      return Positioned(
                        top: 10 + (260 * _scanLineController.value),
                        left: 10,
                        right: 10,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            color: const Color(0xFF81C784),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFF81C784).withValues(alpha: 0.8),
                                blurRadius: 10,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Loading overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 60,
                      height: 60,
                      child:
                          CircularProgressIndicator(color: Color(0xFF81C784), strokeWidth: 3),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Identifying Plant...',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Analyzing leaf structure & patterns',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom controls (Premium Glassmorphism Dock)
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
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
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(45),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Gallery Button
                          GestureDetector(
                            onTap: _pickFromGallery,
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.collections_rounded,
                                  color: Colors.white, size: 24),
                            ),
                          ),

                          // Shutter Button (Premium Design)
                          GestureDetector(
                            onTap: _isProcessing ? null : _captureAndIdentify,
                            child: AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Container(
                                  width: 74,
                                  height: 74,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF81C784).withOpacity(
                                          0.3 * (1 - _pulseController.value)),
                                      width: 3 * _pulseController.value,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Container(
                                    width: 62,
                                    height: 62,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF2E7D32),
                                          Color(0xFF81C784)
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF81C784)
                                              .withValues(alpha: 0.3),
                                          blurRadius: 15,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.local_florist,
                                        color: Colors.white, size: 28),
                                  ),
                                );
                              },
                            ),
                          ),

                          // Placeholder for symmetry
                          const SizedBox(width: 50),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── RESULT VIEW ─────────────────────────────────────────────────────────────
  Widget _buildResultView(bool isDark) {
    final result = _result!;
    final plantName = result['plant_name'] ?? 'Unknown';
    final scientificName = result['scientific_name'] ?? 'N/A';
    final category = result['category'] ?? 'N/A';
    final description = result['description'] ?? 'No description available.';
    final growingTips = result['growing_tips'] ?? 'No tips available.';
    final confidence = (result['confidence'] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E0A) : const Color(0xFFF5F5F5),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Image header
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            leading: _buildBackButtonResult(isDark),
            backgroundColor:
                isDark ? const Color(0xFF0A0E0A) : const Color(0xFFF5F5F5),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(_capturedImagePath!),
                    fit: BoxFit.cover,
                  ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          (isDark
                                  ? const Color(0xFF0A0E0A)
                                  : const Color(0xFFF5F5F5))
                              .withValues(alpha: 0.9),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Confidence badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF81C784).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF81C784).withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '${(confidence * 100).toStringAsFixed(1)}% Confidence',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF81C784),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Plant name
                  Text(
                    plantName,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF1B2E1B),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Scientific name
                  Text(
                    scientificName,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Category chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      category.toString().replaceAll('_', ' ').toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: isDark ? Colors.white38 : Colors.black45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Description card
                  _buildInfoCard(
                    isDark: isDark,
                    icon: Icons.info_outline_rounded,
                    title: 'Description',
                    content: description,
                    accentColor: const Color(0xFF64B5F6),
                  ),
                  const SizedBox(height: 16),

                  // Growing tips card
                  _buildInfoCard(
                    isDark: isDark,
                    icon: Icons.tips_and_updates_outlined,
                    title: 'Growing Tips',
                    content: growingTips,
                    accentColor: const Color(0xFFFFB74D),
                  ),
                  const SizedBox(height: 32),

                  // Scan again button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _resetToCamera,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF81C784),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 4,
                        shadowColor: const Color(0xFF81C784).withValues(alpha: 0.4),
                      ),
                      icon: const Icon(Icons.camera_alt_rounded, size: 22),
                      label: Text(
                        'SCAN ANOTHER PLANT',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required bool isDark,
    required IconData icon,
    required String title,
    required String content,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1B2E1B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            content,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ── ERROR VIEW ──────────────────────────────────────────────────────────────
  Widget _buildErrorView(bool isDark) {
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0E0A) : const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Top bar
              Row(
                children: [
                  _buildBackButton(),
                  const SizedBox(width: 16),
                  Text(
                    'Identification Failed',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF1B2E1B),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Error icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.search_off_rounded,
                    color: Colors.redAccent, size: 56),
              ),
              const SizedBox(height: 24),
              Text(
                'Unable to Identify Plant',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'An error occurred.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              // Tips
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF152213)
                      : const Color(0xFFF1F8E9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _tipRow(Icons.wb_sunny_outlined,
                        'Ensure good natural lighting.'),
                    const SizedBox(height: 10),
                    _tipRow(Icons.center_focus_strong_outlined,
                        'Point camera at a single leaf.'),
                    const SizedBox(height: 10),
                    _tipRow(Icons.do_not_disturb_alt_outlined,
                        'Avoid backgrounds & mixed objects.'),
                  ],
                ),
              ),
              const Spacer(),
              // Try again
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _resetToCamera,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF81C784),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.camera_alt_outlined, size: 20),
                  label: Text(
                    'Try Again',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tipRow(IconData icon, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF81C784), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(alpha: 0.8),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      );

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: const Icon(Icons.arrow_back_rounded,
            color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildBackButtonResult(bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.black.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.8),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.arrow_back_rounded,
          color: isDark ? Colors.white : Colors.black87,
          size: 22,
        ),
      ),
    );
  }
}
