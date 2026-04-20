import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/disease_result.dart';
import '../providers/locale_provider.dart';
import '../services/api_service.dart';
import '../utils/string_extensions.dart';

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

class _TreatmentDetailScreenState extends State<TreatmentDetailScreen> with TickerProviderStateMixin {
  double _acreage = 1.0;
  DiseaseResult? _apiData;
  bool _isLoading = true;
  String _error = '';
  final _apiService = ApiService();

  // Animations
  late TabController _tabController;
  late AnimationController _shakeController;
  late AnimationController _priceController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    _priceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    if (widget.preFetchedData != null) {
      _apiData = widget.preFetchedData;
      _isLoading = false;
      _onDataLoaded();
    } else {
      _loadTreatment();
    }
  }

  void _onDataLoaded() {
    _priceController.forward(from: 0.0);
    _shakeController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _shakeController.dispose();
    _priceController.dispose();
    super.dispose();
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
        _onDataLoaded();
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
    final String cleanDisease = widget.diseaseLabel.toDiseaseOnly();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        title: Text(isUrdu ? 'علاج کی تفصیلات' : 'Treatment Details', 
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading 
        ? _buildLoadingState()
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
                    const SizedBox(height: 20),
                    _buildWarningBanner(isUrdu),
                    const SizedBox(height: 25),
                    _buildTabSelector(isUrdu),
                    const SizedBox(height: 12),
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

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: List.generate(5, (index) => _ShimmerBox(
          height: index == 0 ? 120 : 80,
          margin: const EdgeInsets.only(bottom: 20),
        )),
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
                style: const TextStyle(color: Color(0xFF2ECC71), fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${widget.plantName.toDisplayDisease()} — ${disease.toDisplayDisease()}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black),
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

  Widget _buildWarningBanner(bool isUrdu) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        double x = 0;
        if (!disableAnimations && _shakeController.isAnimating) {
           double t = _shakeController.value;
           x = 10 * (t < 0.1 ? 1 : t < 0.2 ? -1 : t < 0.3 ? 1 : t < 0.4 ? -1 : 0);
        }
        return Transform.translate(
          offset: Offset(x, 0),
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.amber.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isUrdu ? 'احتیاط: تجویز کردہ مقدار پر سختی سے عمل کریں۔' : 'Caution: Follow the recommended dosage strictly.',
                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector(bool isUrdu) {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFF2ECC71),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey,
        tabs: [
          Tab(text: isUrdu ? 'قدرتی علاج' : 'Organic'),
          Tab(text: isUrdu ? 'کیمیائی علاج' : 'Chemical'),
        ],
      ),
    );
  }

  Widget _buildSolutionSection(bool isUrdu) {
    return SizedBox(
      height: 120,
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildSolutionCard(_apiData?.instruction ?? 'Organic treatment details...', const Color(0xFFE8F5E9)),
          _buildSolutionCard('Apply specialized chemical treatment as specified below.', const Color(0xFFFFF3E0)),
        ],
      ),
    );
  }

  Widget _buildSolutionCard(String text, Color bgColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: SingleChildScrollView(
        child: Text(
          text,
          style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87, fontWeight: FontWeight.w500),
        ),
      ),
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
    final disableAnimations = MediaQuery.of(context).disableAnimations;
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
                Text(product.localBrand, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                Text('${product.company} • ${product.size}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  isUrdu ? 'مطلوبہ پیک: ${product.requiredPacks}' : 'Required: ${product.requiredPacks} packs',
                  style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          ScaleTransition(
            scale: disableAnimations ? const AlwaysStoppedAnimation(1.0) : CurvedAnimation(parent: _priceController, curve: Curves.elasticOut),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'PKR ${product.pkrPrice.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.blue),
                ),
              ],
            ),
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
            onChangeEnd: (val) => _loadTreatment(),
          ),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isUrdu ? 'کل خوراک:' : 'Total Dosage:', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  _apiData?.dosagePerAcre ?? 'N/A',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
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
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.grey.shade800)),
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

class _ShimmerBox extends StatefulWidget {
  final double height;
  final EdgeInsets margin;
  const _ShimmerBox({required this.height, required this.margin});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.grey.shade300, Colors.grey.shade100, Colors.grey.shade300],
              stops: [_animation.value - 0.3, _animation.value, _animation.value + 0.3],
            ),
          ),
        );
      },
    );
  }
}
