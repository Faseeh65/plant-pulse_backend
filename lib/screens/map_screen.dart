import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/map_provider.dart';
import 'package:fl_chart/fl_chart.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _green = Color(0xFF6CFB7B);
  static const _bg = Color(0xFF0A1108);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // ── Map Engine ──────────────────────────────────────────────────────────
          Consumer<MapProvider>(
            builder: (context, provider, _) => GoogleMap(
              initialCameraPosition: CameraPosition(
                target: provider.userLocation ?? const LatLng(30.3753, 69.3451),
                zoom: 12,
              ),
              markers: provider.markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              // mapStyle: _darkMapStyle, // Removed as it's not defined in this version

              onMapCreated: (controller) {
                // Future: Apply custom dark style
              },
            ),
          ),

          // ── Top Bar (Filters) ──────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: _buildFilterBar(),
          ),

          // ── Floating Action Buttons ─────────────────────────────────────────────
          Positioned(
            bottom: 120,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: _green,
              child: const Icon(Icons.my_location, color: Colors.black),
              onPressed: () {
                // Focus camera on user
              },
            ),
          ),

          // ── Intelligence Panel (Sliding) ───────────────────────────────────────
          DraggableScrollableSheet(
            initialChildSize: 0.12,
            minChildSize: 0.12,
            maxChildSize: 0.8,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withOpacity(0.95),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 25),
                    _buildPanelHeader(),
                    const SizedBox(height: 30),
                    _buildStatsGrid(),
                    const SizedBox(height: 40),
                    const Text('Disease Spread Trend (30 Days)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 20),
                    _buildTrendGraph(),
                    const SizedBox(height: 40),
                    _buildActionableAdvice(),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      height: 55,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const VerticalDivider(width: 1),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Historical Tracking',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ),
          _buildDiseaseFilter(),
        ],
      ),
    );
  }

  Widget _buildDiseaseFilter() {
    return Consumer<MapProvider>(
      builder: (context, provider, _) => DropdownButton<String>(
        value: provider.selectedDisease,
        dropdownColor: const Color(0xFF1A1A1A),
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down, color: _green),
        items: ['Show All', 'Bacterial Blight', 'Brown Spot', 'Tungro']
            .map((str) => DropdownMenuItem(
                  value: str,
                  child: Text(str, style: const TextStyle(color: Colors.white, fontSize: 12)),
                ))
            .toList(),
        onChanged: (val) {
          if (val != null) provider.setFilter(val);
        },
      ),
    );
  }

  Widget _buildPanelHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Spatial Health Intelligence', style: TextStyle(color: _green, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            Text('Aggregated Regional Analysis', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
          child: const Text('RISK: HIGH', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 11)),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        _statItem('Active Clusters', '04', Colors.orange),
        _statItem('Total Scans', '28', _green),
        _statItem('Radius', '5km', Colors.blue),
      ],
    );
  }

  Widget _statItem(String label, String val, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(val, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildTrendGraph() {
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: const [FlSpot(0, 3), FlSpot(2, 6), FlSpot(4, 4), FlSpot(6, 8), FlSpot(8, 5)],
              isCurved: true,
              color: _green,
              barWidth: 4,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: _green.withOpacity(0.1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionableAdvice() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Actionable Advice', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text(
            'Regional clusters indicate a high spread of Bacterial Blight. We recommend applying specialized fungicide to preventative zones within 500m of the red markers.',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  // Placeholder for Google Maps Dark Style JSON
  static const String _darkMapStyle = '[]';
}
