import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';
import 'results_screen.dart';
import '../utils/string_extensions.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with TickerProviderStateMixin {
  final _dbService = DatabaseService();
  late Future<List<Map<String, dynamic>>> _historyFuture;

  // Animations
  late AnimationController _listController;
  late AnimationController _floatingController;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _loadHistory();
  }

  @override
  void dispose() {
    _listController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  void _loadHistory() {
    setState(() {
      _historyFuture = _dbService.getUserScanHistory();
    });
    _listController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Scan History', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: Theme.of(context).primaryColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).textTheme.bodyLarge?.color),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadHistory();
          await _historyFuture;
        },
        color: const Color(0xFF6CFB7B),
        child: FutureBuilder<List<dynamic>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: _RotatingSprout(size: 50));
            }
            
            if (snapshot.hasError) {
              return Center(
                child: Text('Error loading history.', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.5))),
              );
            }

            final history = snapshot.data ?? [];
            if (history.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final scan = history[index];
                return _buildAnimatedHistoryCard(scan, index);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildAnimatedHistoryCard(Map<String, dynamic> scan, int index) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    if (disableAnimations) return _buildHistoryCard(scan);

    final start = index * 0.1;
    final end = (start + 0.4).clamp(0.0, 1.0);
    
    final animation = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _listController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ),
    );

    return SlideTransition(
      position: animation,
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _listController,
          curve: Interval(start, end, curve: Curves.easeIn),
        ),
        child: _buildHistoryCard(scan),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> scan) {
    final String disease = scan['disease_name'] ?? 'Unknown';
    final String crop = (disease).toDisplayCrop();
    final String dateString = scan['created_at'] ?? '';
    final bool isSynced = scan['is_synced'] == 1;
    
    String date = '';
    if (dateString.isNotEmpty) {
      try {
        date = DateTime.parse(dateString).toLocal().toString().split('.')[0];
      } catch (_) {
        date = dateString;
      }
    }
    
    final double confidence = (scan['confidence'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
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
        title: Text(crop.toDisplayDisease(), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.w900, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(disease.toDisplayDisease(), style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('Date / تاریخ: $date', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.5), fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('Confidence / یقین: ${(confidence * 100).toStringAsFixed(1)}%', 
                  style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).primaryColor.withOpacity(0.8), fontSize: 12)),
                const Spacer(),
                Icon(
                  isSynced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  size: 16,
                  color: isSynced ? Colors.greenAccent : Colors.white24,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        // 2. Floating Empty State Icon
        AnimatedBuilder(
          animation: _floatingController,
          builder: (context, child) {
            double offset = disableAnimations ? 0.0 : (_floatingController.value * 20) - 10;
            return Transform.translate(
              offset: Offset(0, offset),
              child: child,
            );
          },
          child: Icon(Icons.history_toggle_off, size: 80, color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.1)),
        ),
        const SizedBox(height: 16),
        Text('No scans yet\nابھی تک کوئی اسکین نہیں', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.5), fontSize: 18, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _RotatingSprout extends StatefulWidget {
  final double size;
  const _RotatingSprout({required this.size});

  @override
  State<_RotatingSprout> createState() => _RotatingSproutState();
}

class _RotatingSproutState extends State<_RotatingSprout> with SingleTickerProviderStateMixin {
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
    if (MediaQuery.of(context).disableAnimations) {
      return Icon(Icons.eco, color: const Color(0xFF6CFB7B), size: widget.size);
    }
    return RotationTransition(
      turns: _controller,
      child: Icon(Icons.eco, color: const Color(0xFF6CFB7B), size: widget.size),
    );
  }
}
