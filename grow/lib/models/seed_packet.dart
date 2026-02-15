import 'package:uuid/uuid.dart';

class SeedPacket {
  final String id;
  final String cropName;
  final String variety;
  final String vendor;
  final DateTime? purchaseDate;
  final int? quantity;
  final int? price;
  final String memo;
  final String? photoPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  SeedPacket({
    String? id,
    required this.cropName,
    this.variety = '',
    this.vendor = '',
    this.purchaseDate,
    this.quantity,
    this.price,
    this.memo = '',
    this.photoPath,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'crop_name': cropName,
        'variety': variety,
        'vendor': vendor,
        'purchase_date': purchaseDate?.toIso8601String(),
        'quantity': quantity,
        'price': price,
        'memo': memo,
        'photo_path': photoPath,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory SeedPacket.fromMap(Map<String, dynamic> map) => SeedPacket(
        id: map['id'] as String,
        cropName: (map['crop_name'] as String?) ?? '',
        variety: (map['variety'] as String?) ?? '',
        vendor: (map['vendor'] as String?) ?? '',
        purchaseDate: map['purchase_date'] != null
            ? DateTime.parse(map['purchase_date'] as String)
            : null,
        quantity: map['quantity'] as int?,
        price: map['price'] as int?,
        memo: (map['memo'] as String?) ?? '',
        photoPath: map['photo_path'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: map['updated_at'] != null
            ? DateTime.parse(map['updated_at'] as String)
            : DateTime.parse(map['created_at'] as String),
      );
}
