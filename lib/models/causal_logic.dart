class DiagnosticQuestion {
  final String englishText;
  final String urduText;
  final double weight;

  DiagnosticQuestion({
    required this.englishText,
    required this.urduText,
    this.weight = 0.05,
  });
}

/// Represents a single rice disease rule from causal_rules.json.
/// Schema matches the bilingual 6-class Rice-Entropy-Fusion expert system.
class CausalRule {
  final String nameEn;
  final String nameUr;
  final String scientificName;
  final String symptoms;
  final String cause;
  final String favorableConditions;
  final String spread;
  final String severityLevel;
  final String affectedStage;
  final String treatmentEn;
  final String treatmentUr;
  final String prevention;
  final bool questionsNeeded;

  CausalRule({
    required this.nameEn,
    required this.nameUr,
    required this.scientificName,
    required this.symptoms,
    required this.cause,
    required this.favorableConditions,
    required this.spread,
    required this.severityLevel,
    required this.affectedStage,
    required this.treatmentEn,
    required this.treatmentUr,
    required this.prevention,
    required this.questionsNeeded,
  });

  factory CausalRule.fromJson(Map<String, dynamic> json) {
    return CausalRule(
      nameEn: json['name_en'] ?? '',
      nameUr: json['name_ur'] ?? '',
      scientificName: json['scientific_name'] ?? '',
      symptoms: json['symptoms'] ?? '',
      cause: json['cause'] ?? '',
      favorableConditions: json['favorable_conditions'] ?? '',
      spread: json['spread'] ?? '',
      severityLevel: json['severity_level'] ?? 'Unknown',
      affectedStage: json['affected_stage'] ?? '',
      treatmentEn: json['treatment_en'] ?? '',
      treatmentUr: json['treatment_ur'] ?? '',
      prevention: json['prevention'] ?? '',
      questionsNeeded: json['severity_level'] != null &&
          json['severity_level'] != 'None',
    );
  }

  /// Maps severity_level strings to the old severity format for UI compatibility.
  String get severity {
    switch (severityLevel.toLowerCase()) {
      case 'none':
        return 'none';
      case 'low':
      case 'low to medium':
        return 'moderate';
      case 'medium':
        return 'moderate';
      case 'high':
        return 'high';
      case 'very high':
        return 'very_high';
      default:
        return 'moderate';
    }
  }

  // Compatibility getters for results_screen.dart
  String get urduName => nameUr;
  String get organicTreatment => treatmentEn;
  String get urduOrganic => treatmentUr;
  String get chemicalTreatment => treatmentEn;
  String get urduChemical => treatmentUr;
  String get pesticideBrand => '';
  String get pricePkr => '';
  String get availability => '';
  String get urduAvailability => '';
  String get urduPrevention => treatmentUr;
  String get harvestWarning => '';
  String get urduWarning => '';
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
