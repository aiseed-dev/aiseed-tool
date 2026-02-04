import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'image_analysis_service.dart';

/// 植物同定プロバイダーの種類
enum PlantIdProvider {
  /// 同定しない（小さな畑など不要な場合）
  off,

  /// Plant.id API（直接）- 植物特化、コスト低め
  plantId,

  /// サーバー経由（Claude Vision / GPT-4V）- 高精度、雑草も対応
  server,
}

/// Cloud API を使った作物同定サービスの抽象クラス
abstract class PlantIdentificationService {
  /// 画像から作物名を推定する
  Future<List<PlantIdResult>> identify(String imagePath);

  /// APIが利用可能かどうか
  bool get isAvailable;

  /// プロバイダーに応じたサービスを生成
  static PlantIdentificationService create({
    required PlantIdProvider provider,
    String? plantIdApiKey,
    String? serverUrl,
    String? serverToken,
  }) {
    switch (provider) {
      case PlantIdProvider.off:
        return _OffService();
      case PlantIdProvider.plantId:
        return PlantIdService(apiKey: plantIdApiKey);
      case PlantIdProvider.server:
        return ServerPlantIdService(
          serverUrl: serverUrl,
          token: serverToken,
        );
    }
  }
}

/// 同定オフ
class _OffService extends PlantIdentificationService {
  @override
  bool get isAvailable => false;

  @override
  Future<List<PlantIdResult>> identify(String imagePath) async => [];
}

/// Plant.id API を使った実装
/// https://plant.id/
/// 無料枠: 月200リクエスト
/// 植物特化のDBで一般的な作物・雑草に強い
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
          confidence:
              (suggestion['probability'] as num?)?.toDouble() ?? 0.0,
        );
      }).where((r) => r.name.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }
}

/// サーバー経由の植物同定サービス
/// サーバー側で Claude Vision / GPT-4 Vision 等を呼び出す
/// サーバーがAPIキー管理・利用量制御・課金を担当
///
/// サーバーAPI仕様:
///   POST {serverUrl}
///   Content-Type: multipart/form-data
///   Authorization: Bearer {token}  (任意)
///   Body: image (file)
///
///   Response:
///   {
///     "results": [
///       {"name": "トマト", "confidence": 0.95, "description": "..."},
///       ...
///     ]
///   }
class ServerPlantIdService extends PlantIdentificationService {
  final String? _serverUrl;
  final String? _token;

  ServerPlantIdService({String? serverUrl, String? token})
      : _serverUrl = serverUrl,
        _token = token;

  @override
  bool get isAvailable =>
      _serverUrl != null && _serverUrl!.isNotEmpty;

  @override
  Future<List<PlantIdResult>> identify(String imagePath) async {
    if (!isAvailable) return [];

    try {
      final request = http.MultipartRequest('POST', Uri.parse(_serverUrl!));

      if (_token != null && _token!.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $_token';
      }

      request.files.add(
        await http.MultipartFile.fromPath('image', imagePath),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>?;
      if (results == null) return [];

      return results.take(5).map((r) {
        final item = r as Map<String, dynamic>;
        return PlantIdResult(
          name: item['name'] as String? ?? '',
          confidence: (item['confidence'] as num?)?.toDouble() ?? 0.0,
          description: item['description'] as String?,
        );
      }).where((r) => r.name.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }
}
