import 'package:uuid/uuid.dart';

class FarmMaterial {
  final String id;
  final String name;
  final String category; // 肥料, 土, 資材, 道具
  final String vendor;
  final DateTime? purchaseDate;
  final int? quantity;
  final String unit;
  final int? price;
  final String memo;
  final DateTime createdAt;
  final DateTime updatedAt;

  FarmMaterial({
    String? id,
    required this.name,
    this.category = '',
    this.vendor = '',
    this.purchaseDate,
    this.quantity,
    this.unit = '',
    this.price,
    this.memo = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'vendor': vendor,
        'purchase_date': purchaseDate?.toIso8601String(),
        'quantity': quantity,
        'unit': unit,
        'price': price,
        'memo': memo,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory FarmMaterial.fromMap(Map<String, dynamic> map) => FarmMaterial(
        id: map['id'] as String,
        name: (map['name'] as String?) ?? '',
        category: (map['category'] as String?) ?? '',
        vendor: (map['vendor'] as String?) ?? '',
        purchaseDate: map['purchase_date'] != null
            ? DateTime.parse(map['purchase_date'] as String)
            : null,
        quantity: map['quantity'] as int?,
        unit: (map['unit'] as String?) ?? '',
        price: map['price'] as int?,
        memo: (map['memo'] as String?) ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: map['updated_at'] != null
            ? DateTime.parse(map['updated_at'] as String)
            : DateTime.parse(map['created_at'] as String),
      );
}
