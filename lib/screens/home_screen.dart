import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';
import 'scanner_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _dbService = DatabaseService();

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — Feature Coming Soon\n$feature — جلد آ رہا ہے',
          style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2ECC71),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _dbService.getUserScanHistory(),
        builder: (context, snapshot) {
          final history = snapshot.data ?? [];
          final bool hasHistory = history.isNotEmpty;

          return CustomScrollView(
            slivers: [
              // Luxury Header — increased height to prevent overflow
              SliverAppBar(
                expandedHeight: 260.0,
                floating: false,
                pinned: true,
                backgroundColor: const Color(0xFF0A1108),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1B5E20), Color(0xFF0A1108)],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Plant Pulse',
                                        style: TextStyle(
                                          color: Color(0xFF6CFB7B),
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Keep your crops healthy',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _buildHistoryBadge(context),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildFieldSummary(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white70),
                      onPressed: () async {
                        await Supabase.instance.client.auth.signOut();
                        if (context.mounted) Navigator.pushReplacementNamed(context, '/auth');
                      },
                    ),
                  ),
                ],
              ),

              // Conditional History Section
              if (hasHistory) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Past History',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
                          child: Text(
                            'View All',
                            style: TextStyle(
                              color: const Color(0xFF6CFB7B).withOpacity(0.8),
                              fontWeight: FontWeight.w600,
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
                // Empty State Placeholder
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.spa_outlined, color: Colors.white10, size: 80),
                        SizedBox(height: 16),
                        Text(
                          'No scans yet',
                          style: TextStyle(color: Colors.white24, fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildCustomNavBar(context),
    );
  }

  Widget _buildHistoryBadge(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryScreen())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: const Row(
          children: [
            Icon(Icons.history, color: Color(0xFF6CFB7B), size: 18),
            SizedBox(width: 8),
            Text('Vault', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                _buildStatItem('Weekly Scans', stats['count'].toString(), Icons.analytics_outlined),
                VerticalDivider(color: Colors.white.withOpacity(0.1), thickness: 1, width: 24),
                _buildStatItem('Common Issue', stats['most_common'].split('___').last.replaceAll('_', ' '), Icons.bug_report_outlined),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6CFB7B).withOpacity(0.5), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis, maxLines: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> data) {
    final disease = data['disease_name'] ?? data['diseases']?['name_en'] ?? 'Unknown';
    final crop = data['crops']?['name_en'] ?? disease.split('___').first;
    final confidence = data['confidence'] ?? data['confidence_score'] ?? 0.0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF6CFB7B).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.eco, color: Color(0xFF6CFB7B)),
        ),
        title: Text(
          '$crop',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
          style: TextStyle(color: Colors.white.withOpacity(0.5)),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
      ),
    );
  }

  Widget _buildCustomNavBar(BuildContext context) {
    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withOpacity(0.95),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Home (active)
          const Icon(Icons.home_filled, color: Color(0xFF6CFB7B), size: 28),
          
          // Status — wired with SnackBar
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showComingSoon('Crop Status'),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.insert_chart_outlined, color: Colors.white38, size: 28),
            ),
          ),
          
          // Core Scan Trigger
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ScannerScreen()),
              );
            },
            child: Container(
              height: 60,
              width: 60,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF6CFB7B), Color(0xFF2ECC71)],
                ),
              ),
              child: const Icon(Icons.add_a_photo, color: Colors.black, size: 28),
            ),
          ),
          
          // Reminders — wired with SnackBar
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showComingSoon('Reminders'),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.notifications_none, color: Colors.white38, size: 28),
            ),
          ),
          
          // Profile — wired with SnackBar
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showComingSoon('Profile'),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.person_outline, color: Colors.white38, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}
