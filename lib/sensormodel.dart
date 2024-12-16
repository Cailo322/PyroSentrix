class SensorData {
  final double carbonMonoxide;
  final double humidity;
  final double indoorAirQuality;
  final double smokeLevel;
  final double temperatureDht22;
  final double temperature_mlx90614;
  final String timestamp;

  SensorData({
    required this.carbonMonoxide,
    required this.humidity,
    required this.indoorAirQuality,
    required this.smokeLevel,
    required this.temperatureDht22,
    required this.temperature_mlx90614,
    required this.timestamp,
  });

  factory SensorData.fromMap(Map<String, dynamic> data) {
    return SensorData(
      carbonMonoxide: data['carbon_monoxide']?.toDouble() ?? 0.0,
      humidity: data['humidity_dht22']?.toDouble() ?? 0.0,
      indoorAirQuality: data['indoor_air_quality']?.toDouble() ?? 0.0,
      smokeLevel: data['smoke_level']?.toDouble() ?? 0.0,
      temperatureDht22: data['temperature_dht22']?.toDouble() ?? 0.0,
      temperature_mlx90614: data['temperature_mlx90614']?.toDouble() ?? 0.0,
      timestamp: data['timestamp'] ?? '',
    );
  }
}