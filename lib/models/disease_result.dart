class DiseaseResult {
  final String disease;
  final String language;
  final String instruction;
  final String dosagePerAcre;
  final List<MarketRecommendation> recommendations;

  DiseaseResult({
    required this.disease,
    required this.language,
    required this.instruction,
    required this.dosagePerAcre,
    required this.recommendations,
  });

  factory DiseaseResult.fromJson(Map<String, dynamic> json) {
    return DiseaseResult(
      disease: json['disease'] ?? '',
      language: json['language'] ?? 'en',
      instruction: json['instruction'] ?? '',
      dosagePerAcre: json['dosage_per_acre'] ?? '',
      recommendations: (json['market_recommendations'] as List? ?? [])
          .map((item) => MarketRecommendation.fromJson(item))
          .toList(),
    );
  }
}

class MarketRecommendation {
  final String localBrand;
  final String company;
  final String size;
  final double pkrPrice;
  final int requiredPacks;

  MarketRecommendation({
    required this.localBrand,
    required this.company,
    required this.size,
    required this.pkrPrice,
    required this.requiredPacks,
  });

  factory MarketRecommendation.fromJson(Map<String, dynamic> json) {
    return MarketRecommendation(
      localBrand: json['local_brand'] ?? '',
      company: json['company'] ?? '',
      size: json['size'] ?? '',
      pkrPrice: (json['pkr_price'] as num? ?? 0.0).toDouble(),
      requiredPacks: json['required_packs'] ?? 0,
    );
  }
}
