import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/map_provider.dart';
import 'package:fl_chart/fl_chart.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _green = Color(0xFF6CFB7B);
  static const _bg = Color(0xFF0A0E0A);
  static const _amber = Color(0xFFFFB74D);
  
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? _bg : const Color(0xFFF5F7F5),
      body: Stack(
        children: [
          // ── Map Engine (Leaflet/OSM) ──────────────────────────────────────────
          Consumer<MapProvider>(
            builder: (context, provider, _) => FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: provider.userLocation ?? ll.LatLng(31.5204, 74.3587), // Default to Lahore as per user's request
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate: provider.currentLayer == MapLayerType.satellite
                      ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.plantpulse.plant_pulse',
                  tileProvider: NetworkTileProvider(
                    headers: {'User-Agent': 'plant_pulse/1.0 (com.plantpulse.plant_pulse)'},
                  ),
                ),
                if (provider.currentLayer == MapLayerType.heatmap)
                  CircleLayer(
                    circles: provider.markers.map((m) => CircleMarker(
                      point: ll.LatLng(m.lat, m.lng),
                      color: Colors.redAccent.withOpacity(0.3),
                      borderStrokeWidth: 0,
                      useRadiusInMeter: true,
                      radius: 300,
                    )).toList(),
                  ),
                MarkerLayer(
                  markers: [
                    if (provider.userLocation != null)
                      Marker(
                        point: provider.userLocation!,
                        width: 60,
                        height: 60,
                        child: _buildUserLocationMarker(),
                      ),
                    ...provider.markers.map((m) => Marker(
                          point: ll.LatLng(m.lat, m.lng),
                          width: 45,
                          height: 45,
                          child: GestureDetector(
                            onTap: () => _showMarkerDetails(m),
                            child: _buildCustomMarker(m.diseaseType),
                          ),
                        )),
                  ],
                ),
              ],
            ),
          ),

          // ── Top Bar (Filters) ──────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: _buildFilterBar(isDark),
          ),

          // ── System Status Indicator ─────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            left: 20,
            child: Consumer<MapProvider>(
              builder: (context, provider, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLayerIndicator(provider.currentLayer, isDark),
                ],
              ),
            ),
          ),

          // ── Floating Action Buttons ─────────────────────────────────────────────
          Positioned(
            bottom: 140,
            right: 20,
            child: _buildMapTools(),
          ),

          // ── Intelligence Panel (Sliding) ───────────────────────────────────────
          _buildDraggablePanel(isDark),
        ],
      ),
    );
  }

  Widget _buildCustomMarker(String type) {
    Color color;
    final t = type.toLowerCase();
    if (t.contains('bacterial')) color = Colors.redAccent;
    else if (t.contains('brown')) color = Colors.orangeAccent;
    else if (t.contains('tungro')) color = Colors.purpleAccent;
    else color = _green;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing background
        _MarkerPulse(color: color),
        // Central icon
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10)],
          ),
          child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 14),
        ),
      ],
    );
  }

  Widget _buildUserLocationMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        _MarkerPulse(color: Colors.blueAccent),
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: Colors.blueAccent,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(color: Colors.blueAccent.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)
            ],
          ),
        ),
      ],
    );
  }

  void _showMarkerDetails(dynamic data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.diseaseType.toUpperCase(),
              style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Confidence: ${(data.confidence * 100).toStringAsFixed(1)}%',
              style: GoogleFonts.inter(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Detected on: ${data.date.toString().split(' ')[0]}',
              style: GoogleFonts.inter(color: isDark ? Colors.white38 : Colors.black45, fontSize: 12),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('DISMISS'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemStatus(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _green.withOpacity(0.3)),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            'OSM INTEL READY',
            style: GoogleFonts.poppins(
              color: isDark ? _green : const Color(0xFF2E7D32),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          constraints: const BoxConstraints(minHeight: 56),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : Colors.grey).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.black87, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DISEASE MAP',
                        style: GoogleFonts.poppins(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'Spatial Tracking',
                        style: GoogleFonts.inter(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildDiseaseFilter(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiseaseFilter(bool isDark) {
    return Consumer<MapProvider>(
      builder: (context, provider, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _green.withOpacity(0.3)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: provider.selectedDisease,
            isDense: true,
            dropdownColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _green, size: 16),
            items: ['Show All', 'Bacterial Blight', 'Brown Spot', 'Tungro']
                .map((str) => DropdownMenuItem(
                      value: str,
                      child: Text(
                        str,
                        style: GoogleFonts.poppins(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ))
                .toList(),
            onChanged: (val) {
              if (val != null) provider.setFilter(val);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMapTools() {
    return Consumer<MapProvider>(
      builder: (context, provider, _) => Column(
        children: [
          _toolButton(
            provider.currentLayer == MapLayerType.satellite 
                ? Icons.map_rounded 
                : provider.currentLayer == MapLayerType.heatmap 
                    ? Icons.grid_view_rounded 
                    : Icons.layers_outlined,
            () => provider.toggleLayer(),
          ),
          const SizedBox(height: 12),
          _toolButton(Icons.my_location_rounded, () async {
            if (provider.userLocation != null) {
              _mapController.move(provider.userLocation!, 15);
            }
          }, isPrimary: true),
        ],
      ),
    );
  }

  Widget _toolButton(IconData icon, VoidCallback onTap, {bool isPrimary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: isPrimary ? _green : Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isPrimary ? Colors.white30 : Colors.white12),
          boxShadow: [BoxShadow(color: (isPrimary ? _green : Colors.black).withOpacity(0.3), blurRadius: 15, spreadRadius: 2)],
        ),
        child: Icon(icon, color: isPrimary ? Colors.black : Colors.white, size: 24),
      ),
    );
  }

  Widget _buildDraggablePanel(bool isDark) {
    return DraggableScrollableSheet(
      initialChildSize: 0.15,
      minChildSize: 0.15,
      maxChildSize: 0.85,
      snap: true,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: isDark 
                    ? const Color(0xFF0D120D).withOpacity(0.92)
                    : Colors.white.withOpacity(0.92),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08),
                ),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildPanelHeader(isDark),
                  const SizedBox(height: 32),
                  _buildStatsGrid(isDark),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'DISEASE SPREAD TREND',
                        style: GoogleFonts.poppins(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        'Last 30 Days',
                        style: GoogleFonts.inter(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildTrendGraph(),
                  const SizedBox(height: 40),
                  _buildActionableAdvice(isDark),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPanelHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Spatial Health Intelligence',
                style: GoogleFonts.poppins(
                  color: isDark ? _green : const Color(0xFF2E7D32),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Aggregated Regional Analysis',
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white38 : Colors.black45,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
          ),
          child: Text(
            'RISK: HIGH',
            style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    return Row(
      children: [
        _statCard('Active Clusters', '04', Colors.orangeAccent, isDark),
        const SizedBox(width: 12),
        _statCard('Total Scans', '28', _green, isDark),
        const SizedBox(width: 12),
        _statCard('Radius', '5km', Colors.lightBlueAccent, isDark),
      ],
    );
  }

  Widget _statCard(String label, String val, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Text(val, style: GoogleFonts.poppins(color: color, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                color: isDark ? Colors.white24 : Colors.black26,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendGraph() {
    return Container(
      height: 180,
      padding: const EdgeInsets.only(right: 20),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(
            show: true,
            drawVerticalLine: false,
          ),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: const [FlSpot(0, 3), FlSpot(2, 6), FlSpot(4, 4), FlSpot(6, 8), FlSpot(8, 5), FlSpot(10, 7)],
              isCurved: true,
              color: _green,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [_green.withOpacity(0.2), _green.withOpacity(0.0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionableAdvice(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
              ? [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.01)]
              : [Colors.black.withOpacity(0.05), Colors.black.withOpacity(0.01)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded, color: _amber, size: 20),
              const SizedBox(width: 12),
              Text(
                'ACTIONABLE ADVICE',
                style: GoogleFonts.poppins(color: _amber, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Regional clusters indicate a high spread of Bacterial Blight. We recommend applying specialized fungicide to preventative zones within 500m of the red markers.',
            style: GoogleFonts.inter(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 13,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayerIndicator(MapLayerType layer, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      child: Text(
        layer.name.toUpperCase(),
        style: GoogleFonts.inter(
          color: isDark ? Colors.white38 : Colors.black38,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _MarkerPulse extends StatefulWidget {
  final Color color;
  const _MarkerPulse({required this.color});

  @override
  State<_MarkerPulse> createState() => _MarkerPulseState();
}

class _MarkerPulseState extends State<_MarkerPulse> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 30 + (20 * _controller.value),
          height: 30 + (20 * _controller.value),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withOpacity(1 - _controller.value),
          ),
        );
      },
    );
  }
}
