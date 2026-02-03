import 'package:uuid/uuid.dart';

class Plot {
  final String id;
  final String locationId;
  final String name;
  final String memo;
  final DateTime createdAt;

  Plot({
    String? id,
    required this.locationId,
    required this.name,
    this.memo = '',
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'location_id': locationId,
        'name': name,
        'memo': memo,
        'created_at': createdAt.toIso8601String(),
      };

  factory Plot.fromMap(Map<String, dynamic> map) => Plot(
        id: map['id'] as String,
        locationId: map['location_id'] as String,
        name: map['name'] as String,
        memo: (map['memo'] as String?) ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
