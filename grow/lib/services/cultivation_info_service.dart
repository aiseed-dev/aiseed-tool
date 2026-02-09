import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// サーバーから栽培情報を取得するサービス
class CultivationInfoService {
  /// URLからWebページを取得してAIで栽培情報を構造化
  Future<CultivationData?> readFromUrl(String url) async {
    final config = await _getServerConfig();
    if (config == null) return null;

    final response = await http.post(
      Uri.parse('${config.serverUrl}/cultivation-info/read-url'),
      headers: {
        'Content-Type': 'application/json',
        if (config.token.isNotEmpty) 'Authorization': 'Bearer ${config.token}',
      },
      body: jsonEncode({'url': url}),
    );

    if (response.statusCode != 200) return null;
    return CultivationData.fromJson(jsonDecode(response.body));
  }

  /// 種袋写真からAIで栽培情報を構造化
  Future<CultivationData?> readFromImage(String imagePath) async {
    final config = await _getServerConfig();
    if (config == null) return null;

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${config.serverUrl}/cultivation-info/read-image'),
    );
    if (config.token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer ${config.token}';
    }
    request.files.add(await http.MultipartFile.fromPath('image', imagePath));

    final streamedResponse = await request.send();
    if (streamedResponse.statusCode != 200) return null;

    final body = await streamedResponse.stream.bytesToString();
    return CultivationData.fromJson(jsonDecode(body));
  }

  /// URLで既存の栽培情報を検索（キャッシュ）
  Future<CultivationData?> searchByUrl(String url) async {
    final config = await _getServerConfig();
    if (config == null) return null;

    final response = await http.get(
      Uri.parse(
          '${config.serverUrl}/cultivation-info?url=${Uri.encodeComponent(url)}'),
      headers: {
        if (config.token.isNotEmpty) 'Authorization': 'Bearer ${config.token}',
      },
    );

    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body);
    final results = data['results'] as List;
    if (results.isEmpty) return null;
    return CultivationData.fromJson(results[0]);
  }

  /// キーワードで栽培情報を検索
  Future<List<CultivationData>> searchByName(String query) async {
    final config = await _getServerConfig();
    if (config == null) return [];

    final response = await http.get(
      Uri.parse(
          '${config.serverUrl}/cultivation-info?q=${Uri.encodeComponent(query)}'),
      headers: {
        if (config.token.isNotEmpty) 'Authorization': 'Bearer ${config.token}',
      },
    );

    if (response.statusCode != 200) return [];
    final data = jsonDecode(response.body);
    final results = data['results'] as List;
    return results.map((r) => CultivationData.fromJson(r)).toList();
  }

  /// サーバー設定が有効かチェック
  Future<bool> get isAvailable async {
    final config = await _getServerConfig();
    return config != null;
  }

  Future<_ServerConfig?> _getServerConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString('server_url');
    if (serverUrl == null || serverUrl.isEmpty) return null;
    final token = prefs.getString('server_token') ?? '';
    return _ServerConfig(serverUrl: serverUrl, token: token);
  }
}

class _ServerConfig {
  final String serverUrl;
  final String token;
  _ServerConfig({required this.serverUrl, required this.token});
}

/// 構造化された栽培情報データ
class CultivationData {
  final String? id;
  final String cropName;
  final String variety;
  final String sowingPeriod;
  final String harvestPeriod;
  final String spacing;
  final String depth;
  final String sunlight;
  final String watering;
  final String fertilizer;
  final String companionPlants;
  final String tips;
  final String rawText;
  final bool cached;

  CultivationData({
    this.id,
    this.cropName = '',
    this.variety = '',
    this.sowingPeriod = '',
    this.harvestPeriod = '',
    this.spacing = '',
    this.depth = '',
    this.sunlight = '',
    this.watering = '',
    this.fertilizer = '',
    this.companionPlants = '',
    this.tips = '',
    this.rawText = '',
    this.cached = false,
  });

  factory CultivationData.fromJson(Map<String, dynamic> json) =>
      CultivationData(
        id: json['id'] as String?,
        cropName: (json['cropName'] as String?) ?? '',
        variety: (json['variety'] as String?) ?? '',
        sowingPeriod: (json['sowingPeriod'] as String?) ?? '',
        harvestPeriod: (json['harvestPeriod'] as String?) ?? '',
        spacing: (json['spacing'] as String?) ?? '',
        depth: (json['depth'] as String?) ?? '',
        sunlight: (json['sunlight'] as String?) ?? '',
        watering: (json['watering'] as String?) ?? '',
        fertilizer: (json['fertilizer'] as String?) ?? '',
        companionPlants: (json['companionPlants'] as String?) ?? '',
        tips: (json['tips'] as String?) ?? '',
        rawText: (json['rawText'] as String?) ?? '',
        cached: (json['cached'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'cropName': cropName,
        'variety': variety,
        'sowingPeriod': sowingPeriod,
        'harvestPeriod': harvestPeriod,
        'spacing': spacing,
        'depth': depth,
        'sunlight': sunlight,
        'watering': watering,
        'fertilizer': fertilizer,
        'companionPlants': companionPlants,
        'tips': tips,
        'rawText': rawText,
      };

  String toJsonString() => jsonEncode(toJson());

  /// 表示用に非空フィールドのリストを返す
  List<MapEntry<String, String>> get displayFields {
    final fields = <MapEntry<String, String>>[];
    if (sowingPeriod.isNotEmpty) fields.add(MapEntry('播種時期', sowingPeriod));
    if (harvestPeriod.isNotEmpty) fields.add(MapEntry('収穫時期', harvestPeriod));
    if (spacing.isNotEmpty) fields.add(MapEntry('株間', spacing));
    if (depth.isNotEmpty) fields.add(MapEntry('播種深さ', depth));
    if (sunlight.isNotEmpty) fields.add(MapEntry('日照', sunlight));
    if (watering.isNotEmpty) fields.add(MapEntry('水やり', watering));
    if (fertilizer.isNotEmpty) fields.add(MapEntry('施肥', fertilizer));
    if (companionPlants.isNotEmpty) {
      fields.add(MapEntry('コンパニオンプランツ', companionPlants));
    }
    if (tips.isNotEmpty) fields.add(MapEntry('栽培のコツ', tips));
    return fields;
  }
}
