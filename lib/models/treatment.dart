class TreatmentSolution {
  final String naturalUrdu;
  final String naturalEnglish;
  final List<MarketProduct> chemicalProducts;
  final double dosagePerAcreMg; // Standard dosage logic
  final String applicationNotesUrdu;
  final String applicationNotesEnglish;

  TreatmentSolution({
    required this.naturalUrdu,
    required this.naturalEnglish,
    required this.chemicalProducts,
    required this.dosagePerAcreMg,
    required this.applicationNotesUrdu,
    required this.applicationNotesEnglish,
  });
}

class MarketProduct {
  final String brandName;
  final String company;
  final String packSize;
  final int pricePKR;
  final String imagePath;

  MarketProduct({
    required this.brandName,
    required this.company,
    required this.packSize,
    required this.pricePKR,
    this.imagePath = '',
  });
}
