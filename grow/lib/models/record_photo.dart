import 'package:uuid/uuid.dart';

class RecordPhoto {
  final String id;
  final String recordId;
  final String filePath;
  final int sortOrder;
  final DateTime createdAt;

  RecordPhoto({
    String? id,
    required this.recordId,
    required this.filePath,
    this.sortOrder = 0,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'record_id': recordId,
        'file_path': filePath,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
      };

  factory RecordPhoto.fromMap(Map<String, dynamic> map) => RecordPhoto(
        id: map['id'] as String,
        recordId: map['record_id'] as String,
        filePath: map['file_path'] as String,
        sortOrder: (map['sort_order'] as int?) ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
