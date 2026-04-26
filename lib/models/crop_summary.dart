class CropSummary {
  final int totalScans;
  final int healthyCount;
  final int diseasedCount;
  final double healthyPct;
  final double diseasedPct;
  final List<TopDisease> topDiseases;

  const CropSummary({
    required this.totalScans,
    required this.healthyCount,
    required this.diseasedCount,
    required this.healthyPct,
    required this.diseasedPct,
    required this.topDiseases,
  });

  factory CropSummary.fromJson(Map<String, dynamic> j) => CropSummary(
        totalScans:    (j['total_scans']    as num?)?.toInt() ?? 0,
        healthyCount:  (j['healthy_count']  as num?)?.toInt() ?? 0,
        diseasedCount: (j['diseased_count'] as num?)?.toInt() ?? 0,
        healthyPct:    (j['healthy_pct']    as num?)?.toDouble() ?? 0.0,
        diseasedPct:   (j['diseased_pct']   as num?)?.toDouble() ?? 0.0,
        topDiseases:   ((j['top_diseases'] as List?) ?? [])
            .map((e) => TopDisease.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class TopDisease {
  final String disease;
  final int count;
  final double percentage;

  TopDisease({
    required this.disease,
    required this.count,
    required this.percentage,
  });

  factory TopDisease.fromJson(Map<String, dynamic> j) => TopDisease(
        disease:    j['disease'] as String? ?? 'Unknown',
        count:      (j['count'] as num?)?.toInt() ?? 0,
        percentage: (j['percentage'] as num?)?.toDouble() ?? 0.0,
      );
}
