import 'package:uuid/uuid.dart';

enum CropReferenceType { seedPhoto, web }

class CropReference {
  final String id;
  final String cropId;
  final CropReferenceType type;
  final String? filePath;
  final String? url;
  final String title;
  final String content;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  CropReference({
    String? id,
    required this.cropId,
    required this.type,
    this.filePath,
    this.url,
    this.title = '',
    this.content = '',
    this.sortOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'crop_id': cropId,
        'type': type == CropReferenceType.seedPhoto ? 'seed_photo' : 'web',
        'file_path': filePath,
        'url': url,
        'title': title,
        'content': content,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory CropReference.fromMap(Map<String, dynamic> map) => CropReference(
        id: map['id'] as String,
        cropId: map['crop_id'] as String,
        type: (map['type'] as String) == 'seed_photo'
            ? CropReferenceType.seedPhoto
            : CropReferenceType.web,
        filePath: map['file_path'] as String?,
        url: map['url'] as String?,
        title: (map['title'] as String?) ?? '',
        content: (map['content'] as String?) ?? '',
        sortOrder: (map['sort_order'] as int?) ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: map['updated_at'] != null
            ? DateTime.parse(map['updated_at'] as String)
            : DateTime.parse(map['created_at'] as String),
      );
}
