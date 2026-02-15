import 'package:uuid/uuid.dart';

enum ActivityType {
  sowing,        // 0: 播種
  transplanting, // 1: 定植
  watering,      // 2: 水やり・散水
  observation,   // 3: 観察
  harvest,       // 4: 収穫
  other,         // 5: その他
  pruning,       // 6: 剪定
  weeding,       // 7: 除草
  bedMaking,     // 8: 畝作り
  tilling,       // 9: 耕運
  potUp,         // 10: 鉢上
  cutting,       // 11: 挿木
  flowering,     // 12: 花付
  shipping,      // 13: 出荷
  management,    // 14: 管理
}

class GrowRecord {
  final String id;
  final String? cropId;
  final String? locationId;
  final String? plotId;
  final ActivityType activityType;
  final DateTime date;
  final String note;
  final double? workHours;
  final String materials;
  // 収穫
  final double? harvestAmount;
  final String harvestUnit;
  // 出荷
  final double? shippingAmount;
  final String shippingUnit;
  final int? shippingPrice;
  final DateTime createdAt;
  final DateTime updatedAt;

  GrowRecord({
    String? id,
    this.cropId,
    this.locationId,
    this.plotId,
    required this.activityType,
    DateTime? date,
    this.note = '',
    this.workHours,
    this.materials = '',
    this.harvestAmount,
    this.harvestUnit = 'kg',
    this.shippingAmount,
    this.shippingUnit = 'kg',
    this.shippingPrice,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        date = date ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'crop_id': cropId,
        'location_id': locationId,
        'plot_id': plotId,
        'activity_type': activityType.index,
        'date': date.toIso8601String(),
        'note': note,
        'work_hours': workHours,
        'materials': materials,
        'harvest_amount': harvestAmount,
        'harvest_unit': harvestUnit,
        'shipping_amount': shippingAmount,
        'shipping_unit': shippingUnit,
        'shipping_price': shippingPrice,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory GrowRecord.fromMap(Map<String, dynamic> map) {
    var activityIndex = map['activity_type'] as int;
    if (activityIndex >= ActivityType.values.length) {
      activityIndex = ActivityType.other.index;
    }
    return GrowRecord(
      id: map['id'] as String,
      cropId: map['crop_id'] as String?,
      locationId: map['location_id'] as String?,
      plotId: map['plot_id'] as String?,
      activityType: ActivityType.values[activityIndex],
      date: DateTime.parse(map['date'] as String),
      note: (map['note'] as String?) ?? '',
      workHours: map['work_hours'] as double?,
      materials: (map['materials'] as String?) ?? '',
      harvestAmount: map['harvest_amount'] as double?,
      harvestUnit: (map['harvest_unit'] as String?) ?? 'kg',
      shippingAmount: map['shipping_amount'] as double?,
      shippingUnit: (map['shipping_unit'] as String?) ?? 'kg',
      shippingPrice: map['shipping_price'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.parse(map['created_at'] as String),
    );
  }
}
