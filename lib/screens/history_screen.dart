import 'dart:io';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'results_screen.dart';
import '../models/disease_result.dart';
import '../utils/string_extensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

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

  Future<void> _clearAllHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: Theme.of(context).cardColor.withValues(alpha: 0.9),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.2)),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              const SizedBox(width: 12),
              Text('Wipe History?', style: GoogleFonts.poppins(fontWeight: FontWeight.w900, color: Colors.redAccent)),
            ],
          ),
          content: Text(
            'This will permanently delete all local and cloud scan data. This action cannot be reversed.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w500, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('CANCEL', style: GoogleFonts.poppins(color: Colors.grey, fontWeight: FontWeight.w800)),
            ),
            Container(
              margin: const EdgeInsets.only(left: 8),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('WIPE ALL', style: GoogleFonts.poppins(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      // Show loading
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clearing history...'), duration: Duration(seconds: 1)),
      );

      await _dbService.clearAllScans();
      _loadHistory();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('History cleared successfully.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'SCAN HISTORY', 
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w900, 
            fontSize: 18,
            letterSpacing: 2.0,
            color: Theme.of(context).primaryColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _clearAllHistory,
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 28),
            tooltip: 'Clear All History',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Background Decorative Blobs
          Positioned(
            top: -100,
            right: -50,
            child: _buildBlob(primaryColor.withValues(alpha: 0.05), 300),
          ),
          Positioned(
            bottom: 100,
            left: -80,
            child: _buildBlob(primaryColor.withValues(alpha: 0.03), 250),
          ),
          
          RefreshIndicator(
            onRefresh: () async {
              _loadHistory();
              await _historyFuture;
            },
            displacement: 100,
            color: primaryColor,
            child: FutureBuilder<List<dynamic>>(
              future: _historyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: _RotatingSprout(size: 60));
                }
                
                if (snapshot.hasError) {
                  return _buildErrorState();
                }

                final history = snapshot.data ?? [];
                if (history.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 70, 16, 20),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final scan = history[index];
                    return _buildAnimatedHistoryCard(scan, index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 100,
            spreadRadius: 50,
          )
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 60, color: Colors.redAccent.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text('Unable to load history', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.grey)),
        ],
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
        child: Dismissible(
          key: Key('scan_${scan['id']}'),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) async {
            final id = scan['id'];
            await _dbService.deleteScan(id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${scan['disease_name']?.toString().toDisplayDisease()} deleted'),
                  action: SnackBarAction(
                    label: 'UNDO',
                    onPressed: () {
                      // Undo logic could be complex with sync, so we just reload for now
                      _loadHistory();
                    },
                  ),
                ),
              );
            }
          },
          background: Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.only(right: 30),
            alignment: Alignment.centerRight,
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 32),
          ),
          child: _buildHistoryCard(scan),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> scan) {
    final String disease = scan['disease_name'] ?? 'Unknown';
    final String crop = (disease).toDisplayCrop();
    final String dateString = scan['created_at'] ?? '';
    final bool isSynced = scan['is_synced'] == 1;
    final primaryColor = Theme.of(context).primaryColor;
    
    String date = '';
    if (dateString.isNotEmpty) {
      try {
        final dt = DateTime.parse(dateString).toLocal();
        date = '${dt.day}/${dt.month}/${dt.year}  ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        date = dateString;
      }
    }
    
    final double confidence = (scan['confidence'] as num?)?.toDouble() ?? 0.0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultsScreen(
              imagePath: scan['image_path'] ?? '',
              diseaseNameEnglish: disease,
              diseaseNameUrdu: disease, // Placeholder
              confidence: confidence,
              diagnosisData: DiseaseResult(
                disease: disease,
                language: 'en',
                instruction: 'Analysis retrieved from your scan history.',
                dosagePerAcre: 'N/A',
                recommendations: [],
              ),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Image/Icon Zone
                  Hero(
                    tag: 'scan_image_${scan['id']}',
                    child: Container(
                      width: 85,
                      height: 85,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(22),
                        image: scan['image_path'] != null && scan['image_path'].isNotEmpty
                            ? DecorationImage(
                                image: FileImage(File(scan['image_path'])),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: scan['image_path'] == null || scan['image_path'].isEmpty
                          ? Center(child: Icon(Icons.eco_rounded, color: primaryColor, size: 32))
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Content Zone
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                crop.toUpperCase(), 
                                style: GoogleFonts.inter(
                                  color: primaryColor, 
                                  fontWeight: FontWeight.w900, 
                                  fontSize: 9,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              date.split('  ').first, // Only show date
                              style: GoogleFonts.inter(
                                color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.4), 
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          disease.toDisplayDisease(), 
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Theme.of(context).textTheme.bodyLarge?.color, 
                            fontWeight: FontWeight.w800, 
                            fontSize: 18,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Confidence Bar
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: confidence,
                                  backgroundColor: primaryColor.withValues(alpha: 0.05),
                                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor.withValues(alpha: 0.8)),
                                  minHeight: 6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${(confidence * 100).toInt()}%', 
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w900, 
                                color: primaryColor, 
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final primaryColor = Theme.of(context).primaryColor;
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated Illustration
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer Glowing Ring
              AnimatedBuilder(
                animation: _floatingController,
                builder: (context, child) {
                  return Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryColor.withValues(alpha: 0.1), width: 2),
                    ),
                    padding: EdgeInsets.all(20 * (1 - _floatingController.value)),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: primaryColor.withValues(alpha: 0.05), width: 1),
                      ),
                    ),
                  );
                },
              ),
              // Floating Icon
              AnimatedBuilder(
                animation: _floatingController,
                builder: (context, child) {
                  double offset = disableAnimations ? 0.0 : (_floatingController.value * 30) - 15;
                  return Transform.translate(
                    offset: Offset(0, offset),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.2),
                            blurRadius: 30,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: Icon(Icons.history_toggle_off_rounded, size: 50, color: primaryColor),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 40),
          Text(
            'NO SCANS FOUND', 
            style: GoogleFonts.poppins(
              color: Theme.of(context).textTheme.bodyLarge?.color, 
              fontSize: 22, 
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your field analysis history is empty. Start your first scan to monitor your crop health.', 
            textAlign: TextAlign.center, 
            style: GoogleFonts.inter(
              color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.5), 
              fontSize: 14, 
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 40),
          // CTA Button
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 8,
              shadowColor: primaryColor.withValues(alpha: 0.4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.qr_code_scanner_rounded),
                const SizedBox(width: 12),
                Text(
                  'START SCANNING', 
                  style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ],
            ),
          ),
        ],
      ),
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
    return RotationTransition(
      turns: _controller,
      child: Icon(Icons.eco, color: Theme.of(context).primaryColor, size: widget.size),
    );
  }
}
