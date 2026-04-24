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
      id: map['id'].toString(),
      lat: map['lat'] as double,
      lng: map['lng'] as double, // Wait, DatabaseService might use different names
      diseaseType: map['disease'] as String,
      confidence: map['confidence'] as double,
      date: DateTime.parse(map['created_at'] as String),
      isRemote: false,
    );
  }
}
