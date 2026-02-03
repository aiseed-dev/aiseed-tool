import 'package:uuid/uuid.dart';

/// 栽培場所の環境タイプ
enum EnvironmentType {
  outdoor,    // 露地
  indoor,     // 室内
  balcony,    // ベランダ
  rooftop,    // 屋上
}

class Location {
  final String id;
  final String name;
  final String description;
  final EnvironmentType environmentType;
  final DateTime createdAt;

  Location({
    String? id,
    required this.name,
    this.description = '',
    this.environmentType = EnvironmentType.outdoor,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'environment_type': environmentType.index,
        'created_at': createdAt.toIso8601String(),
      };

  factory Location.fromMap(Map<String, dynamic> map) => Location(
        id: map['id'] as String,
        name: map['name'] as String,
        description: (map['description'] as String?) ?? '',
        environmentType: EnvironmentType.values[
            (map['environment_type'] as int?) ?? 0],
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
