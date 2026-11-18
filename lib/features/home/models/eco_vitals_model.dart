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
    this.uvIndex = 4.2,
    this.uvStatus = 'Moderate',
    this.uvAdvisory = 'Moderate sun exposure. Seek tree canopy shade during midday.',
    this.temperature = 26.5,
    this.feelsLike = 28.0,
    this.humidity = 62,
    this.comfortStatus = 'Ideal Comfort',
    this.platformTrees = 0,
    this.estimatedCo2Kg = 0.0,
  });

  factory CityAqiData.fromJson(Map<String, dynamic> json, {String? defaultCity}) {
    final canopy = json['canopy_metrics'] as Map<String, dynamic>?;

    return CityAqiData(
      city: json['city']?.toString() ?? defaultCity ?? 'Bengaluru',
      aqi: (json['aqi'] as num?)?.toInt() ?? 58,
      status: json['status']?.toString() ?? 'Moderate',
      pm25: (json['pm25'] as num?)?.toDouble(),
      recommendation: json['recommendation']?.toString() ??
          'Air quality is acceptable. Favorable conditions for plantation drives.',
      uvIndex: (json['uv_index'] as num?)?.toDouble() ?? 4.2,
      uvStatus: json['uv_status']?.toString() ?? 'Moderate',
      uvAdvisory: json['uv_advisory']?.toString() ??
          'Moderate sun exposure. Seek tree canopy shade during midday.',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 26.5,
      feelsLike: (json['feels_like'] as num?)?.toDouble() ?? 28.0,
      humidity: (json['humidity'] as num?)?.toInt() ?? 62,
      comfortStatus: json['comfort_status']?.toString() ?? 'Ideal Comfort',
      platformTrees: (canopy?['platform_trees'] as num?)?.toInt() ?? 0,
      estimatedCo2Kg: (canopy?['estimated_co2_kg'] as num?)?.toDouble() ?? 0.0,
    );
  }

  static CityAqiData get fallbackBangalore => const CityAqiData(
        city: 'Bengaluru',
        aqi: 58,
        status: 'Moderate',
        pm25: 16.4,
        recommendation:
            'Air quality is acceptable. Favorable conditions for plantation drives.',
        uvIndex: 4.2,
        uvStatus: 'Moderate',
        uvAdvisory: 'Moderate sun exposure. Seek tree canopy shade during midday.',
        temperature: 26.5,
        feelsLike: 28.0,
        humidity: 62,
        comfortStatus: 'Ideal Comfort',
      );
}

typedef EcoVitalsData = CityAqiData;
