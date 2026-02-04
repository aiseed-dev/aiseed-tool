import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'image_analysis_service.dart';

/// Cloud API を使った作物同定サービスの抽象クラス
abstract class PlantIdentificationService {
  /// 画像から作物名を推定する
  /// APIキーが未設定の場合は空リストを返す
  Future<List<PlantIdResult>> identify(String imagePath);

  /// APIが利用可能かどうか
  bool get isAvailable;
}

/// Plant.id API を使った実装
/// https://plant.id/
/// 無料枠: 月200リクエスト
/// 公開時は有料プランまたはユーザー課金が必要
class PlantIdService extends PlantIdentificationService {
  final String? _apiKey;

  PlantIdService({String? apiKey}) : _apiKey = apiKey;

  @override
  bool get isAvailable => _apiKey != null && _apiKey!.isNotEmpty;

  @override
  Future<List<PlantIdResult>> identify(String imagePath) async {
    if (!isAvailable) return [];

    try {
      final bytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('https://api.plant.id/v3/identification'),
        headers: {
          'Api-Key': _apiKey!,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'images': ['data:image/jpeg;base64,$base64Image'],
          'similar_images': false,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final result = data['result'] as Map<String, dynamic>?;
      if (result == null) return [];

      final classification =
          result['classification'] as Map<String, dynamic>?;
      if (classification == null) return [];

      final suggestions = classification['suggestions'] as List<dynamic>?;
      if (suggestions == null) return [];

      return suggestions.take(3).map((s) {
        final suggestion = s as Map<String, dynamic>;
        return PlantIdResult(
          name: suggestion['name'] as String? ?? '',
          confidence: (suggestion['probability'] as num?)?.toDouble() ?? 0.0,
        );
      }).where((r) => r.name.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }
}

/// APIキーが未設定の場合のスタブ実装
/// 設定画面からAPIキーを入力できるようにする想定
class StubPlantIdService extends PlantIdentificationService {
  @override
  bool get isAvailable => false;

  @override
  Future<List<PlantIdResult>> identify(String imagePath) async => [];
}
