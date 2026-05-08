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
  bool _isResettingPassword = false;

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
    _headingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Listen for Auth State changes to detect password recovery redirection
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        setState(() {
          _isResettingPassword = true;
          _isLogin = false; // Move to a form-like state
        });
      }
    });
  }

  late AnimationController _headingController;

  @override
  void dispose() {
    _buttonController.dispose();
    _headingController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    if (_isResettingPassword) {
      await _handleUpdatePassword();
      return;
    }

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
        _showSnackBar('Account created! Please check your email for verification.', Colors.green);
      }
      if (mounted && _isLogin) Navigator.pushReplacementNamed(context, '/home');
    } on AuthException catch (e) {
      _showSnackBar(e.message, Colors.red);
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    if (_emailController.text.isEmpty) {
      _showSnackBar('Please enter your email to reset password', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailController.text,
        redirectTo: 'com.plantpulse.plant_pulse://login-callback/',
      );
      _showSnackBar('Password reset link sent to your email!', Colors.green);
    } catch (e) {
      _showSnackBar(e.toString(), Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleUpdatePassword() async {
    if (_passwordController.text.isEmpty || _passwordController.text != _confirmPasswordController.text) {
      _showSnackBar('Passwords must match and cannot be empty', Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      _showSnackBar('Password updated successfully! You can now sign in.', Colors.green);
      setState(() {
        _isResettingPassword = false;
        _isLogin = true;
      });
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                  stops: const [0.0, 0.4, 0.8, 1.0],
                  colors: [
                    isDark ? Colors.black.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.3),
                    isDark ? Colors.black.withValues(alpha: 0.8) : const Color(0xFF2E5E32).withValues(alpha: 0.5),
                    isDark ? Colors.black.withValues(alpha: 0.95) : const Color(0xFF4A614A).withValues(alpha: 0.9),
                    isDark ? Colors.black : const Color(0xFF1B2E1B), // Deep forest green foundation
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
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 30 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          AnimatedBuilder(
                            animation: _headingController,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, 5 * _headingController.value),
                                child: child,
                              );
                            },
                            child: Stack(
                              children: [
                                // Text Shadow for Pop
                                Text(
                                  _isResettingPassword 
                                    ? 'Set New Password'
                                    : (_isLogin ? 'Welcome Back' : 'Join Plant Pulse'),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 44,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.5,
                                    height: 1.1,
                                    foreground: Paint()
                                      ..style = PaintingStyle.stroke
                                      ..strokeWidth = 2
                                      ..color = isDark ? Colors.black26 : Colors.black12,
                                  ),
                                ),
                                ShaderMask(
                                  shaderCallback: (bounds) => LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: isDark 
                                      ? [const Color(0xFF6CFB7B), Colors.white, const Color(0xFF6CFB7B)] 
                                      : [const Color(0xFFBEEBBE), const Color(0xFF6CFB7B), const Color(0xFF2E5E32)],
                                  ).createShader(bounds),
                                  child: Text(
                                    _isResettingPassword 
                                      ? 'Set New Password'
                                      : (_isLogin ? 'Welcome Back' : 'Join Plant Pulse'),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.playfairDisplay(
                                      color: Colors.white,
                                      fontSize: 44,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1.5,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            width: 60,
                            height: 4,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6CFB7B), Colors.transparent],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isResettingPassword
                        ? 'Choose a strong new password for your account'
                        : (_isLogin ? 'SIGN IN TO CONTINUE MONITORING' : 'START YOUR AGRICULTURAL JOURNEY'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.orbitron(
                        color: const Color(0xFF6CFB7B),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Glassmorphic Card
                    _buildGlassCard(),

                    const SizedBox(height: 10),
                    // Toggle Text
                    if (!_isResettingPassword)
                      GestureDetector(
                        onTap: () => setState(() => _isLogin = !_isLogin),
                      child: RichText(
                        text: TextSpan(
                          text: _isLogin ? "DON'T HAVE AN ACCOUNT? " : "ALREADY HAVE AN ACCOUNT? ",
                          style: GoogleFonts.orbitron(
                            color: Colors.white.withValues(alpha: 0.6), 
                            fontSize: 10,
                            letterSpacing: 1,
                          ),
                          children: [
                            TextSpan(
                              text: _isLogin ? "SIGN UP" : "LOG IN",
                              style: const TextStyle(
                                color: Color(0xFF6CFB7B),
                                fontWeight: FontWeight.w900,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFF2E5E32).withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(color: (isDark ? Colors.black : const Color(0xFF2E5E32)).withValues(alpha: 0.1), blurRadius: 30, spreadRadius: -5),
        ],
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              if (!_isResettingPassword)
                _buildModernField(_emailController, 'Email Address', Icons.mail_outline),
              if (!_isResettingPassword) const SizedBox(height: 20),
              _buildModernField(
                _passwordController, 
                _isResettingPassword ? 'New Password' : 'Password', 
                Icons.lock_outline, 
                isPassword: true
              ),
              if (!_isLogin || _isResettingPassword) ...[
                const SizedBox(height: 20),
                _buildModernField(
                  _confirmPasswordController, 
                  _isResettingPassword ? 'Confirm New Password' : 'Confirm Password', 
                  Icons.lock_reset, 
                  isPassword: true
                ),
              ],
              if (_isLogin && !_isResettingPassword)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _handleForgotPassword,
                    child: Text('Forgot Password?', style: GoogleFonts.inter(color: isDark ? Colors.white54 : const Color(0xFF2E5E32).withValues(alpha: 0.7), fontSize: 12)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.orbitron(
            color: isDark ? const Color(0xFF6CFB7B) : const Color(0xFF1B2E1B),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Focus(
          onFocusChange: (hasFocus) => setState(() {}),
          child: Builder(
            builder: (context) {
              final hasFocus = Focus.of(context).hasFocus;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: hasFocus ? const Color(0xFF6CFB7B) : Colors.white.withValues(alpha: 0.1),
                    width: hasFocus ? 2 : 1,
                  ),
                  boxShadow: hasFocus 
                    ? [BoxShadow(color: const Color(0xFF6CFB7B).withValues(alpha: 0.2), blurRadius: 10, spreadRadius: 1)]
                    : [],
                ),
                child: TextField(
                  controller: controller,
                  obscureText: isPassword,
                  style: GoogleFonts.rajdhani(
                    color: isDark ? Colors.white : Colors.black, 
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Icon(icon, color: hasFocus ? const Color(0xFF00C853) : (isDark ? Colors.white38 : Colors.black26), size: 20),
                    hintText: 'Enter your $label',
                    hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 13),
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
                    color: const Color(0xFF00C853).withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : Text(
                        _isResettingPassword 
                          ? 'Update Password' 
                          : (_isLogin ? 'Sign In' : 'Create Account'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: Colors.black, fontSize: 16),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

