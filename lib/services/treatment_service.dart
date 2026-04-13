import '../models/treatment.dart';

class TreatmentService {
  static final TreatmentService _instance = TreatmentService._internal();
  factory TreatmentService() => _instance;
  TreatmentService._internal();

  final Map<String, TreatmentSolution> _data = {
    // TOMATO MAPPINGS
    "Tomato___Late_blight": TreatmentSolution(
      naturalEnglish: "Apply a mixture of 1 tbsp baking soda and 1 tsp liquid soap in 1 liter of water.",
      naturalUrdu: "ایک لیٹر پانی میں 1 کھانے کا چمچ بیکنگ سوڈا اور 1 چائے کا چمچ مائع صابن ملا کر سپرے کریں۔",
      dosagePerAcreMg: 500, // 500g per acre
      chemicalProducts: [
        MarketProduct(brandName: "Antracol", company: "Bayer", packSize: "500g", pricePKR: 1850),
        MarketProduct(brandName: "Fruton", company: "Engro", packSize: "250g", pricePKR: 950),
      ],
      applicationNotesEnglish: "Spray during cool hours. Repeat every 7-10 days if humidity persists.",
      applicationNotesUrdu: "ٹھنڈے اوقات میں سپرے کریں۔ نمی برقرار رہنے کی صورت میں ہر 7-10 دن بعد دہرائیں۔",
    ),
    "Tomato___Early_blight": TreatmentSolution(
      naturalEnglish: "Use copper-based organic spray or Neem oil (5ml per liter).",
      naturalUrdu: "کاپر پر مبنی نامیاتی سپرے یا نیم کا تیل (5 ملی لیٹر فی لیٹر) استعمال کریں۔",
      dosagePerAcreMg: 400,
      chemicalProducts: [
        MarketProduct(brandName: "Cabrio Top", company: "BASF", packSize: "250g", pricePKR: 2400),
        MarketProduct(brandName: "Polyram", company: "Jaffar Bros", packSize: "500g", pricePKR: 1600),
      ],
      applicationNotesEnglish: "Remove lower infected leaves before spraying.",
      applicationNotesUrdu: "سپرے کرنے سے پہلے نیچے کے متاثرہ پتے ہٹا دیں۔",
    ),
    "Tomato___Leaf_Miner": TreatmentSolution(
      naturalEnglish: "Install yellow sticky traps and use Neem oil spray.",
      naturalUrdu: "پیلی چپکنے والی جالیاں (Sticky Traps) لگائیں اور نیم کے تیل کا سپرے کریں۔",
      dosagePerAcreMg: 350,
      chemicalProducts: [
        MarketProduct(brandName: "Coragen", company: "FMC", packSize: "50ml", pricePKR: 2800),
        MarketProduct(brandName: "Belt", company: "Bayer", packSize: "50ml", pricePKR: 3200),
      ],
      applicationNotesEnglish: "Apply at the first sign of winding tunnels in leaves.",
      applicationNotesUrdu: "پتوں میں بل کھاتی ہوئی سرنگوں کی پہلی علامت پر استعمال کریں۔",
    ),
    
    // POTATO MAPPINGS
    "Potato___Late_blight": TreatmentSolution(
      naturalEnglish: "Destroy infected tubers and apply copper manure.",
      naturalUrdu: "متاثرہ آلوؤں کو تلف کریں اور کاپر پر مبنی قدرتی کھاد ڈالیں۔",
      dosagePerAcreMg: 600,
      chemicalProducts: [
        MarketProduct(brandName: "Revus", company: "Syngenta", packSize: "250ml", pricePKR: 3500),
        MarketProduct(brandName: "Ridomil Gold", company: "Syngenta", packSize: "500g", pricePKR: 2900),
      ],
      applicationNotesEnglish: "Ensure full coverage of both upper and lower leaf surfaces.",
      applicationNotesUrdu: "پتوں کی اوپری اور نچلی دونوں سطحوں پر مکمل کوریج کو یقینی بنائیں۔",
    ),
    "Potato___Early_blight": TreatmentService._internal_getEarlyBlightDefault(),

    // CORN MAPPINGS
    "Corn_(maize)___Common_rust_": TreatmentSolution(
      naturalEnglish: "Improve air circulation and avoid overhead watering.",
      naturalUrdu: "ہوا کی نکاسی کو بہتر بنائیں اور اوپر سے پانی دینے سے گریز کریں۔",
      dosagePerAcreMg: 450,
      chemicalProducts: [
        MarketProduct(brandName: "Tilt", company: "Syngenta", packSize: "100ml", pricePKR: 1450),
        MarketProduct(brandName: "Nativo", company: "Bayer", packSize: "100g", pricePKR: 2200),
      ],
      applicationNotesEnglish: "Apply preventative spray if cool, wet weather is forecast.",
      applicationNotesUrdu: "ٹھنڈے اور برساتی موسم کی پیش گوئی کی صورت میں حفاظتی سپرے کریں۔",
    ),
  };

  static TreatmentSolution _internal_getEarlyBlightDefault() {
    return TreatmentSolution(
      naturalEnglish: "Apply ash to leaves or use compost tea.",
      naturalUrdu: "پتوں پر راکھ ڈالیں یا کمپوسٹ ٹی (Compost Tea) استعمال کریں۔",
      dosagePerAcreMg: 400,
      chemicalProducts: [
        MarketProduct(brandName: "Score", company: "Syngenta", packSize: "100ml", pricePKR: 1250),
      ],
      applicationNotesEnglish: "Alternate chemical classes to prevent resistance.",
      applicationNotesUrdu: "قوت مدافعت پیدا ہونے سے بچنے کے لیے باری باری مختلف ادویات استعمال کریں۔",
    );
  }

  TreatmentSolution? getTreatment(String label) {
    if (_data.containsKey(label)) return _data[label];
    
    // Fallback logic for similar diseases
    if (label.contains('Early_blight')) return _data["Tomato___Early_blight"];
    if (label.contains('Late_blight')) return _data["Tomato___Late_blight"];
    if (label.contains('leaf_disease')) return _data["Tomato___Early_blight"];
    
    return null;
  }

  double calculateRequiredPacks(double dosagePerAcre, double acres) {
    // Basic logic: 1 pack is usually enough for 1 acre for these products
    return (dosagePerAcre * acres) / dosagePerAcre; 
  }
}
