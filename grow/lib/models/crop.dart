import 'package:uuid/uuid.dart';

enum AcquisitionType {
  seedSowing,
  seedlingPurchase,
  seedlingTransplant,
  directSowing,
}

class Crop {
  final String id;
  final String locationId;
  final String cultivationName;
  final String name;
  final String variety;
  final AcquisitionType acquisitionType;
  final DateTime startDate;
  final DateTime createdAt;

  Crop({
    String? id,
    required this.locationId,
    required this.cultivationName,
    required this.name,
    this.variety = '',
    required this.acquisitionType,
    DateTime? startDate,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        startDate = startDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'location_id': locationId,
        'cultivation_name': cultivationName,
        'name': name,
        'variety': variety,
        'acquisition_type': acquisitionType.index,
        'start_date': startDate.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  factory Crop.fromMap(Map<String, dynamic> map) => Crop(
        id: map['id'] as String,
        locationId: map['location_id'] as String,
        cultivationName: (map['cultivation_name'] as String?) ?? '',
        name: map['name'] as String,
        variety: (map['variety'] as String?) ?? '',
        acquisitionType:
            AcquisitionType.values[map['acquisition_type'] as int],
        startDate: DateTime.parse(map['start_date'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
