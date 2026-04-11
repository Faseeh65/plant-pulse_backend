import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'results_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _isProcessing = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
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
    _pulseController.dispose();
    super.dispose();
  }

  void _captureAndAnalyze() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // For now, simulate capture and processing
      await Future.delayed(const Duration(seconds: 2));
      
      if (!mounted) return;
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const ResultsScreen(
            diseaseNameEnglish: 'Apple Scab',
            diseaseNameUrdu: 'سیب کی کھجلی',
            confidence: 0.95,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Capture error: $e');
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          CameraPreview(_controller!),
          
          // Shaded Overlay with Clear Center
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return CustomPaint(
                painter: ScannerFramePainter(
                  glowOpacity: _pulseAnimation.value,
                ),
              );
            },
          ),
          
          // Processing Indicator
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Analyzing Plant...',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    )
                  ],
                ),
              ),
            ),
            
          // Capture Button
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 48.0),
              child: GestureDetector(
                onTap: _captureAndAnalyze,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF1B5E20), // Forest Green
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class ScannerFramePainter extends CustomPainter {
  final double glowOpacity;

  ScannerFramePainter({required this.glowOpacity});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final frameSize = size.width * 0.75;
    final half = frameSize / 2;

    final rect = Rect.fromLTRB(cx - half, cy - half, cx + half, cy + half);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(20));

    // Dark Background outside the frame
    final scrimPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    
    canvas.drawPath(
      scrimPath,
      Paint()..color = Colors.black.withOpacity(0.6),
    );

    // Glowing border
    final glowPaint = Paint()
      ..color = const Color(0xFF1B5E20).withOpacity(glowOpacity) // Shimmering green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    
    canvas.drawRRect(rrect, glowPaint);

    // Solid border
    final solidPaint = Paint()
      ..color = const Color(0xFF1B5E20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
      
    canvas.drawRRect(rrect, solidPaint);
    
    // Draw Corner Accents
    final cornerLength = frameSize * 0.15;
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Top-Left
    canvas.drawPath(
      Path()
        ..moveTo(rect.left, rect.top + cornerLength)
        ..lineTo(rect.left, rect.top + 20)
        ..arcToPoint(Offset(rect.left + 20, rect.top), radius: const Radius.circular(20))
        ..lineTo(rect.left + cornerLength, rect.top),
      cornerPaint,
    );
    
    // Top-Right
    canvas.drawPath(
      Path()
        ..moveTo(rect.right - cornerLength, rect.top)
        ..lineTo(rect.right - 20, rect.top)
        ..arcToPoint(Offset(rect.right, rect.top + 20), radius: const Radius.circular(20))
        ..lineTo(rect.right, rect.top + cornerLength),
      cornerPaint,
    );
    
    // Bottom-Left
    canvas.drawPath(
      Path()
        ..moveTo(rect.left, rect.bottom - cornerLength)
        ..lineTo(rect.left, rect.bottom - 20)
        ..arcToPoint(Offset(rect.left + 20, rect.bottom), radius: const Radius.circular(20), clockwise: false)
        ..lineTo(rect.left + cornerLength, rect.bottom),
      cornerPaint,
    );
    
    // Bottom-Right
    canvas.drawPath(
      Path()
        ..moveTo(rect.right - cornerLength, rect.bottom)
        ..lineTo(rect.right - 20, rect.bottom)
        ..arcToPoint(Offset(rect.right, rect.bottom - 20), radius: const Radius.circular(20), clockwise: false)
        ..lineTo(rect.right, rect.bottom - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ScannerFramePainter oldDelegate) {
    return oldDelegate.glowOpacity != glowOpacity;
  }
}
