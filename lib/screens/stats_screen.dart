import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';

// ─── theme tokens ─────────────────────────────────────────────────────────────
const _bg      = Color(0xFF0A1108);
const _card    = Color(0xFF152213);
const _border  = Color(0xFF1E3A1A);
const _green   = Color(0xFF6CFB7B);
const _green2  = Color(0xFF2ECC71);
const _red     = Color(0xFFFF5252);

// Palette for the disease bars (lime → teal → amber → red)
const _barColors = [
  Color(0xFF6CFB7B), Color(0xFF26C6DA), Color(0xFFFFB300),
  Color(0xFFFF5252), Color(0xFF7C4DFF), Color(0xFF00E5FF),
  Color(0xFFFF6D00), Color(0xFF69F0AE), Color(0xFFFF4081),
  Color(0xFFEEFF41),
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    setState(() {
      _future = ApiService().fetchCropSummary(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Crop Stats  •  فصل کا احوال',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
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
          // ── KPI row ──────────────────────────────────────────────────────
          Row(
            children: [
              _kpiCard('Total Scans', data.totalScans.toString(),
                  Icons.document_scanner_outlined, _green),
              const SizedBox(width: 12),
              _kpiCard('Diseased', data.diseasedCount.toString(),
                  Icons.coronavirus_outlined, _red),
              const SizedBox(width: 12),
              _kpiCard('Healthy', data.healthyCount.toString(),
                  Icons.spa_outlined, _green2),
            ],
          ),

          const SizedBox(height: 28),

          // ── Pie chart: Healthy vs Diseased ───────────────────────────────
          _sectionLabel('Health Distribution', 'صحت کی تقسیم'),
          const SizedBox(height: 14),
          _cardWrap(
            child: SizedBox(
              height: 240,
              child: Row(
                children: [
                  // Pie
                  Expanded(
                    flex: 3,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            setState(() {
                              if (response == null ||
                                  response.touchedSection == null) {
                                _touchedPieIndex = -1;
                              } else {
                                _touchedPieIndex = response
                                    .touchedSection!.touchedSectionIndex;
                              }
                            });
                          },
                        ),
                        sectionsSpace: 3,
                        centerSpaceRadius: 44,
                        sections: _pieSections(data),
                      ),
                    ),
                  ),
                  // Legend
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _pieLegend(_green, 'Healthy',
                              '${data.healthyPct.toStringAsFixed(1)}%'),
                          const SizedBox(height: 12),
                          _pieLegend(_red, 'Diseased',
                              '${data.diseasedPct.toStringAsFixed(1)}%'),
                          const SizedBox(height: 20),
                          Text('${data.totalScans} total scans',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bar chart: Top diseases ───────────────────────────────────────
          if (data.topDiseases.isNotEmpty) ...[
            const SizedBox(height: 28),
            _sectionLabel('Top Diseases', 'سب سے زیادہ بیماریاں'),
            const SizedBox(height: 14),
            _cardWrap(child: _buildBarChart(data.topDiseases)),
            const SizedBox(height: 24),

            // ── Ranked list ───────────────────────────────────────────────
            _sectionLabel('Disease Breakdown', 'بیماریوں کی تفصیل'),
            const SizedBox(height: 12),
            ...data.topDiseases.asMap().entries.map(
              (e) => _diseaseRow(e.key, e.value, data.totalScans),
            ),
          ],
        ],
      ),
    );
  }

  // ── pie sections ───────────────────────────────────────────────────────────
  List<PieChartSectionData> _pieSections(CropSummary data) {
    final touched0 = _touchedPieIndex == 0;
    final touched1 = _touchedPieIndex == 1;
    return [
      PieChartSectionData(
        value: data.healthyPct,
        color: _green,
        radius: touched0 ? 68 : 58,
        title: touched0 ? '${data.healthyPct.toStringAsFixed(1)}%' : '',
        titleStyle: const TextStyle(
            color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
      ),
      PieChartSectionData(
        value: data.diseasedPct,
        color: _red,
        radius: touched1 ? 68 : 58,
        title: touched1 ? '${data.diseasedPct.toStringAsFixed(1)}%' : '',
        titleStyle: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    ];
  }

  // ── bar chart ──────────────────────────────────────────────────────────────
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
                getTooltipItem: (group, gi, rod, ri) {
                  final name = diseases[group.x].disease
                      .split('___')
                      .last
                      .replaceAll('_', ' ');
                  return BarTooltipItem(
                    '$name\n${rod.toY.toInt()} scans',
                    const TextStyle(
                        color: _green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, _) => Text(
                    v.toInt().toString(),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4), fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= diseases.length) return const SizedBox();
                    // short crop name only
                    final short = diseases[i]
                        .disease
                        .split('___')
                        .first
                        .replaceAll('_', ' ');
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        short.length > 7 ? '${short.substring(0, 7)}…' : short,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.5), fontSize: 9),
                      ),
                    );
                  },
                ),
              ),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              horizontalInterval: (maxVal / 4).ceilToDouble(),
              getDrawingHorizontalLine: (_) => FlLine(
                color: Colors.white.withOpacity(0.05),
                strokeWidth: 1,
              ),
              drawVerticalLine: false,
            ),
            borderData: FlBorderData(show: false),
            barGroups: diseases.asMap().entries.map((e) {
              final color = _barColors[e.key % _barColors.length];
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value.count.toDouble(),
                    color: color,
                    width: 18,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6)),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: (maxVal * 1.3).ceilToDouble(),
                      color: Colors.white.withOpacity(0.03),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ── ranked disease row ────────────────────────────────────────────────────
  Widget _diseaseRow(int index, TopDisease d, int total) {
    final color = _barColors[index % _barColors.length];
    final cleanName = d.disease.split('___').last.replaceAll('_', ' ');
    final crop = d.disease.split('___').first.replaceAll('_', ' ');
    final pct = d.count / total;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  cleanName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
              Text(
                '${d.count} scans',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(crop,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.38), fontSize: 12)),
          ),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.white.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${d.percentage.toStringAsFixed(1)}% of all scans',
            style: TextStyle(
                color: Colors.white.withOpacity(0.3), fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────────
  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 22)),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.45), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String en, String ur) => Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Text(
          '$en  •  $ur',
          style: const TextStyle(
              color: _green,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 0.4),
        ),
      );

  Widget _cardWrap({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
        ),
        child: child,
      );

  Widget _pieLegend(Color color, String label, String value) => Row(
        children: [
          Container(
              width: 12,
              height: 12,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ]),
        ],
      );

  Widget _errorState(String error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  color: Colors.white24, size: 64),
              const SizedBox(height: 16),
              const Text('Could not load stats',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                error.contains('STATS_ERROR_503')
                    ? 'Database offline — try again later.'
                    : 'Check your internet connection.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.45), fontSize: 13),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry',
                    style: TextStyle(fontWeight: FontWeight.bold)),
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
                  color: _green.withOpacity(0.07), shape: BoxShape.circle),
              child: const Icon(Icons.insert_chart_outlined,
                  color: _green, size: 64),
            ),
            const SizedBox(height: 20),
            const Text('No scans yet',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Scan your first plant to see stats here.',
                style:
                    TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14)),
          ],
        ),
      );
}
