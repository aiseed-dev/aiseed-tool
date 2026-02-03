import 'package:uuid/uuid.dart';

class Crop {
  final String id;
  final String cultivationName;
  final String name;
  final String variety;
  final String memo;
  final DateTime startDate;
  final DateTime createdAt;

  Crop({
    String? id,
    required this.cultivationName,
    this.name = '',
    this.variety = '',
    this.memo = '',
    DateTime? startDate,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        startDate = startDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'cultivation_name': cultivationName,
        'name': name,
        'variety': variety,
        'memo': memo,
        'start_date': startDate.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  factory Crop.fromMap(Map<String, dynamic> map) => Crop(
        id: map['id'] as String,
        cultivationName: (map['cultivation_name'] as String?) ?? '',
        name: (map['name'] as String?) ?? '',
        variety: (map['variety'] as String?) ?? '',
        memo: (map['memo'] as String?) ?? '',
        startDate: DateTime.parse(map['start_date'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
