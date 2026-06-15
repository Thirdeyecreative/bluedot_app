class TreeSpecies {
  final String id;
  final String localName;
  final String scientificName;
  final double co2OffsetFactor;
  final int growthTimeYears;
  final List<String> imageUrls;
  final String? description;
  final String? family;
  final String? nativeRegion;

  const TreeSpecies({
    required this.id,
    required this.localName,
    required this.scientificName,
    required this.co2OffsetFactor,
    required this.growthTimeYears,
    this.imageUrls = const [],
    this.description,
    this.family,
    this.nativeRegion,
  });

  factory TreeSpecies.fromJson(Map<String, dynamic> json) => TreeSpecies(
        id: json['id'] as String,
        localName: json['local_name'] as String? ?? '',
        scientificName: json['scientific_name'] as String? ?? '',
        co2OffsetFactor: (json['co2_offset_factor'] as num?)?.toDouble() ?? 0,
        growthTimeYears: json['growth_time_years'] as int? ?? 0,
        imageUrls: (json['image_urls'] as List<dynamic>?)?.cast<String>() ?? [],
        description: json['description'] as String?,
        family: json['family'] as String?,
        nativeRegion: json['native_region'] as String?,
      );

  String? get thumbnailUrl => imageUrls.isNotEmpty ? imageUrls.first : null;
}
