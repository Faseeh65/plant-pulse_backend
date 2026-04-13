import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;

class StorageService {
  final _client = Supabase.instance.client;
  static const String bucketName = 'plant-scans';

  Future<String?> uploadScanImage(File imageFile) async {
    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(imageFile.path)}';
      final String path = 'scans/$fileName';

      await _client.storage.from(bucketName).upload(
            path,
            imageFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final String imageUrl = _client.storage.from(bucketName).getPublicUrl(path);
      return imageUrl;
    } catch (e) {
      print('Image Upload Error: $e');
      return null;
    }
  }
}
