class MapMarkerData {
  final String id;
  final double lat;
  final double lng;
  final String diseaseType;
  final double confidence;
  final DateTime date;
  final bool isRemote;

  MapMarkerData({
    required this.id,
    required this.lat,
    required this.lng,
    required this.diseaseType,
    required this.confidence,
    required this.date,
    this.isRemote = false,
  });

  factory MapMarkerData.fromLocal(Map<String, dynamic> map) {
    return MapMarkerData(
      id: map['id']?.toString() ?? '',
      lat: (map['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0.0,
      diseaseType: (map['disease_name'] as String?) ?? 'Healthy',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
      date: DateTime.parse(map['created_at'] as String? ?? DateTime.now().toIso8601String()),
      isRemote: false,
    );
  }
}
