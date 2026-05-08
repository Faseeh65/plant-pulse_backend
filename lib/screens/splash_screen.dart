import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_assets.dart';
import '../services/api_service.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _breathingController;
  late AnimationController _floatingController;

  late Animation<double> _logoScaleAnimation;
  late Animation<double> _breathingAnimation;
  late Animation<double> _appNameFadeAnimation;
  late Animation<Offset> _appNameSlideAnimation;

  String _status = 'Initializing...';
  bool _isError = false;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // 1. Logo entrance: scale from 0.0 to 1.0 with elastic curve
    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    // 2. App name fade-in slides up from bottom
    _appNameFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeInOut),
      ),
    );
    _appNameSlideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // 3. Subtle breathing animation
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _breathingAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOut,
      ),
    );

    _entranceController.forward().then((_) {
      if (mounted) _breathingController.repeat(reverse: true);
    });

    // 4. Background floating particles
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _performStartupChecks();
  }

  Future<void> _performStartupChecks() async {
    setState(() => _status = 'Checking Server Connectivity...');
    
    // Minimum wait for animation/branding
    await Future.delayed(const Duration(seconds: 3));

    final isHealthy = await ApiService().checkHealth();

    if (!isHealthy) {
      if (mounted) {
        setState(() {
          _status = 'Backend Offline — Running in Demo Mode';
          _isError = true;
        });
        // Give user 2 seconds to see warning, then continue anyway
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        setState(() => _isError = false);
      }
    }

    if (mounted) {
      try {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          Navigator.pushReplacementNamed(context, '/auth');
        }
      } catch (e) {
        debugPrint('⚠️ Supabase not initialized, redirecting to auth: $e');
        Navigator.pushReplacementNamed(context, '/auth');
      }
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _breathingController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background floating particles
          if (!disableAnimations)
            AnimatedBuilder(
              animation: _floatingController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _ParticlesPainter(
                    progress: _floatingController.value,
                    color: isDark ? const Color(0xFF6CFB7B).withValues(alpha: 0.05) : const Color(0xFF245C34).withValues(alpha: 0.05),
                  ),
                );
              },
            ),

          // Main Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with entrance and breathing
                AnimatedBuilder(
                  animation: Listenable.merge([_entranceController, _breathingController]),
                  builder: (context, child) {
                    double scale = disableAnimations ? 1.0 : _logoScaleAnimation.value;
                    if (_entranceController.isCompleted && !disableAnimations) {
                      scale = _breathingAnimation.value;
                    }
                    return Transform.scale(
                      scale: scale,
                      child: child,
                    );
                  },
                  child: Image.asset(
                    AppAssets.appIcon,
                    width: 230,
                    height: 230,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),

                // App Name with slide-up fade
                AnimatedBuilder(
                  animation: _entranceController,
                  builder: (context, child) {
                    return SlideTransition(
                      position: disableAnimations ? const AlwaysStoppedAnimation(Offset.zero) : _appNameSlideAnimation,
                      child: FadeTransition(
                        opacity: disableAnimations ? const AlwaysStoppedAnimation(1.0) : _appNameFadeAnimation,
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    'Plant Pulse',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: isDark ? const Color(0xFF6CFB7B) : const Color(0xFF245C34),
                      letterSpacing: -0.5,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                // Status Text
                AnimatedBuilder(
                  animation: _entranceController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: disableAnimations ? const AlwaysStoppedAnimation(1.0) : _appNameFadeAnimation,
                      child: child,
                    );
                  },
                  child: Text(
                    _status.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.orbitron(
                      color: _isError ? Colors.redAccent : (isDark ? Colors.white70 : Colors.black54),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),

                if (_isError) ...[
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.black,
                    ),
                    onPressed: _performStartupChecks,
                    child: const Text('Retry Connection'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticlesPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ParticlesPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final particles = [
      _Particle(0.2, 0.8, 15, 1.2),
      _Particle(0.7, 0.6, 20, 0.8),
      _Particle(0.4, 0.3, 10, 1.5),
      _Particle(0.8, 0.1, 25, 0.9),
      _Particle(0.3, 0.9, 12, 1.1),
      _Particle(0.6, 0.4, 18, 1.3),
    ];

    for (var p in particles) {
      double yOffset = (progress * p.speed) % 1.0;
      double currentY = (p.startY - yOffset);
      if (currentY < 0) currentY += 1.0;

      canvas.drawCircle(
        Offset(size.width * p.startX, size.height * currentY),
        p.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _Particle {
  final double startX;
  final double startY;
  final double radius;
  final double speed;

  _Particle(this.startX, this.startY, this.radius, this.speed);
}
