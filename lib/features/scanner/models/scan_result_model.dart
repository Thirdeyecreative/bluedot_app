class ScanResult {
  final String status; // 'new_tag' | 'verified'
  final String message;
  final String treeId;
  final String? speciesMatched;
  final int pointsAwarded;
  final int totalPoints;
  final String? assetUrl;
  final PlantNetData? plantnetData;

  const ScanResult({
    required this.status,
    required this.message,
    required this.treeId,
    this.speciesMatched,
    required this.pointsAwarded,
    required this.totalPoints,
    this.assetUrl,
    this.plantnetData,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
        status: json['status'] as String? ?? 'new_tag',
        message: json['message'] as String? ?? '',
        treeId: json['tree_id'] as String? ?? '',
        speciesMatched: json['species_matched'] as String?,
        pointsAwarded: json['points_awarded'] as int? ?? 0,
        totalPoints: json['total_points'] as int? ?? 0,
        assetUrl: json['asset_url'] as String?,
        plantnetData: json['plantnet_data'] != null
            ? PlantNetData.fromJson(json['plantnet_data'] as Map<String, dynamic>)
            : null,
      );

  bool get isNewTag => status == 'new_tag';
}

class PlantNetData {
  final String? scientificName;
  final String? commonName;
  final double? score;
  final String? family;

  const PlantNetData({
    this.scientificName,
    this.commonName,
    this.score,
    this.family,
  });

  factory PlantNetData.fromJson(Map<String, dynamic> json) {
    // Pl@ntNet returns results as a list; pick the top one
    final results = json['results'] as List<dynamic>?;
    if (results != null && results.isNotEmpty) {
      final top = results.first as Map<String, dynamic>;
      final species = top['species'] as Map<String, dynamic>?;
      final commonNames = species?['commonNames'] as List<dynamic>?;
      return PlantNetData(
        scientificName: species?['scientificNameWithoutAuthor'] as String?,
        commonName: commonNames?.isNotEmpty == true ? commonNames!.first as String? : null,
        score: (top['score'] as num?)?.toDouble(),
        family: (species?['family'] as Map<String, dynamic>?)?['scientificNameWithoutAuthor'] as String?,
      );
    }
    return PlantNetData(
      scientificName: json['scientific_name'] as String?,
      commonName: json['common_name'] as String?,
      score: (json['score'] as num?)?.toDouble(),
    );
  }
}

class ScanHistoryItem {
  final String id;
  final String? imageUrl;
  final String? taggedAt;
  final Map<String, dynamic>? plantnetSummary;

  const ScanHistoryItem({
    required this.id,
    this.imageUrl,
    this.taggedAt,
    this.plantnetSummary,
  });

  factory ScanHistoryItem.fromJson(Map<String, dynamic> json) => ScanHistoryItem(
        id: json['id'] as String,
        imageUrl: json['image_url'] as String?,
        taggedAt: json['tagged_at'] as String?,
        plantnetSummary: json['plantnet_data_summary'] as Map<String, dynamic>?,
      );
}
