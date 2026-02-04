import 'package:uuid/uuid.dart';

class Crop {
  final String id;
  final String cultivationName;
  final String name;
  final String variety;
  final String? plotId;
  final String? parentCropId;
  final String memo;
  final DateTime startDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Crop({
    String? id,
    required this.cultivationName,
    this.name = '',
    this.variety = '',
    this.plotId,
    this.parentCropId,
    this.memo = '',
    DateTime? startDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        startDate = startDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'cultivation_name': cultivationName,
        'name': name,
        'variety': variety,
        'plot_id': plotId,
        'parent_crop_id': parentCropId,
        'memo': memo,
        'start_date': startDate.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Crop.fromMap(Map<String, dynamic> map) => Crop(
        id: map['id'] as String,
        cultivationName: (map['cultivation_name'] as String?) ?? '',
        name: (map['name'] as String?) ?? '',
        variety: (map['variety'] as String?) ?? '',
        plotId: map['plot_id'] as String?,
        parentCropId: map['parent_crop_id'] as String?,
        memo: (map['memo'] as String?) ?? '',
        startDate: DateTime.parse(map['start_date'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: map['updated_at'] != null
            ? DateTime.parse(map['updated_at'] as String)
            : DateTime.parse(map['created_at'] as String),
      );
}
