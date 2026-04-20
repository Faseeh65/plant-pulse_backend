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

class CausalRule {
  final String urduName;
  final String cause;
  final String urduCause;
  final String organicTreatment;
  final String urduOrganic;
  final String chemicalTreatment;
  final String urduChemical;
  final String pesticideBrand;
  final String pricePkr;
  final String availability;
  final String urduAvailability;
  final String prevention;
  final String urduPrevention;
  final String severity;
  final bool questionsNeeded;
  final String harvestWarning;
  final String urduWarning;

  CausalRule({
    required this.urduName,
    required this.cause,
    required this.urduCause,
    required this.organicTreatment,
    required this.urduOrganic,
    required this.chemicalTreatment,
    required this.urduChemical,
    required this.pesticideBrand,
    required this.pricePkr,
    required this.availability,
    required this.urduAvailability,
    required this.prevention,
    required this.urduPrevention,
    required this.severity,
    required this.questionsNeeded,
    required this.harvestWarning,
    required this.urduWarning,
  });

  factory CausalRule.fromJson(Map<String, dynamic> json) {
    return CausalRule(
      urduName: json['urdu_name'] ?? '',
      cause: json['cause'] ?? '',
      urduCause: json['urdu_cause'] ?? '',
      organicTreatment: json['organic_treatment'] ?? '',
      urduOrganic: json['urdu_organic'] ?? '',
      chemicalTreatment: json['chemical_treatment'] ?? '',
      urduChemical: json['urdu_chemical'] ?? '',
      pesticideBrand: json['pesticide_brand'] ?? '',
      pricePkr: json['price_pkr'] ?? '',
      availability: json['availability'] ?? '',
      urduAvailability: json['urdu_availability'] ?? '',
      prevention: json['prevention'] ?? '',
      urduPrevention: json['urdu_prevention'] ?? '',
      severity: json['severity'] ?? 'moderate',
      questionsNeeded: json['questions_needed'] ?? false,
      harvestWarning: json['harvest_warning'] ?? '',
      urduWarning: json['urdu_warning'] ?? '',
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
