import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/disease_result.dart';
import '../services/api_service.dart';
import 'treatment_detail_screen.dart';

class ResultsScreen extends StatefulWidget {
  final String imagePath;
  final String diseaseNameEnglish;
  final String diseaseNameUrdu;
  final double confidence;
  final bool isRefined;
  final bool secondaryInspectionRequired;
  final DiseaseResult diagnosisData;

  const ResultsScreen({
    super.key,
    required this.imagePath,
    required this.diseaseNameEnglish,
    required this.diseaseNameUrdu,
    required this.confidence,
    this.isRefined = false,
    this.secondaryInspectionRequired = false,
    required this.diagnosisData,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  @override
  void initState() {
    super.initState();
    // Fire-and-forget cloud save — never blocks UI
    _saveToCloudSilently();
  }

  Future<void> _saveToCloudSilently() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return; // not logged in — skip

    final plantName = widget.diseaseNameEnglish.split('___').first;
    final saved = await ApiService().saveScanResult(
      userId:          userId,
      plantName:       plantName,
      diseaseResult:   widget.diseaseNameEnglish,
      confidenceScore: widget.confidence,
    );

    if (!saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Failed to save to history.',
            style: TextStyle(fontSize: 13),
          ),
          backgroundColor: Colors.amber.shade800,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Unwrap widget fields for use in build
    final imagePath                = widget.imagePath;
    final diseaseNameEnglish       = widget.diseaseNameEnglish;
    final confidence               = widget.confidence;
    final isRefined                = widget.isRefined;
    final secondaryInspectionRequired = widget.secondaryInspectionRequired;
    final diagnosisData            = widget.diagnosisData;
    final bool isHealthy = diseaseNameEnglish.toLowerCase().contains('healthy');
    final String cleanName = diseaseNameEnglish.split('___').last.replaceAll('_', ' ');
    final String plantType = diseaseNameEnglish.split('___').first;

    return Scaffold(
      backgroundColor: const Color(0xFF141414), // Dark background matching the "Details" screen
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Image with Rounded Bottom Corners
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              child: Stack(
                children: [
                  Image.file(
                    File(imagePath),
                    height: 350,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 50,
                    left: 20,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Positioned(
                    top: 60,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        'Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // Main Title & Subtitle
            Center(
              child: Column(
                children: [
                  Text(
                    plantType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cleanName,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Horizontal Thumbnails Row (Mocked from original image for aesthetic)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(4, (index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(imagePath),
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      // Adding varying opacity or slight color filters just to make them look like different angle shots
                      color: Colors.white.withOpacity(1.0 - (index * 0.1)),
                      colorBlendMode: BlendMode.dstATop,
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 30),

            // Secondary Inspection Warning (Only if triggered)
            if (secondaryInspectionRequired)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Secondary Inspection Required',
                              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'تفصیلی معائنے کی ضرورت ہے',
                              style: TextStyle(color: Colors.redAccent, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (secondaryInspectionRequired) const SizedBox(height: 20),

            // Report Details Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$plantType Report',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildReportRow(
                    'Pathology:', 
                    isHealthy 
                        ? 'No disease found, you really take good care of your plant.' 
                        : 'FastAPI Analysis: ${diagnosisData.disease.split('___').last.replaceAll('_', ' ')} detected.\n\n${diagnosisData.instruction.split('\n\n').first}',
                  ),
                  _buildReportRow(
                    'Health Condition:', 
                    isHealthy 
                      ? 'Your plant looks perfectly alright no health issue found.' 
                      : 'The scan indicates a ${isRefined ? "refined " : ""}confidence of ${(confidence * 100).toStringAsFixed(1)}%. Treatment required immediately.'
                  ),
                  _buildReportRow('Dosage Recommendation:', diagnosisData.dosagePerAcre),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Bottom Action Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TreatmentDetailScreen(
                        diseaseLabel: diseaseNameEnglish,
                        plantName: plantType,
                        preFetchedData: diagnosisData, // Pass the backend result
                      ),
                    ),
                  );
                },
                child: Container(
                  height: 60,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6CFB7B), Color(0xFF2ECC71)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2ECC71).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Center(
                    child: Text(
                      isHealthy ? 'Water me' : 'Treat Plant',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportRow(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
