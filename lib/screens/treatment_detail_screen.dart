import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/disease_result.dart';
import '../providers/locale_provider.dart';
import '../services/api_service.dart';

class TreatmentDetailScreen extends StatefulWidget {
  final String diseaseLabel;
  final String plantName;
  final DiseaseResult? preFetchedData;

  const TreatmentDetailScreen({
    super.key,
    required this.diseaseLabel,
    required this.plantName,
    this.preFetchedData,
  });

  @override
  State<TreatmentDetailScreen> createState() => _TreatmentDetailScreenState();
}

class _TreatmentDetailScreenState extends State<TreatmentDetailScreen> {
  double _acreage = 1.0;
  DiseaseResult? _apiData;
  bool _isLoading = true;
  String _error = '';
  final _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    if (widget.preFetchedData != null) {
      _apiData = widget.preFetchedData;
      _isLoading = false;
    } else {
      _loadTreatment();
    }
  }

  Future<void> _loadTreatment() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final lang = context.read<LocaleProvider>().locale.languageCode;
      final data = await _apiService.fetchDiagnosisDetails(
        widget.diseaseLabel, 
        acres: _acreage,
        lang: lang,
      );
      if (mounted) {
        setState(() {
          _apiData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Backend Connection Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isUrdu = context.watch<LocaleProvider>().locale.languageCode == 'ur';
    final String cleanDisease = widget.diseaseLabel.split('___').last.replaceAll('_', ' ');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        title: Text(isUrdu ? 'علاج کی تفصیلات' : 'Treatment Details', 
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF2ECC71)))
        : _error.isNotEmpty 
          ? _buildErrorState(isUrdu)
          : _apiData == null 
            ? _buildEmptyState(isUrdu)
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(cleanDisease, isUrdu),
                    const SizedBox(height: 25),
                    _buildSolutionSection(isUrdu),
                    const SizedBox(height: 25),
                    _buildMarketSection(isUrdu),
                    const SizedBox(height: 25),
                    _buildDosageCalculator(isUrdu),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
    );
  }

  Widget _buildHeader(String disease, bool isUrdu) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_turned_in, color: Color(0xFF2ECC71)),
              const SizedBox(width: 8),
              Text(
                isUrdu ? 'تشخیص مکمل' : 'Diagnosis Confirmed',
                style: const TextStyle(color: Color(0xFF2ECC71), fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${widget.plantName} — $disease',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 8),
          Text(
            isUrdu ? 'طبی رپورٹ پر مبنی سفارشات' : 'Recommendations based on clinical report',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSolutionSection(bool isUrdu) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(isUrdu ? 'تجویز کردہ حل' : 'Recommended Solution', Icons.lightbulb_outline),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFFC8E6C9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _apiData?.instruction ?? '',
                style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMarketSection(bool isUrdu) {
    final List<MarketRecommendation> recommendations = _apiData?.recommendations ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(isUrdu ? 'مارکیٹ کی مصنوعات' : 'Market Products', Icons.shopping_basket_outlined),
        const SizedBox(height: 12),
        ...recommendations.map((item) => _buildProductCard(item, isUrdu)),
      ],
    );
  }

  Widget _buildProductCard(MarketRecommendation product, bool isUrdu) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.inventory_2, color: Colors.blue),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.localBrand, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${product.company} • ${product.size}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  isUrdu ? 'مطلوبہ پیک: ${product.requiredPacks}' : 'Required: ${product.requiredPacks} packs',
                  style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'PKR ${product.pkrPrice.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDosageCalculator(bool isUrdu) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBBDEFB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(isUrdu ? 'خوراک اور قیمت کا حساب' : 'Dosage & Price Calc', Icons.calculate),
          const SizedBox(height: 16),
          Text(
            isUrdu ? 'کھیت کا رقبہ (ایکڑ): ${_acreage.toStringAsFixed(1)}' : 'Field Size (Acres): ${_acreage.toStringAsFixed(1)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Slider(
            value: _acreage,
            min: 0.5,
            max: 10.0,
            divisions: 19,
            activeColor: Colors.blue,
            onChanged: (val) => setState(() => _acreage = val),
            onChangeEnd: (val) => _loadTreatment(), // Re-calculate via backend
          ),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isUrdu ? 'کل خوراک:' : 'Total Dosage:', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  _apiData?.dosagePerAcre ?? 'N/A',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
      ],
    );
  }

  Widget _buildEmptyState(bool isUrdu) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          Text(isUrdu ? 'علاج کی معلومات دستیاب نہیں' : 'Treatment info not available', style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isUrdu) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 60, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(_error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _loadTreatment, child: Text(isUrdu ? 'دوبارہ کوشش کریں' : 'Retry')),
          ],
        ),
      ),
    );
  }
}
