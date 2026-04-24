import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../services/database_service.dart';
import '../utils/string_extensions.dart';
import '../widgets/weather_header.dart';
import '../widgets/intelligence_card.dart';
import '../providers/weather_provider.dart';
import '../providers/theme_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _dbService = DatabaseService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late AnimationController _entranceController;
  
  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final weather = context.watch<WeatherProvider>().currentWeather;
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      drawer: _buildNavigationDrawer(),
      body: Stack(
        children: [
          // ── Background Adaptive Theme ──────────────────────────────────────────
          _buildThemeBackground(isDark, weather),

          // ── Main Content ───────────────────────────────────────────────────────
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Adaptive Header (Weather & Toggle)
              SliverToBoxAdapter(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                _buildDrawerButton(),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Plant Pulse',
                                      style: GoogleFonts.poppins(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        foreground: Paint()
                                          ..shader = LinearGradient(
                                            colors: [primary, primary.withOpacity(0.6)],
                                          ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                                      ),
                                    ),
                                    Text(
                                      'Precision Rice Pathology',
                                      style: TextStyle(color: isDark ? Colors.white30 : Colors.black26, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            _buildAnimatedThemeToggle(themeProvider),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const WeatherHeader(),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Interactive Intelligence Cards (Horizontal Carousel)
              SliverToBoxAdapter(
                child: _buildIntelligenceCarousel(weather),
              ),

              // 3. Hero Scan Zone (Laser Animation)
              SliverToBoxAdapter(
                child: _buildHeroScanZone(),
              ),

              const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
            ],
          ),

          // ── Floating Dock Navigation ───────────────────────────────────────────
          Positioned(
            bottom: 25,
            left: 20,
            right: 20,
            child: _buildFloatingDock(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeBackground(bool isDark, dynamic weather) {
    final humidity = weather?.humidity ?? 0;
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor),
      child: Stack(
        children: [
          if (humidity > 80)
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
                child: Lottie.network(
                  'https://assets10.lottiefiles.com/packages/lf20_S6v9Y9.json', // Fog/Mist
                  fit: BoxFit.cover,
                ),
              ),
            ),
          if (isDark)
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).primaryColor.withOpacity(0.05),
                ),
                child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50), child: const SizedBox()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawerButton() {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _scaffoldKey.currentState?.openDrawer(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.75),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(isDark ? 0.08 : 0.45)),
          ),
          child: Icon(
            Icons.menu_rounded,
            color: isDark ? Colors.white70 : Colors.black87,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationDrawer() {
    final theme = Theme.of(context);
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF0A1108), Color(0xFF152213), Color(0xFF0F1B0C)]
                : const [Color(0xFFF8FFF5), Color(0xFFE9F6EA), Color(0xFFFDFEFB)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(Icons.eco_rounded, color: theme.primaryColor, size: 28),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Plant Pulse Menu',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Quick access to all services',
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.65),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _buildDrawerItem(
                      icon: Icons.map_outlined,
                      label: 'Disease Map',
                      routeName: '/map',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required String routeName,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            final navigator = Navigator.of(context);
            navigator.pop();
            Future.microtask(() => navigator.pushNamed(routeName));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: theme.cardColor.withOpacity(0.42),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.dividerColor.withOpacity(0.6)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: theme.primaryColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.55),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedThemeToggle(ThemeProvider provider) {
    final isDark = provider.isDarkMode;
    return GestureDetector(
      onTap: () => provider.toggleTheme(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A12) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10)],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Icon(
            isDark ? Icons.nightlight_round : Icons.sunny,
            key: ValueKey(isDark),
            color: isDark ? const Color(0xFF6CFB7B) : Colors.orangeAccent,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildIntelligenceCarousel(dynamic weather) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dbService.getFieldSummary(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {'count': 0, 'most_common': 'None'};
        final count = stats['count'] as int;

        return SizedBox(
          height: 180,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            physics: const BouncingScrollPhysics(),
            children: [
              IntelligenceCard(
                title: 'ENV RISK',
                subtitle: 'Live Humidity Gauge',
                accentColor: Colors.orangeAccent,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${weather?.humidity ?? 0}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Container(
                      height: 4,
                      width: 100,
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(5)),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: ((weather?.humidity ?? 0) / 100).clamp(0.0, 1.0),
                        child: Container(decoration: BoxDecoration(color: Colors.orangeAccent, borderRadius: BorderRadius.circular(5))),
                      ),
                    ),
                  ],
                ),
              ),
              IntelligenceCard(
                title: 'RECENT ACTIVITY',
                subtitle: 'Last 7 Days Scans',
                accentColor: const Color(0xFF6CFB7B),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$count', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 35,
                      width: 120,
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: _dbService.getUserScanHistory(),
                        builder: (ctx, histSnap) {
                          final history = histSnap.data ?? [];
                          // Simple mock spots based on real history length or spread
                          final spots = history.isEmpty ? [const FlSpot(0, 0)] : 
                                       history.take(5).toList().asMap().entries.map((e) => FlSpot(e.key.toDouble(), 1 + (e.key % 3).toDouble())).toList();
                          
                          return LineChart(
                            LineChartData(
                              gridData: const FlGridData(show: false),
                              titlesData: const FlTitlesData(show: false),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: spots,
                                  isCurved: true,
                                  color: const Color(0xFF6CFB7B),
                                  barWidth: 3,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(show: true, color: const Color(0xFF6CFB7B).withOpacity(0.1)),
                                ),
                              ],
                            ),
                          );
                        }
                      ),
                    ),
                  ],
                ),
              ),
              IntelligenceCard(
                title: 'TOP THREAT',
                subtitle: 'Regional Alert',
                accentColor: Colors.redAccent,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (stats['most_common'] as String).toDiseaseOnly(), 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
                        SizedBox(width: 4),
                        Text('High Priority', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildHeroScanZone() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Lottie.network(
            'https://assets9.lottiefiles.com/packages/lf20_T6v6tZ.json',
            height: 160,
            errorBuilder: (c, e, s) => Icon(Icons.eco, size: 100, color: Theme.of(context).primaryColor.withOpacity(0.2)),
          ),
          const SizedBox(height: 20),
          Text('Plant Pulse', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w900)),
          const Text('Scan your rice field with AI', style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 30),
          _buildPulseButton(),
        ],
      ),
    );
  }

  Widget _buildPulseButton() {
    return ElevatedButton(
      onPressed: () => Navigator.pushNamed(context, '/scanner'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.black,
        minimumSize: const Size(200, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 15,
        shadowColor: Theme.of(context).primaryColor.withOpacity(0.5),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.camera_alt),
          SizedBox(width: 12),
          Text('START SCANNING', style: TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildFloatingDock(bool isDark) {
    final primary = Theme.of(context).primaryColor;
    return Container(
      height: 75,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.7),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 30)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _dockItem(Icons.camera_alt_rounded, false, primary, onTap: () => Navigator.pushNamed(context, '/scanner')),
              _dockItem(Icons.notifications_active_outlined, false, primary, onTap: () => Navigator.pushNamed(context, '/reminders')),
              _dockItem(Icons.history_rounded, false, primary, onTap: () => Navigator.pushNamed(context, '/history')),
              _dockItem(Icons.bar_chart_rounded, false, primary, onTap: () => Navigator.pushNamed(context, '/stats')),
              _dockItem(
                Icons.person_outline_rounded,
                false,
                primary,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dockItem(IconData icon, bool active, Color primary, {VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 56,
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: active ? primary : Colors.white24, size: 24),
              if (active)
                Container(margin: const EdgeInsets.only(top: 4), width: 4, height: 4, decoration: BoxDecoration(color: primary, shape: BoxShape.circle)),
            ],
          ),
        ),
      ),
    );
  }
}
