import 'package:uuid/uuid.dart';

class RecordPhoto {
  final String id;
  final String recordId;
  final String filePath;
  final String? r2Key;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  RecordPhoto({
    String? id,
    required this.recordId,
    required this.filePath,
    this.r2Key,
    this.sortOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'record_id': recordId,
        'file_path': filePath,
        'r2_key': r2Key,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory RecordPhoto.fromMap(Map<String, dynamic> map) => RecordPhoto(
        id: map['id'] as String,
        recordId: map['record_id'] as String,
        filePath: map['file_path'] as String,
        r2Key: map['r2_key'] as String?,
        sortOrder: (map['sort_order'] as int?) ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: map['updated_at'] != null
            ? DateTime.parse(map['updated_at'] as String)
            : DateTime.parse(map['created_at'] as String),
      );
}
