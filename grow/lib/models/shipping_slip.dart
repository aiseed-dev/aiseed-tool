import 'package:uuid/uuid.dart';

class ShippingSlip {
  final String id;
  final String destination;
  final String cropName;
  final double? amount;
  final String unit;
  final int? price;
  final DateTime date;
  final String memo;
  final String? photoPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  ShippingSlip({
    String? id,
    required this.destination,
    this.cropName = '',
    this.amount,
    this.unit = 'kg',
    this.price,
    DateTime? date,
    this.memo = '',
    this.photoPath,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        date = date ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'destination': destination,
        'crop_name': cropName,
        'amount': amount,
        'unit': unit,
        'price': price,
        'date': date.toIso8601String(),
        'memo': memo,
        'photo_path': photoPath,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory ShippingSlip.fromMap(Map<String, dynamic> map) => ShippingSlip(
        id: map['id'] as String,
        destination: (map['destination'] as String?) ?? '',
        cropName: (map['crop_name'] as String?) ?? '',
        amount: map['amount'] as double?,
        unit: (map['unit'] as String?) ?? 'kg',
        price: map['price'] as int?,
        date: DateTime.parse(map['date'] as String),
        memo: (map['memo'] as String?) ?? '',
        photoPath: map['photo_path'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: map['updated_at'] != null
            ? DateTime.parse(map['updated_at'] as String)
            : DateTime.parse(map['created_at'] as String),
      );
}
