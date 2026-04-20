import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';
import '../utils/string_extensions.dart';
import 'scanner_screen.dart';
import 'history_screen.dart';
import 'stats_screen.dart';
import 'reminder_screen.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _dbService = DatabaseService();

  // Animations
  late AnimationController _statsController;
  late Animation<Offset> _statCard1Animation;
  late Animation<Offset> _statCard2Animation;

  late AnimationController _swayController;
  late Animation<double> _swayAnimation;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Stats cards: slide in from left staggered
    _statsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _statCard1Animation = Tween<Offset>(begin: const Offset(-1.0, 0.0), end: Offset.zero).animate(
      CurvedAnimation(parent: _statsController, curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic)),
    );
    _statCard2Animation = Tween<Offset>(begin: const Offset(-1.0, 0.0), end: Offset.zero).animate(
      CurvedAnimation(parent: _statsController, curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic)),
    );
    _statsController.forward();

    // Empty state swaying
    _swayController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _swayAnimation = Tween<double>(begin: -3.0 * (3.14159 / 180.0), end: 3.0 * (3.14159 / 180.0)).animate(
      CurvedAnimation(parent: _swayController, curve: Curves.easeInOut),
    );
    _swayController.repeat(reverse: true);

    // Scan button pulse glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 4.0, end: 12.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _statsController.dispose();
    _swayController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — Feature Coming Soon\n$feature — جلد آ رہا ہے',
          style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: const Color(0xFF2ECC71),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double navBarSpace = 80.0 + bottomPadding + 20.0;

    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _dbService.getUserScanHistory(),
        builder: (context, snapshot) {
          final history = snapshot.data ?? [];
          final bool hasHistory = history.isNotEmpty;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 250.0,
                floating: false,
                pinned: true,
                backgroundColor: const Color(0xFF1A1A1A),
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF2E4D2E), // Deep Forest Green
                          Color(0xFF1A1A1A), // Dark Background
                        ],
                        stops: [0.0, 0.8],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Plant Pulse',
                                        style: TextStyle(
                                          color: Color(0xFF6CFB7B),
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      Text(
                                        'Keep your crops healthy',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildThemeToggle(context),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.logout_rounded, color: Colors.white54, size: 22),
                                      onPressed: () async {
                                        await Supabase.instance.client.auth.signOut();
                                        if (context.mounted) Navigator.pushReplacementNamed(context, '/auth');
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _buildFieldSummary(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              if (hasHistory) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Past History',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
                          child: Text(
                            'View All',
                            style: TextStyle(
                              color: const Color(0xFF6CFB7B).withOpacity(0.8),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildHistoryCard(history[index]),
                      childCount: history.length > 5 ? 5 : history.length,
                    ),
                  ),
                ),
              ] else if (snapshot.connectionState == ConnectionState.done) ...[
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: navBarSpace),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 2. Empty state swaying icon
                          AnimatedBuilder(
                            animation: _swayAnimation,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: disableAnimations ? 0.0 : _swayAnimation.value,
                                child: child,
                              );
                            },
                            child: Icon(Icons.energy_savings_leaf_outlined, color: const Color(0xFF6CFB7B).withOpacity(0.3), size: 100),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Scan Your First Crop\nاپنی پہلی فصل اسکین کریں',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 24, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Press camera button to begin\nکیمرہ بٹن دبائیں اور شروع کریں',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.5), fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6CFB7B),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              elevation: 8,
                              shadowColor: const Color(0xFF6CFB7B).withOpacity(0.4),
                            ),
                            icon: const Icon(Icons.camera_alt_rounded, size: 22),
                            label: const Text('Start Scanning', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen())),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else ...[
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF6CFB7B)),
                  ),
                ),
              ],

              SliverToBoxAdapter(child: SizedBox(height: navBarSpace)),
            ],
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SafeArea(
        top: false,
        child: _buildCustomNavBar(context),
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    final isDark = tp.isDarkMode;
    
    return GestureDetector(
      onTap: () => tp.toggleTheme(),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: !isDark ? const Color(0xFF6CFB7B) : Colors.transparent,
                shape: BoxShape.circle,
                boxShadow: !isDark ? [BoxShadow(color: const Color(0xFF6CFB7B).withOpacity(0.4), blurRadius: 8)] : null,
              ),
              child: Icon(Icons.sunny, size: 18, color: !isDark ? Colors.black : Colors.white38),
            ),
            const SizedBox(width: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF6CFB7B) : Colors.transparent,
                shape: BoxShape.circle,
                boxShadow: isDark ? [BoxShadow(color: const Color(0xFF6CFB7B).withOpacity(0.4), blurRadius: 8)] : null,
              ),
              child: Icon(Icons.nightlight_round, size: 18, color: isDark ? Colors.black : Colors.white38),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldSummary() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dbService.getFieldSummary(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {'count': 0, 'most_common': 'None'};
        final disableAnimations = MediaQuery.of(context).disableAnimations;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A).withOpacity(0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: SlideTransition(
                    position: disableAnimations ? const AlwaysStoppedAnimation(Offset.zero) : _statCard1Animation,
                    child: _buildStatItem('Weekly Scans', stats['count'].toString(), Icons.bar_chart_rounded),
                  ),
                ),
                VerticalDivider(color: Colors.white.withOpacity(0.08), thickness: 1, width: 32),
                Expanded(
                  child: SlideTransition(
                    position: disableAnimations ? const AlwaysStoppedAnimation(Offset.zero) : _statCard2Animation,
                    child: _buildStatItem('Common Issue', (stats['most_common'] as String? ?? '').toDiseaseOnly(), Icons.bug_report_rounded),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min, // Fix for overflow
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF6CFB7B).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF6CFB7B), size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Quick history cards logic for potentially "Quick tip cards" if they were these
  Widget _buildHistoryCard(Map<String, dynamic> data) {
    final disease = data['disease_name'] ?? data['diseases']?['name_en'] ?? 'Unknown';
    final crop = data['crops']?['name_en'] ?? (disease as String).toDisplayCrop();
    final confidence = data['confidence'] ?? data['confidence_score'] ?? 0.0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Theme.of(context).cardTheme.elevation != 0 
            ? [BoxShadow(color: Theme.of(context).cardTheme.shadowColor ?? Colors.black12, blurRadius: 12, offset: const Offset(0, 4))] 
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.eco, color: Theme.of(context).primaryColor),
        ),
        title: Text(
          '${crop.toDisplayDisease()}',
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7), fontWeight: FontWeight.w500),
        ),
        trailing: Icon(Icons.chevron_right, color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.3)),
      ),
    );
  }

  Widget _buildCustomNavBar(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    return Container(
      height: 72,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withOpacity(0.97),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.home_filled, color: Color(0xFF6CFB7B), size: 26),
          ),

          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StatsScreen()),
            ),
            child: const Tooltip(
              message: 'Crop Status',
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.insert_chart_outlined, color: Colors.white38, size: 26),
              ),
            ),
          ),

          // 4. Scan button pulse glow
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ScannerScreen()),
              );
            },
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6CFB7B), Color(0xFF2ECC71)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2ECC71).withOpacity(0.4),
                        blurRadius: disableAnimations ? 12.0 : _pulseAnimation.value,
                        spreadRadius: disableAnimations ? 0.0 : _pulseAnimation.value / 4,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: const Icon(Icons.add_a_photo, color: Colors.black, size: 26),
            ),
          ),

          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReminderScreen()),
            ),
            child: const Tooltip(
              message: 'Reminders',
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.notifications_none, color: Colors.white38, size: 26),
              ),
            ),
          ),

          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: const Tooltip(
              message: 'Profile',
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.person_outline, color: Colors.white38, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
