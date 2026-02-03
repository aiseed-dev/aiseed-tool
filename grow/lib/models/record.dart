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
  final String cropId;
  final ActivityType activityType;
  final DateTime date;
  final String note;
  final DateTime createdAt;

  GrowRecord({
    String? id,
    required this.cropId,
    required this.activityType,
    DateTime? date,
    this.note = '',
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        date = date ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'crop_id': cropId,
        'activity_type': activityType.index,
        'date': date.toIso8601String(),
        'note': note,
        'created_at': createdAt.toIso8601String(),
      };

  factory GrowRecord.fromMap(Map<String, dynamic> map) => GrowRecord(
        id: map['id'] as String,
        cropId: map['crop_id'] as String,
        activityType: ActivityType.values[map['activity_type'] as int],
        date: DateTime.parse(map['date'] as String),
        note: (map['note'] as String?) ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
