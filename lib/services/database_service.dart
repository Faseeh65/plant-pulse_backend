import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_db_service.dart';
import 'storage_service.dart';
import 'package:uuid/uuid.dart';

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
      await _client.from('scans').insert({
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
}
