import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/causal_logic.dart';

class CausalService {
  static final CausalService _instance = CausalService._internal();
  factory CausalService() => _instance;
  CausalService._internal();

  Map<String, CausalRule>? _rules;

  // Static shared questions as requested
  final List<DiagnosticQuestion> staticQuestions = [
    DiagnosticQuestion(
      englishText: "Has there been high humidity or rain recently?",
      urduText: "کیا حال ہی میں زیادہ نمی یا بارش ہوئی ہے؟",
      weight: 0.05,
    ),
    DiagnosticQuestion(
      englishText: "Are you watering directly on the leaves?",
      urduText: "کیا آپ براہ راست پتوں پر پانی دے رہے ہیں؟",
      weight: 0.03,
    ),
    DiagnosticQuestion(
      englishText: "Is your plant getting enough sunlight?",
      urduText: "کیا آپ کے پودے کو کافی دھوپ مل رہی ہے؟",
      weight: 0.02,
    ),
  ];

  Future<void> init() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/models/causal_rules.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      
      _rules = jsonData.map((key, value) => MapEntry(key, CausalRule.fromJson(value)));
    } catch (e) {
      print('Error loading causal rules: $e');
    }
  }

  CausalRule? getRuleForLabel(String label) {
    if (_rules == null) return null;
    return _rules![label]; // Exact match as requested
  }

  RefinedResult refineResult({
    required String label,
    required double originalConfidence,
    required List<bool> answers,
  }) {
    final rule = getRuleForLabel(label);
    if (rule == null || answers.length != staticQuestions.length) {
      return RefinedResult(
        label: label,
        originalConfidence: originalConfidence,
        refinedConfidence: originalConfidence,
        secondaryInspectionRequired: false,
        answers: answers,
      );
    }

    double bonus = 0.0;
    bool flagged = false;

    for (int i = 0; i < answers.length; i++) {
      if (answers[i]) {
        bonus += staticQuestions[i].weight;
      } else {
        // If user answers 'No' to environmental triggers, it might flag secondary inspection
        // For these questions, 'Yes' to 1 and 2 is bad, 'No' to 3 is bad.
        // But the previous implementation just added weight.
        // Let's keep it simple: if answers indicate poor environment, flag it.
        if (i == 0 || i == 1) flagged = true; // High rain/Humidity or wrong watering
      }
    }

    double refinedConfidence = originalConfidence + bonus;
    if (refinedConfidence > 0.999) refinedConfidence = 0.999;

    return RefinedResult(
      label: label,
      originalConfidence: originalConfidence,
      refinedConfidence: refinedConfidence,
      secondaryInspectionRequired: flagged,
      answers: answers,
    );
  }
}
