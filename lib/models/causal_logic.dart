class DiagnosticQuestion {
  final String englishText;
  final String urduText;
  final String type;
  final double weight;

  DiagnosticQuestion({
    required this.englishText,
    required this.urduText,
    required this.type,
    required this.weight,
  });

  factory DiagnosticQuestion.fromJson(Map<String, dynamic> json) {
    return DiagnosticQuestion(
      englishText: json['en'] as String,
      urduText: json['ur'] as String,
      type: json['type'] as String,
      weight: (json['weight'] as num).toDouble(),
    );
  }
}

class CausalRule {
  final List<DiagnosticQuestion> questions;

  CausalRule({required this.questions});

  factory CausalRule.fromJson(Map<String, dynamic> json) {
    var questionList = json['questions'] as List;
    return CausalRule(
      questions: questionList
          .map((q) => DiagnosticQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RefinedResult {
  final String label;
  final double originalConfidence;
  final double refinedConfidence;
  final bool secondaryInspectionRequired;
  final List<bool> answers;

  RefinedResult({
    required this.label,
    required this.originalConfidence,
    required this.refinedConfidence,
    required this.secondaryInspectionRequired,
    required this.answers,
  });
}
