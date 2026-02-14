import 'dart:convert';
import 'package:http/http.dart' as http;

/// ユーザーホームページの生成・デプロイサービス
class SiteService {
  final String serverUrl;
  final String serverToken;

  SiteService({required this.serverUrl, required this.serverToken});

  /// サーバーで HTML を生成して返す
  Future<String> generateHtml(SiteData data) async {
    final res = await http.post(
      Uri.parse('$serverUrl/sites/generate'),
      headers: {
        'Authorization': 'Bearer $serverToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data.toJson()),
    );

    if (res.statusCode != 200) {
      throw Exception('HTML生成に失敗しました: ${res.statusCode}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return json['html'] as String;
  }

  /// ユーザーの Cloudflare Pages にデプロイ
  Future<DeployResult> deploy({
    required SiteData site,
    required String cfAccountId,
    required String cfApiToken,
    required String projectName,
  }) async {
    final res = await http.post(
      Uri.parse('$serverUrl/sites/deploy'),
      headers: {
        'Authorization': 'Bearer $serverToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'site': site.toJson(),
        'cfAccountId': cfAccountId,
        'cfApiToken': cfApiToken,
        'projectName': projectName,
      }),
    );

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'デプロイに失敗しました');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return DeployResult(
      url: json['url'] as String? ?? '',
      projectUrl: json['projectUrl'] as String? ?? '',
    );
  }
}

class SiteData {
  final String farmName;
  final String farmDescription;
  final String farmLocation;
  final String farmPolicy;
  final String farmUsername;
  final List<SiteCrop> crops;
  final SiteSales sales;

  SiteData({
    required this.farmName,
    this.farmDescription = '',
    this.farmLocation = '',
    this.farmPolicy = '',
    this.farmUsername = '',
    this.crops = const [],
    SiteSales? sales,
  }) : sales = sales ?? SiteSales();

  Map<String, dynamic> toJson() => {
        'farmName': farmName,
        'farmDescription': farmDescription,
        'farmLocation': farmLocation,
        'farmPolicy': farmPolicy,
        'farmUsername': farmUsername,
        'crops': crops.map((c) => c.toJson()).toList(),
        'sales': sales.toJson(),
      };
}

class SiteCrop {
  final String cultivationName;
  final String variety;
  final String description;
  final List<String> photoUrls;

  SiteCrop({
    required this.cultivationName,
    this.variety = '',
    this.description = '',
    this.photoUrls = const [],
  });

  Map<String, dynamic> toJson() => {
        'cultivationName': cultivationName,
        'variety': variety,
        'description': description,
        'photoUrls': photoUrls,
      };
}

class SiteSales {
  final String description;
  final String contact;
  final List<SalesItem> items;

  SiteSales({
    this.description = '',
    this.contact = '',
    this.items = const [],
  });

  Map<String, dynamic> toJson() => {
        'description': description,
        'contact': contact,
        'items': items.map((i) => i.toJson()).toList(),
      };
}

class SalesItem {
  final String name;
  final String price;
  final String note;

  SalesItem({required this.name, required this.price, this.note = ''});

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'note': note,
      };
}

class DeployResult {
  final String url;
  final String projectUrl;

  DeployResult({required this.url, required this.projectUrl});
}
