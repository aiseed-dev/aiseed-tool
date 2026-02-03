import 'package:uuid/uuid.dart';

/// 区画の覆い・構造タイプ（Locationとの環境差分）
enum CoverType {
  open,       // 露地（覆いなし）
  greenhouse, // ハウス
  tunnel,     // トンネル
  coldFrame,  // フレーム
}

/// 土壌タイプ
enum SoilType {
  unknown,    // 不明
  clay,       // 粘土質
  silt,       // シルト質
  sandy,      // 砂質
  loam,       // 壌土
  peat,       // 泥炭
  volcanic,   // 火山灰土（黒ボク）
}

class Plot {
  final String id;
  final String locationId;
  final String name;
  final CoverType coverType;
  final SoilType soilType;
  final String memo;
  final DateTime createdAt;

  Plot({
    String? id,
    required this.locationId,
    required this.name,
    this.coverType = CoverType.open,
    this.soilType = SoilType.unknown,
    this.memo = '',
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'location_id': locationId,
        'name': name,
        'cover_type': coverType.index,
        'soil_type': soilType.index,
        'memo': memo,
        'created_at': createdAt.toIso8601String(),
      };

  factory Plot.fromMap(Map<String, dynamic> map) => Plot(
        id: map['id'] as String,
        locationId: map['location_id'] as String,
        name: map['name'] as String,
        coverType: CoverType.values[(map['cover_type'] as int?) ?? 0],
        soilType: SoilType.values[(map['soil_type'] as int?) ?? 0],
        memo: (map['memo'] as String?) ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
