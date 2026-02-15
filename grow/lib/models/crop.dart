import 'package:uuid/uuid.dart';
import '../services/skill_file_generator.dart';

class Crop {
  final String id;
  final String cultivationName;
  final String name;
  final String variety;
  final String? plotId;
  final String? parentCropId;
  final String? farmingMethod;
  final String memo;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  Crop({
    String? id,
    required this.cultivationName,
    this.name = '',
    this.variety = '',
    this.plotId,
    this.parentCropId,
    this.farmingMethod,
    this.memo = '',
    DateTime? startDate,
    this.endDate,
    this.isFavorite = false,
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
        'farming_method': farmingMethod,
        'memo': memo,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'is_favorite': isFavorite ? 1 : 0,
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
        farmingMethod: map['farming_method'] as String?,
        memo: (map['memo'] as String?) ?? '',
        startDate: DateTime.parse(map['start_date'] as String),
        endDate: map['end_date'] != null
            ? DateTime.parse(map['end_date'] as String)
            : null,
        isFavorite: (map['is_favorite'] as int?) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: map['updated_at'] != null
            ? DateTime.parse(map['updated_at'] as String)
            : DateTime.parse(map['created_at'] as String),
      );

  bool get isEnded => endDate != null;

  /// farming_method 文字列を FarmingPractices にパース
  FarmingPractices get practices =>
      FarmingPractices.fromString(farmingMethod);

  Crop copyWith({bool? isFavorite}) => Crop(
        id: id,
        cultivationName: cultivationName,
        name: name,
        variety: variety,
        plotId: plotId,
        parentCropId: parentCropId,
        farmingMethod: farmingMethod,
        memo: memo,
        startDate: startDate,
        endDate: endDate,
        isFavorite: isFavorite ?? this.isFavorite,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
