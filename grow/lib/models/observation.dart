import 'package:uuid/uuid.dart';

/// 観測カテゴリ
enum ObservationCategory {
  climate,  // 気象（気温・湿度・降水量・風速等）
  soil,     // 土壌（pH・水分・温度・EC等）
  water,    // 水質（pH・EC等）
}

/// 観測データ（1回の計測で複数のエントリを持つ）
class Observation {
  final String id;
  final String? locationId;
  final String? plotId;
  final ObservationCategory category;
  final DateTime date;
  final String memo;
  final DateTime createdAt;

  Observation({
    String? id,
    this.locationId,
    this.plotId,
    required this.category,
    DateTime? date,
    this.memo = '',
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        date = date ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'location_id': locationId,
        'plot_id': plotId,
        'category': category.index,
        'date': date.toIso8601String(),
        'memo': memo,
        'created_at': createdAt.toIso8601String(),
      };

  factory Observation.fromMap(Map<String, dynamic> map) => Observation(
        id: map['id'] as String,
        locationId: map['location_id'] as String?,
        plotId: map['plot_id'] as String?,
        category:
            ObservationCategory.values[(map['category'] as int?) ?? 0],
        date: DateTime.parse(map['date'] as String),
        memo: (map['memo'] as String?) ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

/// 観測エントリ（個別の測定値）
class ObservationEntry {
  final String id;
  final String observationId;
  final String key;    // e.g. "temperature", "humidity", "soil_ph"
  final double value;
  final String unit;   // e.g. "°C", "%", "pH"

  ObservationEntry({
    String? id,
    required this.observationId,
    required this.key,
    required this.value,
    this.unit = '',
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() => {
        'id': id,
        'observation_id': observationId,
        'key': key,
        'value': value,
        'unit': unit,
      };

  factory ObservationEntry.fromMap(Map<String, dynamic> map) =>
      ObservationEntry(
        id: map['id'] as String,
        observationId: map['observation_id'] as String,
        key: map['key'] as String,
        value: (map['value'] as num).toDouble(),
        unit: (map['unit'] as String?) ?? '',
      );
}
