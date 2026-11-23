/// Environmental and atmospheric vitals (AQI, Solar UV, Thermal Comfort & Humidity).
class CityAqiData {
  final String city;
  final int aqi;
  final String status;
  final double? pm25;
  final String recommendation;

  // Solar UV Index
  final double uvIndex;
  final String uvStatus;
  final String uvAdvisory;

  // Thermal Comfort & Humidity
  final double temperature;
  final double feelsLike;
  final int humidity;
  final String comfortStatus;

  // BlueDot Local Canopy Metrics
  final int platformTrees;
  final double estimatedCo2Kg;

  const CityAqiData({
    required this.city,
    required this.aqi,
    required this.status,
    this.pm25,
    required this.recommendation,
    required this.uvIndex,
    required this.uvStatus,
    required this.uvAdvisory,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.comfortStatus,
    required this.platformTrees,
    required this.estimatedCo2Kg,
  });

  factory CityAqiData.fromJson(Map<String, dynamic> json) {
    final canopy = json['canopy_metrics'] as Map<String, dynamic>;

    return CityAqiData(
      city: json['city'] as String,
      aqi: (json['aqi'] as num).toInt(),
      status: json['status'] as String,
      pm25: (json['pm25'] as num?)?.toDouble(),
      recommendation: json['recommendation'] as String,
      uvIndex: (json['uv_index'] as num).toDouble(),
      uvStatus: json['uv_status'] as String,
      uvAdvisory: json['uv_advisory'] as String,
      temperature: (json['temperature'] as num).toDouble(),
      feelsLike: (json['feels_like'] as num).toDouble(),
      humidity: (json['humidity'] as num).toInt(),
      comfortStatus: json['comfort_status'] as String,
      platformTrees: (canopy['platform_trees'] as num).toInt(),
      estimatedCo2Kg: (canopy['estimated_co2_kg'] as num).toDouble(),
    );
  }
}

typedef EcoVitalsData = CityAqiData;
