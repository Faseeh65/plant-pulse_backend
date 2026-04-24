import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_assets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  bool _isLogin = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  late AnimationController _buttonController;

  @override
  void initState() {
    super.initState();
    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.05,
    );
  }

  @override
  void dispose() {
    _buttonController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('Please fill in all fields', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        if (_passwordController.text != _confirmPasswordController.text) {
          throw 'Passwords do not match';
        }
        await Supabase.instance.client.auth.signUp(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      _showSnackBar(e.toString(), Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Background Layer (Full Screen Image) ───────────────────────────────
          Positioned.fill(
            child: Image.asset(
              AppAssets.farmBg,
              fit: BoxFit.cover,
            ),
          ),
          // Dark Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.7),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),

          // ── Content Layer ──────────────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 50),
                    // Heading
                    Text(
                      _isLogin ? 'Welcome Back' : 'Join Plant Pulse',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.playfairDisplay(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isLogin ? 'Sign in to continue monitoring' : 'Start your agricultural intelligence journey',
                      style: GoogleFonts.montserrat(color: Colors.white60, fontSize: 13),
                    ),
                    const SizedBox(height: 40),

                    // Glassmorphic Card
                    _buildGlassCard(),

                    const SizedBox(height: 10),
                    // Toggle Text
                    GestureDetector(
                      onTap: () => setState(() => _isLogin = !_isLogin),
                      child: RichText(
                        text: TextSpan(
                          text: _isLogin ? "Don't have an account? " : "Already have an account? ",
                          style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 14),
                          children: [
                            TextSpan(
                              text: _isLogin ? 'Sign up' : 'Sign in',
                              style: const TextStyle(
                                color: Color(0xFF6CFB7B),
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: -5),
        ],
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              _buildModernField(_emailController, 'Email Address', Icons.mail_outline),
              const SizedBox(height: 20),
              _buildModernField(_passwordController, 'Password', Icons.lock_outline, isPassword: true),
              if (!_isLogin) ...[
                const SizedBox(height: 20),
                _buildModernField(_confirmPasswordController, 'Confirm Password', Icons.lock_reset, isPassword: true),
              ],
              if (_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: Text('Forgot Password?', style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 12)),
                  ),
                ),
              const SizedBox(height: 24),
              _buildGradientButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernField(TextEditingController controller, String label, IconData icon, {bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.montserrat(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Focus(
          onFocusChange: (hasFocus) => setState(() {}),
          child: Builder(
            builder: (context) {
              final hasFocus = Focus.of(context).hasFocus;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: hasFocus ? const Color(0xFF6CFB7B) : Colors.white.withOpacity(0.1),
                    width: hasFocus ? 2 : 1,
                  ),
                  boxShadow: hasFocus 
                    ? [BoxShadow(color: const Color(0xFF6CFB7B).withOpacity(0.2), blurRadius: 10, spreadRadius: 1)]
                    : [],
                ),
                child: TextField(
                  controller: controller,
                  obscureText: isPassword,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    prefixIcon: Icon(icon, color: hasFocus ? const Color(0xFF6CFB7B) : Colors.white38, size: 20),
                    hintText: 'Enter your $label',
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGradientButton() {
    return GestureDetector(
      onTapDown: (_) => _buttonController.forward(),
      onTapUp: (_) => _buttonController.reverse(),
      onTapCancel: () => _buttonController.reverse(),
      onTap: _isLoading ? null : _handleAuth,
      child: AnimatedBuilder(
        animation: _buttonController,
        builder: (context, child) {
          return Transform.scale(
            scale: 1 - _buttonController.value,
            child: Container(
              height: 55,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00C853), Color(0xFF64DD17)],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C853).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : Text(
                        _isLogin ? 'Sign In' : 'Create Account',
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: Colors.black, fontSize: 16),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

