class ScanResult {
  final String status; // 'new_tag' | 'verified'
  final String message;
  final String treeId;
  final String? speciesMatched;
  final bool isNewSpecies;
  final int pointsAwarded;
  final int totalPoints;
  final String? assetUrl;
  final PlantNetData? plantnetData;
  final SpeciesInfo? species;

  const ScanResult({
    required this.status,
    required this.message,
    required this.treeId,
    this.speciesMatched,
    this.isNewSpecies = false,
    required this.pointsAwarded,
    required this.totalPoints,
    this.assetUrl,
    this.plantnetData,
    this.species,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
        status: json['status'] as String? ?? 'new_tag',
        message: json['message'] as String? ?? '',
        treeId: json['tree_id'] as String? ?? '',
        speciesMatched: json['species_matched'] as String?,
        isNewSpecies: json['is_new_species'] as bool? ?? false,
        pointsAwarded: json['points_awarded'] as int? ?? 0,
        totalPoints: json['total_points'] as int? ?? 0,
        assetUrl: json['asset_url'] as String?,
        plantnetData: json['plantnet_data'] != null
            ? PlantNetData.fromJson(json['plantnet_data'] as Map<String, dynamic>)
            : null,
        species: json['species'] != null
            ? SpeciesInfo.fromJson(json['species'] as Map<String, dynamic>)
            : null,
      );

  bool get isNewTag => status == 'new_tag';
  bool get isNotIdentified => status == 'not_identified';
}

class SpeciesInfo {
  final String id;
  final String scientificName;
  final String localName;
  final double? co2OffsetFactor;
  final int? growthTimeYears;
  final List<String> imageUrls;
  final List<String> funFacts;
  final bool isPendingReview;

  const SpeciesInfo({
    required this.id,
    required this.scientificName,
    required this.localName,
    this.co2OffsetFactor,
    this.growthTimeYears,
    this.imageUrls = const [],
    this.funFacts = const [],
    this.isPendingReview = false,
  });

  factory SpeciesInfo.fromJson(Map<String, dynamic> json) => SpeciesInfo(
        id: json['id'] as String? ?? '',
        scientificName: json['scientific_name'] as String? ?? '',
        localName: json['local_name'] as String? ?? '',
        co2OffsetFactor: (json['co2_offset_factor'] as num?)?.toDouble(),
        growthTimeYears: json['growth_time_years'] as int?,
        imageUrls: (json['image_urls'] as List<dynamic>?)?.cast<String>() ?? const [],
        funFacts: (json['fun_facts'] as List<dynamic>?)?.cast<String>() ?? const [],
        isPendingReview: json['is_pending_review'] as bool? ?? false,
      );
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
  final List<String> imageUrls;
  final double? lat;
  final double? lng;
  final String? taggedAt;
  final Map<String, dynamic>? plantnetSummary;
  final PlantNetData? plantnetData;
  final SpeciesInfo? species;

  const ScanHistoryItem({
    required this.id,
    this.imageUrl,
    this.imageUrls = const [],
    this.lat,
    this.lng,
    this.taggedAt,
    this.plantnetSummary,
    this.plantnetData,
    this.species,
  });

  bool get hasLocation => lat != null && lng != null;

  factory ScanHistoryItem.fromJson(Map<String, dynamic> json) => ScanHistoryItem(
        id: json['id'] as String,
        imageUrl: json['image_url'] as String?,
        imageUrls: (json['image_urls'] as List<dynamic>?)?.cast<String>() ?? const [],
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
        taggedAt: json['tagged_at'] as String?,
        plantnetSummary: json['plantnet_data_summary'] as Map<String, dynamic>?,
        plantnetData: json['plantnet_data'] != null
            ? PlantNetData.fromJson(json['plantnet_data'] as Map<String, dynamic>)
            : null,
        species: json['species'] != null
            ? SpeciesInfo.fromJson(json['species'] as Map<String, dynamic>)
            : null,
      );
}
