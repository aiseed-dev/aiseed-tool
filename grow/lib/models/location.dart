import 'package:uuid/uuid.dart';

class Location {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;

  Location({
    String? id,
    required this.name,
    this.description = '',
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'created_at': createdAt.toIso8601String(),
      };

  factory Location.fromMap(Map<String, dynamic> map) => Location(
        id: map['id'] as String,
        name: map['name'] as String,
        description: (map['description'] as String?) ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
