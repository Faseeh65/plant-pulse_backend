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
  late AnimationController _floatingController;
  late AnimationController _pulseController;

  // Notification State
  List<Map<String, dynamic>> _notifications = [
    {
      'icon': Icons.wb_sunny_rounded,
      'title': 'Weather Update',
      'body': 'High humidity detected. Increased risk of Blast disease.',
      'time': 'Just now',
      'color': Colors.orangeAccent,
    },
    {
      'icon': Icons.check_circle_rounded,
      'title': 'Scan Successful',
      'body': 'Rice Leaf Folder detected in Field A. View recommendations.',
      'time': '2 hours ago',
      'color': const Color(0xFF2E5E32),
    },
    {
      'icon': Icons.info_outline_rounded,
      'title': 'System Update',
      'body': 'New AI models for Brown Spot detection are now live.',
      'time': '1 day ago',
      'color': Colors.blueAccent,
    },
  ];

  void _clearNotifications() {
    setState(() {
      _notifications.clear();
    });
    Navigator.pop(context); // Close drawer
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notifications cleared'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }
  
  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _floatingController.dispose();
    _pulseController.dispose();
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
      endDrawer: _buildNotificationDrawer(),
      body: Stack(
        children: [
          // ── Background Adaptive Theme ──────────────────────────────────────────
          _buildThemeBackground(isDark, weather),

          // ── Main Content ───────────────────────────────────────────────────────
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
              // 1. Adaptive Header (Weather & Toggle)
              SliverToBoxAdapter(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                    child: Column(
                      children: [
                        // --- Custom App Bar Header ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Left: Menu Button
                            GestureDetector(
                              onTap: () => _scaffoldKey.currentState?.openDrawer(),
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: Icon(Icons.menu_rounded, color: isDark ? const Color(0xFF6CFB7B) : const Color(0xFF2E5E32), size: 24),
                              ),
                            ),
                            
                            // Center: Branding
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Plant Pulse',
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? Colors.white : const Color(0xFF2E5E32),
                                      letterSpacing: -0.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  Text(
                                    'PRECISION RICE PATHOLOGY',
                                    style: GoogleFonts.inter(
                                      color: isDark ? Colors.white38 : Colors.black38,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 9,
                                      letterSpacing: 1.2,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            
                            // Right: Notification/Spray History Button
                            GestureDetector(
                              onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(Icons.notifications_none_rounded, color: isDark ? const Color(0xFF6CFB7B) : const Color(0xFF2E5E32), size: 24),
                                    Positioned(
                                      top: 12,
                                      right: 12,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(color: Color(0xFF6CFB7B), shape: BoxShape.circle),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildHeroScanZone(),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Interactive Intelligence Cards (Horizontal Carousel)
              SliverToBoxAdapter(
                child: _buildIntelligenceCarousel(weather),
              ),

              // 3. Weather Widget (Moved from top)
              const SliverToBoxAdapter(
                child: WeatherHeader(),
              ),

              const SliverPadding(padding: EdgeInsets.only(bottom: 160)),
            ],
          ),
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
    return Stack(
      children: [
        // Base Background
        Container(color: isDark ? const Color(0xFF0A0E0A) : const Color(0xFFF5F5F5)), 
        
        // Header Area: Soft curved mint-green-to-white gradient
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: MediaQuery.of(context).size.height * 0.4,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  isDark ? const Color(0xFF1B2E1B) : const Color(0xFFE8F5E9), // Soft Mint or Darker Green
                  isDark ? const Color(0xFF0A0E0A) : const Color(0xFFF5F5F5), // Base Match
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(60),
                bottomRight: Radius.circular(60),
              ),
            ),
          ),
        ),
      ],
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
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0A0E0A) : const Color(0xFFF8FFF5),
      width: MediaQuery.of(context).size.width * 0.85, // Exact width feel
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Titles ---
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plant Pulse Menu',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All secondary functions',
                    style: TextStyle(
                      color: isDark ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.4),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- Menu Items ---
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildDrawerItem(
                    icon: Icons.bar_chart_rounded,
                    label: 'Analytics & Stats',
                    routeName: '/stats',
                    isDark: isDark,
                  ),
                  _buildDrawerItem(
                    icon: Icons.map_outlined,
                    label: 'Disease Map',
                    routeName: '/map',
                    isDark: isDark,
                  ),
                  _buildDrawerItem(
                    icon: Icons.person_outline_rounded,
                    label: 'My Profile',
                    routeName: '/profile',
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required String routeName,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, routeName);
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white : Colors.black.withOpacity(0.1),
              width: 1,
            ),
            color: Colors.transparent,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF152213),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF6CFB7B), size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white54 : Colors.black54,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationDrawer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D150B).withOpacity(0.95) : Colors.white.withOpacity(0.95),
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(40)),
        ),
        child: Column(
          children: [
            // --- Header ---
            Container(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Scans',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54,
                      letterSpacing: 1,
                    ),
                  ),
                  TextButton(
                    onPressed: _clearNotifications,
                    child: Text(
                      'Clear All',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- Notification List ---
            Expanded(
              child: _notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            size: 64,
                            color: isDark ? Colors.white24 : Colors.black12,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No new notifications',
                            style: GoogleFonts.poppins(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final item = _notifications[index];
                        return _notificationItem(
                          icon: item['icon'],
                          title: item['title'],
                          body: item['body'],
                          time: item['time'],
                          color: item['color'],
                          isDark: isDark,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notificationItem({
    required IconData icon,
    required String title,
    required String body,
    required String time,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedThemeToggle(ThemeProvider provider) {
    final isDark = provider.isDarkMode;
    return GestureDetector(
      onTap: () => provider.toggleTheme(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A12) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.4) : Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (child, animation) {
            return RotationTransition(
              turns: animation,
              child: ScaleTransition(scale: animation, child: child),
            );
          },
          child: Icon(
            isDark ? Icons.nightlight_round : Icons.sunny,
            key: ValueKey(isDark),
            color: isDark ? const Color(0xFF6CFB7B) : Colors.orangeAccent,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildIntelligenceCarousel(dynamic weather) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dbService.getFieldSummary(),
      builder: (context, snapshot) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final stats = snapshot.data ?? {'count': 0, 'most_common': 'None'};

        return Container(
          height: 240,
          margin: const EdgeInsets.only(top: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                IntelligenceCard(
                  title: 'ENV RISK',
                  subtitle: 'Risk Analysis',
                  accentColor: const Color(0xFFFFB347), 
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${weather?.humidity ?? "--"}',
                            style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          const SizedBox(width: 4),
                          Text('%', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white70)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text('Relative Humidity', style: TextStyle(color: Colors.white70, fontSize: 10)),
                      const SizedBox(height: 15),
                      Container(
                        height: 8,
                        width: 180,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: ((weather?.humidity ?? 0) / 100).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
                              borderRadius: BorderRadius.circular(4)
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IntelligenceCard(
                  title: 'ACTIVITY',
                  subtitle: 'Field Metrics',
                  accentColor: const Color(0xFF6CFB7B),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${stats['count'] ?? 0}', style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
                      const SizedBox(height: 10),
                      const Text('Total Scans', style: TextStyle(color: Colors.white70, fontSize: 10)),
                    ],
                  ),
                ),
                IntelligenceCard(
                  title: 'THREAT',
                  subtitle: 'Disease Alert',
                  accentColor: const Color(0xFFFF5252),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (stats['most_common']?.toString() ?? 'None').toDiseaseOnly(),
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      const Text('Most Common', style: TextStyle(color: Colors.white70, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroScanZone() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: isDark ? Colors.white12 : Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, 5 * _floatingController.value),
                child: child,
              );
            },
            child: Container(
              height: 140,
              width: 140,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFE8F5E9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withOpacity(0.2) : const Color(0xFF2E5E32).withOpacity(0.05),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.eco_rounded, size: 80, color: isDark ? const Color(0xFF6CFB7B) : const Color(0xFF2E5E32)),
                  // Custom Scanning Laser Effect
                  AnimatedBuilder(
                    animation: _floatingController,
                    builder: (context, child) {
                      return Positioned(
                        top: 20 + (100 * _floatingController.value),
                        child: Container(
                          width: 100,
                          height: 2,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6CFB7B),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6CFB7B).withOpacity(0.8),
                                blurRadius: 10,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Field Scanner',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22, 
              fontWeight: FontWeight.w900, 
              color: isDark ? Colors.white : const Color(0xFF2E5E32)
            ),
          ),
          const Text(
            'Scan rice diseases or identify any plant',
            style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 30),
          _buildDualScanButtons(),
        ],
      ),
    );
  }

  Widget _buildDualScanButtons() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_pulseController.value * 0.03),
          child: child,
        );
      },
      child: Row(
        children: [
          // ── Button 1: Rice Scan ──
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E5E32).withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/scanner'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.eco_rounded, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      'Rice Scan',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // ── Button 2: Plant Identify ──
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF81C784).withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/plant-identify'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF2E7D32) : const Color(0xFF81C784),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_florist, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      'Plant Identify',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingDock(bool isDark) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2E1B).withOpacity(0.9) : Colors.white,
        borderRadius: BorderRadius.circular(35),
        border: Border.all(color: isDark ? Colors.white12 : Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _dockItem(
            icon: Icons.history_rounded,
            active: false,
            onTap: () => Navigator.pushNamed(context, '/history'),
          ),
          _dotDivider(),
          _dockItem(
            icon: Icons.camera_alt_rounded,
            active: true,
            onTap: () => Navigator.pushNamed(context, '/scanner'),
          ),
          _dotDivider(),
          _dockItem(
            icon: Icons.medication_liquid_rounded,
            active: false,
            onTap: () => Navigator.pushNamed(context, '/reminders'),
          ),
        ],
      ),
    );
  }

  Widget _dotDivider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        color: isDark ? Colors.white24 : Colors.black12,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _dockItem({required IconData icon, required bool active, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active 
            ? (isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFF0F7F0))
            : Colors.transparent,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: active 
                  ? (isDark ? const Color(0xFF6CFB7B) : const Color(0xFF2E5E32))
                  : (isDark ? Colors.white54 : Colors.black45),
                size: 24,
              ),
              if (active)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF6CFB7B) : const Color(0xFF2E5E32),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
