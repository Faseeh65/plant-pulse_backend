import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  String _status = 'Initializing...';
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.forward();

    _performStartupChecks();
  }

  Future<void> _performStartupChecks() async {
    setState(() => _status = 'Checking Server Connectivity...');
    
    // Minimum wait for animation/branding
    await Future.delayed(const Duration(seconds: 2));

    final isHealthy = await ApiService().checkHealth();

    if (!isHealthy) {
      if (mounted) {
        setState(() {
          _status = 'FastAPI Server Offline\nPlease start your backend on 0.0.0.0';
          _isError = true;
        });
      }
      return; // Do not let the user enter if server is unreachable
    }

    if (mounted) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/auth');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1108), // Near black dark green
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Leaf Logo (Using High-Res Logo provided by User)
              Image.asset(
                'assets/images/Without Background Logo.png',
                height: 180,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              Text(
                'PlantPulse',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF6CFB7B),
                  letterSpacing: 2.0,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 48),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _isError ? Colors.redAccent : Colors.white70,
                  fontSize: 16,
                ),
              ),
              if (_isError) ...[
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6CFB7B),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _performStartupChecks,
                  child: const Text('Retry Connection'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
