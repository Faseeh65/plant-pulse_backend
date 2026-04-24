import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/causal_logic.dart';
import '../providers/locale_provider.dart';
import 'package:provider/provider.dart';

class QuestionnaireOverlay extends StatefulWidget {
  final String label;
  final List<DiagnosticQuestion> questions;
  final Function(List<bool>) onCompleted;
  final VoidCallback onSkip;

  const QuestionnaireOverlay({
    super.key,
    required this.label,
    required this.questions,
    required this.onCompleted,
    required this.onSkip,
  });

  @override
  State<QuestionnaireOverlay> createState() => _QuestionnaireOverlayState();
}

class _QuestionnaireOverlayState extends State<QuestionnaireOverlay> with TickerProviderStateMixin {
  int _currentIndex = 0;
  final List<bool> _answers = [];
  bool _isFinished = false;

  // Animations
  late AnimationController _cardController;
  late AnimationController _progressController;
  late AnimationController _buttonsController;

  late Animation<double> _cardSlideAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _noButtonScale;
  late Animation<double> _yesButtonScale;

  @override
  void initState() {
    super.initState();
    
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _cardSlideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOutBack),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0 / widget.questions.length).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _buttonsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _noButtonScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _buttonsController, curve: const Interval(0.0, 0.6, curve: Curves.elasticOut)),
    );
    _yesButtonScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _buttonsController, curve: const Interval(0.3, 0.9, curve: Curves.elasticOut)),
    );

    _cardController.forward();
    _progressController.forward();
    _buttonsController.forward();
  }

  @override
  void dispose() {
    _cardController.dispose();
    _progressController.dispose();
    _buttonsController.dispose();
    super.dispose();
  }

  void _submitAnswer(bool answer) {
    if (_isFinished) return;
    _answers.add(answer);
    if (_currentIndex < widget.questions.length - 1) {
      setState(() {
        _currentIndex++;
      });
      
      // Update Progress
      double nextProgress = (_currentIndex + 1) / widget.questions.length;
      _progressAnimation = Tween<double>(
        begin: _progressAnimation.value,
        end: nextProgress,
      ).animate(CurvedAnimation(parent: _progressController, curve: Curves.easeInOut));
      
      _cardController.forward(from: 0.0);
      _progressController.forward(from: 0.0);
      _buttonsController.forward(from: 0.0);
    } else {
      _isFinished = true;
      widget.onCompleted(_answers);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale.languageCode;
    final currentQuestion = widget.questions[_currentIndex];
    final questionText = locale == 'ur' ? currentQuestion.urduText : currentQuestion.englishText;
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background Blur
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withOpacity(0.7)),
          ),
          
          Center(
            child: AnimatedBuilder(
              animation: _cardController,
              builder: (context, child) {
                double slide = disableAnimations ? 0.0 : (1 - _cardSlideAnimation.value) * 100;
                return Transform.translate(
                  offset: Offset(0, slide),
                  child: Opacity(
                    opacity: disableAnimations ? 1.0 : _cardSlideAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 3. Animated Progress Bar
                    AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, child) {
                        return LinearProgressIndicator(
                          value: disableAnimations ? (_currentIndex + 1) / widget.questions.length : _progressAnimation.value,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          color: const Color(0xFF6CFB7B),
                          borderRadius: BorderRadius.circular(10),
                        );
                      },
                    ),
                    const SizedBox(height: 30),
                    
                    // Question Icon
                    const Icon(Icons.help_outline, color: Color(0xFF6CFB7B), size: 48),
                    const SizedBox(height: 20),
                    
                    // Question Text
                    Text(
                      locale == 'ur' ? 'تشخیصی سوالات' : 'Diagnostic Questions',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      questionText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    // 2. & 4. Staggered reveal and Bounce buttons
                    Row(
                      children: [
                        Expanded(
                          child: ScaleTransition(
                            scale: disableAnimations ? const AlwaysStoppedAnimation(1.0) : _noButtonScale,
                            child: _buildActionButton(
                              text: locale == 'ur' ? 'نہیں' : 'No',
                              isPrimary: false,
                              onTap: () => _submitAnswer(false),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: ScaleTransition(
                            scale: disableAnimations ? const AlwaysStoppedAnimation(1.0) : _yesButtonScale,
                            child: _buildActionButton(
                              text: locale == 'ur' ? 'جی ہاں' : 'Yes',
                              isPrimary: true,
                              onTap: () => _submitAnswer(true),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Skip Button
                    TextButton(
                      onPressed: widget.onSkip,
                      child: Text(
                        locale == 'ur' ? 'چھوڑیں (ماہرین کے لیے)' : 'Skip (for experts)',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 14,
                        ),
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

  Widget _buildActionButton({required String text, required bool isPrimary, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFF6CFB7B) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: isPrimary ? null : Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isPrimary ? Colors.black : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
