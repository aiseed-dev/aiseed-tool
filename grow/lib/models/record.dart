import 'package:uuid/uuid.dart';

enum ActivityType {
  sowing,
  transplanting,
  watering,
  observation,
  harvest,
  other,
}

class GrowRecord {
  final String id;
  final String? cropId;
  final String? locationId;
  final String? plotId;
  final ActivityType activityType;
  final DateTime date;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;

  GrowRecord({
    String? id,
    this.cropId,
    this.locationId,
    this.plotId,
    required this.activityType,
    DateTime? date,
    this.note = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        date = date ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'crop_id': cropId,
        'location_id': locationId,
        'plot_id': plotId,
        'activity_type': activityType.index,
        'date': date.toIso8601String(),
        'note': note,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory GrowRecord.fromMap(Map<String, dynamic> map) => GrowRecord(
        id: map['id'] as String,
        cropId: map['crop_id'] as String?,
        locationId: map['location_id'] as String?,
        plotId: map['plot_id'] as String?,
        activityType: ActivityType.values[map['activity_type'] as int],
        date: DateTime.parse(map['date'] as String),
        note: (map['note'] as String?) ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: map['updated_at'] != null
            ? DateTime.parse(map['updated_at'] as String)
            : DateTime.parse(map['created_at'] as String),
      );
}
