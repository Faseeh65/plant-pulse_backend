import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';
import '../utils/string_extensions.dart';
import '../models/crop_summary.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

// ─── theme tokens ─────────────────────────────────────────────────────────────
// These now serve as default fallback/accent colors
const _green = Color(0xFF1B5E20); // Primary Forest Green
const _green2 = Color(0xFF2E7D32); // Secondary Green
const _red = Color(0xFFC62828); // Muted Red
const _amber = Color(0xFFFFB300); // Amber for disease warnings

// Palette for the disease bars (Natural greens, teals, and accents)
const _barColors = [
  Color(0xFF1B5E20),
  Color(0xFF388E3C),
  Color(0xFF689F38),
  Color(0xFF81C784),
  Color(0xFFA5D6A7),
  Color(0xFF2E7D32),
  Color(0xFF43A047),
  Color(0xFF4CAF50),
  Color(0xFF66BB6A),
  Color(0xFF81C784),
];

// ─── screen ───────────────────────────────────────────────────────────────────

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late Future<CropSummary> _future;
  int _touchedPieIndex = -1;
  Color get _primary => Theme.of(context).primaryColor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    setState(() {
      _future = DatabaseService().fetchCropSummary(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Crop Statistics & Health Trends',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _green),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: FutureBuilder<CropSummary>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _green, strokeWidth: 2.5),
            );
          }
          if (snap.hasError) {
            return _errorState(snap.error.toString());
          }
          final data = snap.data!;
          if (data.totalScans == 0) return _emptyState();
          return _buildContent(context, data);
        },
      ),
    );
  }

  // ── content ────────────────────────────────────────────────────────────────
  Widget _buildContent(BuildContext context, CropSummary data) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _kpiCard(
                  'Total Scans',
                  data.totalScans.toString(),
                  Icons.qr_code_scanner_rounded,
                  _primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _kpiCard(
                  'Healthy',
                  '${data.healthyPct.toStringAsFixed(0)}%',
                  Icons.favorite_rounded,
                  _green2,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _kpiCard(
                  'Diseased',
                  '${(100 - data.healthyPct).toStringAsFixed(0)}%',
                  Icons.bug_report_rounded,
                  _amber,
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          _cardWrap(
            title: 'Health Distribution',
            icon: Icons.pie_chart_outline_rounded,
            child: SizedBox(
              height: 180,
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            setState(() {
                              if (response == null || response.touchedSection == null) {
                                _touchedPieIndex = -1;
                              } else {
                                _touchedPieIndex = response.touchedSection!.touchedSectionIndex;
                              }
                            });
                          },
                        ),
                        sectionsSpace: 3,
                        centerSpaceRadius: 20,
                        sections: _pieSections(data),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _pieLegend(_green, 'Healthy', '${data.healthyPct.toStringAsFixed(0)}%'),
                        const SizedBox(height: 16),
                        _pieLegend(_red, 'Diseased', '${data.diseasedPct.toStringAsFixed(0)}%'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (data.topDiseases.isNotEmpty) ...[
            const SizedBox(height: 28),
            _cardWrap(
              title: 'Top Diseases',
              icon: Icons.analytics_outlined,
              child: _buildBarChart(data.topDiseases),
            ),
            const SizedBox(height: 24),
            _sectionLabel('Disease Breakdown'),
            const SizedBox(height: 12),
            ...data.topDiseases.asMap().entries.map(
              (e) => _diseaseRow(e.key, e.value, data.totalScans),
            ),
          ],
        ],
      ),
    );
  }

  List<PieChartSectionData> _pieSections(CropSummary data) {
    return [
      PieChartSectionData(
        value: data.healthyPct,
        color: _green,
        radius: _touchedPieIndex == 0 ? 32 : 28,
        title: _touchedPieIndex == 0 ? '${data.healthyPct.toStringAsFixed(0)}%' : '',
        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10),
      ),
      PieChartSectionData(
        value: data.diseasedPct,
        color: _red,
        radius: _touchedPieIndex == 1 ? 32 : 28,
        title: _touchedPieIndex == 1 ? '${data.diseasedPct.toStringAsFixed(0)}%' : '',
        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10),
      ),
    ];
  }

  Widget _buildBarChart(List<TopDisease> diseases) {
    final maxVal = diseases.map((d) => d.count).reduce((a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 12, 8),
      child: SizedBox(
        height: 220,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: (maxVal * 1.3).ceilToDouble(),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                tooltipRoundedRadius: 8,
                getTooltipColor: (_) => const Color(0xFF1A2E18),
                getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                  '${rod.toY.toInt()} scans',
                  const TextStyle(color: _green, fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barGroups: diseases.asMap().entries.map((e) {
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value.count.toDouble(),
                    color: _barColors[e.key % _barColors.length],
                    width: 20,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _diseaseRow(int index, TopDisease d, int total) {
    final color = _barColors[index % _barColors.length];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: Text(d.disease.toDisplayDisease(), style: const TextStyle(fontWeight: FontWeight.w900))),
              Text('${d.count} scans', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5))),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: d.count / total, valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 6, backgroundColor: Colors.grey.withOpacity(0.1)),
        ],
      ),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black),
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.4),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
  Widget _cardWrap({required Widget child, String? title, IconData? icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: _primary, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          child,
        ],
      ),
    );
  }

  Widget _sectionLabel(String en) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          en.toUpperCase(),
          style: GoogleFonts.poppins(
            color: _primary.withOpacity(0.8),
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 1.5,
          ),
        ),
      );

  Widget _pieLegend(Color color, String label, String value) => Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.4),
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black),
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      );

  Widget _errorState(String error) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            color: Theme.of(
              context,
            ).textTheme.bodyLarge?.color?.withOpacity(0.15),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'System Sync Interrupted',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.contains('STATS_ERROR_503') ||
                    error.contains('REMINDERS_ERROR_503')
                ? 'Database Sync offline. Please verify your connection or Railway config.'
                : 'Please verify your network status to sync crop data.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color:
                  Theme.of(
                    context,
                  ).textTheme.bodyLarge?.color?.withOpacity(0.5) ??
                  Colors.grey,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text(
              'Retry',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            onPressed: _load,
          ),
        ],
      ),
    ),
  );

  Widget _emptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _green.withOpacity(0.07),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.insert_chart_outlined,
            color: _green,
            size: 64,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'No scans yet',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Scan your first plant to see stats here.',
          style: TextStyle(
            color: Theme.of(
              context,
            ).textTheme.bodyLarge?.color?.withOpacity(0.5),
            fontSize: 14,
          ),
        ),
      ],
    ),
  );
}
