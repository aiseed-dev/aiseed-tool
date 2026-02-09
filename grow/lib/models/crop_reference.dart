import 'package:uuid/uuid.dart';

enum CropReferenceType { seedPhoto, seedInfo, web }

class CropReference {
  final String id;
  final String cropId;
  final CropReferenceType type;
  final String? filePath;
  final String? url;
  final String? sourceInfoId;
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
    this.sourceInfoId,
    this.title = '',
    this.content = '',
    this.sortOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  static String _typeToString(CropReferenceType t) {
    switch (t) {
      case CropReferenceType.seedPhoto:
        return 'seed_photo';
      case CropReferenceType.seedInfo:
        return 'seed_info';
      case CropReferenceType.web:
        return 'web';
    }
  }

  static CropReferenceType _typeFromString(String s) {
    switch (s) {
      case 'seed_photo':
        return CropReferenceType.seedPhoto;
      case 'seed_info':
        return CropReferenceType.seedInfo;
      default:
        return CropReferenceType.web;
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'crop_id': cropId,
        'type': _typeToString(type),
        'file_path': filePath,
        'url': url,
        'source_info_id': sourceInfoId,
        'title': title,
        'content': content,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory CropReference.fromMap(Map<String, dynamic> map) => CropReference(
        id: map['id'] as String,
        cropId: map['crop_id'] as String,
        type: _typeFromString(map['type'] as String),
        filePath: map['file_path'] as String?,
        url: map['url'] as String?,
        sourceInfoId: map['source_info_id'] as String?,
        title: (map['title'] as String?) ?? '',
        content: (map['content'] as String?) ?? '',
        sortOrder: (map['sort_order'] as int?) ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: map['updated_at'] != null
            ? DateTime.parse(map['updated_at'] as String)
            : DateTime.parse(map['created_at'] as String),
      );
}
