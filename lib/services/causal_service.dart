import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/causal_logic.dart';

class CausalService {
  static final CausalService _instance = CausalService._internal();
  factory CausalService() => _instance;
  CausalService._internal();

  Map<String, CausalRule>? _rules;

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
    return _rules![label] ?? _rules!['fallback'];
  }

  RefinedResult refineResult({
    required String label,
    required double originalConfidence,
    required List<bool> answers,
  }) {
    final rule = getRuleForLabel(label);
    if (rule == null || answers.length != rule.questions.length) {
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
        bonus += rule.questions[i].weight;
      } else {
        // If user answers 'No' to a critical symptom or environmental trigger, flag it
        flagged = true;
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
