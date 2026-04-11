import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

/// Phase 2B – Scan Screen
/// Live camera feed with an animated scanning frame and a shutter button.
/// Tapping the shutter captures the image and calls [_uploadImage], which
/// will eventually POST the photo to the FastAPI /predict endpoint.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with TickerProviderStateMixin {
  // ── Camera ──────────────────────────────────────────────────────────────
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  bool _cameraReady = false;
  bool _isCapturing = false;

  // ── Pulse animation ──────────────────────────────────────────────────────
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  // ── Shutter flash animation ──────────────────────────────────────────────
  late final AnimationController _flashController;
  late final Animation<double> _flashAnim;

  @override
  void initState() {
    super.initState();

    // Pulsing glow on the scanning frame — 1.8 s loop
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Quick white flash when shutter fires
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _flashAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeOut),
    );

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      _controller = CameraController(
        _cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() => _cameraReady = true);
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _flashController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  // ── Shutter ──────────────────────────────────────────────────────────────
  Future<void> _onShutter() async {
    if (!_cameraReady || _isCapturing) return;
    setState(() => _isCapturing = true);

    // Flash feedback
    await _flashController.forward();
    _flashController.reverse();

    try {
      final XFile image = await _controller!.takePicture();
      await _uploadImage(image);
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  // ── FastAPI placeholder ──────────────────────────────────────────────────
  /// Placeholder: will POST [image] to the FastAPI /predict endpoint.
  /// Replace the body of this function in Phase 3 when the backend is ready.
  Future<void> _uploadImage(XFile image) async {
    // TODO(Phase 3): Send image to FastAPI /predict
    // Example:
    //   final uri = Uri.parse('http://<host>:8000/predict');
    //   final request = http.MultipartRequest('POST', uri)
    //     ..files.add(await http.MultipartFile.fromPath('file', image.path));
    //   final response = await request.send();
    //   …handle response…
    debugPrint('[_uploadImage] Captured: ${image.path}');
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _buildTransparentAppBar(),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera preview (or loading state)
          _cameraReady
              ? _buildCameraPreview()
              : const _CameraLoadingView(),

          // 2. Scanning frame overlay
          _buildScanOverlay(),

          // 3. Shutter flash
          AnimatedBuilder(
            animation: _flashAnim,
            builder: (context, _) => Opacity(
              opacity: _flashAnim.value * 0.6,
              child: const ColoredBox(color: Colors.white),
            ),
          ),

          // 4. Shutter button pinned to bottom
          _buildShutterButton(),
        ],
      ),
    );
  }

  AppBar _buildTransparentAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  Widget _buildCameraPreview() {
    return OverflowBox(
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.previewSize!.height,
          height: _controller!.value.previewSize!.width,
          child: CameraPreview(_controller!),
        ),
      ),
    );
  }

  Widget _buildScanOverlay() {
    const frameSize = 260.0;
    const cornerSize = 36.0;
    const cornerThickness = 3.5;
    const cornerRadius = 12.0;

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        return CustomPaint(
          painter: _ScanFramePainter(
            frameSize: frameSize,
            cornerSize: cornerSize,
            cornerThickness: cornerThickness,
            cornerRadius: cornerRadius,
            glowOpacity: _pulseAnim.value,
            glowColor: AppColors.accentGreen,
          ),
        );
      },
    );
  }

  Widget _buildShutterButton() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 52),
        child: GestureDetector(
          onTap: _onShutter,
          child: AnimatedScale(
            scale: _isCapturing ? 0.88 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: _ShutterButton(isCapturing: _isCapturing),
          ),
        ),
      ),
    );
  }
}

// ── Scanning frame CustomPainter ─────────────────────────────────────────────
class _ScanFramePainter extends CustomPainter {
  final double frameSize;
  final double cornerSize;
  final double cornerThickness;
  final double cornerRadius;
  final double glowOpacity;
  final Color glowColor;

  const _ScanFramePainter({
    required this.frameSize,
    required this.cornerSize,
    required this.cornerThickness,
    required this.cornerRadius,
    required this.glowOpacity,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final half = frameSize / 2;

    final left = cx - half;
    final top = cy - half;
    final right = cx + half;
    final bottom = cy + half;

    // Dark vignette outside the frame
    final scrimPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final frameRRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(left, top, right, bottom),
      const Radius.circular(20),
    );
    final scrimPath = Path()
      ..addRect(fullRect)
      ..addRRect(frameRRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(scrimPath, scrimPaint);

    // Glow paint
    final glowPaint = Paint()
      ..color = glowColor.withValues(alpha: glowOpacity * 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawRRect(frameRRect, glowPaint);

    // Corner brackets
    final cornerPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.85 + glowOpacity * 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cornerThickness
      ..strokeCap = StrokeCap.round;

    _drawCorners(canvas, left, top, right, bottom, cornerPaint);
  }

  void _drawCorners(Canvas canvas, double l, double t, double r, double b,
      Paint paint) {
    final s = cornerSize;
    final cr = cornerRadius;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(l, t + s)
        ..lineTo(l, t + cr)
        ..arcToPoint(Offset(l + cr, t),
            radius: Radius.circular(cr), clockwise: true)
        ..lineTo(l + s, t),
      paint,
    );

    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(r - s, t)
        ..lineTo(r - cr, t)
        ..arcToPoint(Offset(r, t + cr),
            radius: Radius.circular(cr), clockwise: false)
        ..lineTo(r, t + s),
      paint,
    );

    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(r, b - s)
        ..lineTo(r, b - cr)
        ..arcToPoint(Offset(r - cr, b),
            radius: Radius.circular(cr), clockwise: false)
        ..lineTo(r - s, b),
      paint,
    );

    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(l + s, b)
        ..lineTo(l + cr, b)
        ..arcToPoint(Offset(l, b - cr),
            radius: Radius.circular(cr), clockwise: false)
        ..lineTo(l, b - s),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ScanFramePainter old) =>
      old.glowOpacity != glowOpacity;
}

// ── Shutter button widget ─────────────────────────────────────────────────────
class _ShutterButton extends StatelessWidget {
  final bool isCapturing;
  const _ShutterButton({required this.isCapturing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCapturing
                ? AppColors.accentGreen.withValues(alpha: 0.7)
                : Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── Camera loading state ──────────────────────────────────────────────────────
class _CameraLoadingView extends StatelessWidget {
  const _CameraLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.accentGreen,
        strokeWidth: 2,
      ),
    );
  }
}
