import 'package:uuid/uuid.dart';

class Crop {
  final String id;
  final String locationId;
  final String cultivationName;
  final String memo;
  final DateTime startDate;
  final DateTime createdAt;

  Crop({
    String? id,
    required this.locationId,
    required this.cultivationName,
    this.memo = '',
    DateTime? startDate,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        startDate = startDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'location_id': locationId,
        'cultivation_name': cultivationName,
        'memo': memo,
        'start_date': startDate.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  factory Crop.fromMap(Map<String, dynamic> map) => Crop(
        id: map['id'] as String,
        locationId: map['location_id'] as String,
        cultivationName: (map['cultivation_name'] as String?) ?? '',
        memo: (map['memo'] as String?) ?? '',
        startDate: DateTime.parse(map['start_date'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
