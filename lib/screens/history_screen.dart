import 'dart:io';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'results_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _dbService = DatabaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1108),
      appBar: AppBar(
        title: const Text('History Vault', style: TextStyle(color: Color(0xFF6CFB7B), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _dbService.getUserScanHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF6CFB7B)));
          }
          
          final history = snapshot.data ?? [];
          if (history.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final scan = history[index];
              return _buildHistoryCard(scan);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> scan) {
    final String disease = scan['disease_name'] ?? 'Unknown';
    final String date = DateTime.parse(scan['created_at']).toLocal().toString().split('.')[0];
    final double confidence = scan['confidence'] ?? 0.0;
    final String imagePath = scan['image_path'] ?? '';
    final bool isSynced = scan['is_synced'] == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        onTap: () {
          // Navigate to details if needed
        },
        contentPadding: const EdgeInsets.all(16),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: imagePath.isNotEmpty && File(imagePath).existsSync()
              ? Image.file(File(imagePath), width: 60, height: 60, fit: BoxFit.cover)
              : Container(width: 60, height: 60, color: Colors.grey.withOpacity(0.2), child: const Icon(Icons.image_not_supported)),
        ),
        title: Text(disease, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(date, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Confidence: ${(confidence * 100).toStringAsFixed(1)}%', 
                  style: TextStyle(color: const Color(0xFF6CFB7B).withOpacity(0.8), fontSize: 12)),
                const Spacer(),
                Icon(isSynced ? Icons.cloud_done : Icons.cloud_off, 
                  size: 14, color: isSynced ? Colors.green : Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 80, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text('No scan history found', style: TextStyle(color: Colors.white38, fontSize: 18)),
        ],
      ),
    );
  }
}
