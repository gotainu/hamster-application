class SwitchBotReading {
  final DateTime ts;
  final double? temperature;
  final double? humidity;

  SwitchBotReading({required this.ts, this.temperature, this.humidity});

  Map<String, dynamic> toJson() => {
        'ts': ts.toIso8601String(),
        'temperature': temperature,
        'humidity': humidity,
      };

  static SwitchBotReading fromMap(Map<String, dynamic> m) => SwitchBotReading(
        ts: DateTime.parse(m['ts'] as String),
        temperature: (m['temperature'] as num?)?.toDouble(),
        humidity: (m['humidity'] as num?)?.toDouble(),
      );
}
