import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseService {
  final _client = Supabase.instance.client;

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

  /// Saves a scan result to the authenticated user's history.
  Future<void> saveScanHistory({
    required String cropId,
    required String diseaseId,
    required double confidenceScore,
    String? imageUrl,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('scan_history').insert({
      'user_id': userId,
      'crop_id': cropId,
      'disease_id': diseaseId,
      'confidence_score': confidenceScore,
      'image_url': imageUrl,
    });
  }

  /// Fetches the current user's scan history, newest first.
  /// Joins: scan_history → diseases → crops
  Future<List<Map<String, dynamic>>> getUserScanHistory() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('scan_history')
        .select('''
          id,
          confidence_score,
          image_url,
          created_at,
          diseases (
            name_en,
            name_ur
          ),
          crops (
            name_en,
            name_ur
          )
        ''')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }
}
