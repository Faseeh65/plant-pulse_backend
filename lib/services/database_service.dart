import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_db_service.dart';
import 'storage_service.dart';
import 'package:uuid/uuid.dart';
import '../models/crop_summary.dart';

class DatabaseService {
  final _client = Supabase.instance.client;
  final _localDb = LocalDbService();
  final _storage = StorageService();

  /// Fetches the full causal chain for a given disease class name.
  /// Joins: diseases → pests → crops
  /// Matches on diseases.name_en (must match ML model class name exactly).
  Future<Map<String, dynamic>?> getDiseaseWithCausalChain(
      String diseaseNameEn) async {
    final response = await _client
        .from('diseases')
        .select('''
          id,
          name_en,
          name_ur,
          is_fungal,
          treatment_organic_ur,
          treatment_chemical_ur,
          local_pesticide_names,
          estimated_pkr_price,
          pests (
            id,
            name_en,
            name_ur,
            scientific_name,
            description_ur,
            crops (
              id,
              name_en,
              name_ur
            )
          )
        ''')
        .eq('name_en', diseaseNameEn)
        .maybeSingle();

    return response;
  }

  /// New consolidated Save Scan method (Offline-First)
  Future<void> saveScan({
    required String diseaseName,
    required double confidence,
    required String causalFactor,
    required String imagePath,
    double? lat,
    double? lng,
  }) async {
    final id = const Uuid().v4();
    final createdAt = DateTime.now().toIso8601String();
    final userId = _client.auth.currentUser?.id;

    // 1. Save to Local DB immediately (Always works offline)
    await _localDb.insertScan({
      'id': id,
      'disease_name': diseaseName,
      'confidence': confidence,
      'causal_factor': causalFactor,
      'image_path': imagePath,
      'created_at': createdAt,
      'is_synced': 0,
      'lat': lat,
      'lng': lng,
    });

    // 2. Attempt Background Sync to Supabase
    if (userId != null) {
      _trySync(id, userId, diseaseName, confidence, causalFactor, imagePath, createdAt, lat, lng);
    }
  }

  Future<void> _trySync(String id, String userId, String disease, double conf, String causal, String path, String date, double? lat, double? lng) async {
    try {
      // Upload image
      final imageUrl = await _storage.uploadScanImage(File(path));
      if (imageUrl == null) return;

      // --- Input Sanitization Deployment ---
      // Ensure image_url is properly escaped and validated
      final sanitizedUrl = Uri.tryParse(imageUrl)?.toString() ?? imageUrl;

      // Save to Supabase (Protected by PostgREST parametrization)
      await _client.from('scan_history').insert({
        'id': id,
        'user_id': userId,
        'disease_name': disease,
        'confidence': conf,
        'causal_factor': causal,
        'image_url': sanitizedUrl,
        'created_at': date,
        'lat': lat,
        'lng': lng,
      });

      // Mark locally as synced
      await _localDb.markAsSynced(id, imageUrl);
      print('✅ Scan Synced Successfully: $id');
    } catch (e) {
      print('☁️ Sync Pending (Offline): $e');
    }
  }

  /// Sync all pending scans (e.g., when app restarts or network returns)
  Future<void> syncOfflineScans() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final unsynced = await _localDb.getUnsyncedScans();
    for (var scan in unsynced) {
      await _trySync(
        scan['id'], 
        userId, 
        scan['disease_name'], 
        scan['confidence'], 
        scan['causal_factor'], 
        scan['image_path'], 
        scan['created_at'],
        scan['lat'],
        scan['lng']
      );
    }
  }

  /// Fetches the current user's scan history from local DB (Instant)
  Future<List<Map<String, dynamic>>> getUserScanHistory() async {
    return await _localDb.getAllScans();
  }

  /// Gets analytic summary for the Home Page
  Future<Map<String, dynamic>> getFieldSummary() async {
    return await _localDb.getWeeklyStats();
  }

  /// Fetches aggregated crop statistics (Compatible with StatsScreen)
  Future<CropSummary> fetchCropSummary(String userId) async {
    // 1. Get Local Scans
    var allScans = await _localDb.getAllScans();

    // 2. If local is empty and we have a userId, try fetching from Supabase
    if (allScans.isEmpty && userId.isNotEmpty) {
      try {
        final remoteScans = await _client
            .from('scan_history')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);
        
        if (remoteScans != null && remoteScans.isNotEmpty) {
          // Cache remote scans locally for next time
          for (var s in remoteScans) {
            await _localDb.insertScan({
              'id': s['id'] ?? const Uuid().v4(),
              'disease_name': s['disease_name'],
              'confidence': s['confidence'],
              'causal_factor': s['causal_factor'],
              'image_url': s['image_url'],
              'is_synced': 1,
              'created_at': s['created_at'],
              'lat': s['lat'],
              'lng': s['lng'],
            });
          }
          allScans = await _localDb.getAllScans();
        }
      } catch (e) {
        print('Error fetching remote stats: $e');
      }
    }

    if (allScans.isEmpty) {
      return const CropSummary(
        totalScans: 0,
        healthyCount: 0,
        diseasedCount: 0,
        healthyPct: 0.0,
        diseasedPct: 0.0,
        topDiseases: [],
      );
    }

    int healthy = 0;
    Map<String, int> counts = {};

    for (var s in allScans) {
      final name = (s['disease_name'] as String?) ?? 'Unknown';
      counts[name] = (counts[name] ?? 0) + 1;
      if (name.toLowerCase().contains('healthy')) {
        healthy++;
      }
    }

    final total = allScans.length;
    final diseased = total - healthy;

    final sortedEntries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topDiseases = sortedEntries.map((e) => TopDisease(
      disease: e.key,
      count: e.value,
      percentage: (e.value / total) * 100,
    )).toList();

    return CropSummary(
      totalScans: total,
      healthyCount: healthy,
      diseasedCount: diseased,
      healthyPct: (healthy / total) * 100,
      diseasedPct: (diseased / total) * 100,
      topDiseases: topDiseases,
    );
  }

  /// Deletes a single scan from both local and remote storage
  Future<void> deleteScan(String id) async {
    final userId = _client.auth.currentUser?.id;

    // 1. Delete Local
    await _localDb.deleteScan(id);

    // 2. Delete Remote
    if (userId != null) {
      try {
        await _client.from('scan_history').delete().eq('id', id).eq('user_id', userId);
      } catch (e) {
        print('Error deleting remote scan: $e');
      }
    }
  }

  /// Clears all scans from both local and remote storage
  Future<void> clearAllScans() async {
    final userId = _client.auth.currentUser?.id;
    
    // 1. Clear Local
    await _localDb.deleteAllScans();
    
    // 2. Clear Remote
    if (userId != null) {
      try {
        await _client.from('scan_history').delete().eq('user_id', userId);
      } catch (e) {
        print('Error clearing remote history: $e');
      }
    }
  }
}
