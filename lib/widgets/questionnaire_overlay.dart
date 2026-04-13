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

class _QuestionnaireOverlayState extends State<QuestionnaireOverlay> {
  int _currentIndex = 0;
  final List<bool> _answers = [];

  void _submitAnswer(bool answer) {
    setState(() {
      _answers.add(answer);
      if (_currentIndex < widget.questions.length - 1) {
        _currentIndex++;
      } else {
        widget.onCompleted(_answers);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale.languageCode;
    final currentQuestion = widget.questions[_currentIndex];
    final questionText = locale == 'ur' ? currentQuestion.urduText : currentQuestion.englishText;
    final progress = (_currentIndex + 1) / widget.questions.length;

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
                  // Progress Indicator
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    color: const Color(0xFF6CFB7B),
                    borderRadius: BorderRadius.circular(10),
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
                      fontWeight: FontWeight.bold,
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
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          text: locale == 'ur' ? 'نہیں' : 'No',
                          isPrimary: false,
                          onTap: () => _submitAnswer(false),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildActionButton(
                          text: locale == 'ur' ? 'جی ہاں' : 'Yes',
                          isPrimary: true,
                          onTap: () => _submitAnswer(true),
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
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
