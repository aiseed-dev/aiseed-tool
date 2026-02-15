import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_chat_service.dart';

/// 汎用AIサービス — チャット以外の単発AI処理（写真分析、要約など）
/// API key（Gemini / Claude 直接）とサーバー経由の両方に対応。
class AiService {
  final AiProvider provider;
  final String apiKey;
  final String model;
  final String? serverUrl;
  final String? serverToken;

  AiService({
    required this.provider,
    required this.apiKey,
    String? model,
    this.serverUrl,
    this.serverToken,
  }) : model = model ?? _defaultModel(provider);

  static String _defaultModel(AiProvider provider) {
    switch (provider) {
      case AiProvider.fastapi:
        return '';
      case AiProvider.gemini:
        return 'gemini-2.0-flash';
      case AiProvider.claude:
        return 'claude-haiku-4-5-20251001';
    }
  }

  bool get isConfigured {
    if (provider == AiProvider.fastapi) {
      return serverUrl != null && serverUrl!.isNotEmpty;
    }
    return apiKey.isNotEmpty;
  }

  /// SharedPreferences から設定を読み込んで生成
  static Future<AiService> fromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final providerIndex =
        prefs.getInt(kAiProviderPref) ?? AiProvider.gemini.index;
    final provider = AiProvider
        .values[providerIndex.clamp(0, AiProvider.values.length - 1)];
    return AiService(
      provider: provider,
      apiKey: prefs.getString(kAiApiKeyPref) ?? '',
      model: prefs.getString(kAiModelPref),
      serverUrl: prefs.getString('server_url'),
      serverToken: prefs.getString('server_token'),
    );
  }

  /// テキストのみのAIリクエスト
  Future<String> request(String prompt, {String? systemPrompt}) async {
    return _dispatch(prompt: prompt, systemPrompt: systemPrompt);
  }

  /// 画像付きAIリクエスト（写真分析など）
  Future<String> analyzeImage(
    String imagePath,
    String prompt, {
    String? systemPrompt,
  }) async {
    return _dispatch(
      prompt: prompt,
      systemPrompt: systemPrompt,
      imagePath: imagePath,
    );
  }

  Future<String> _dispatch({
    required String prompt,
    String? systemPrompt,
    String? imagePath,
  }) async {
    switch (provider) {
      case AiProvider.gemini:
        return _geminiRequest(prompt, systemPrompt, imagePath);
      case AiProvider.claude:
        return _claudeRequest(prompt, systemPrompt, imagePath);
      case AiProvider.fastapi:
        return _fastapiRequest(prompt, systemPrompt, imagePath);
    }
  }

  // ── Gemini（テキスト + マルチモーダル対応）──

  Future<String> _geminiRequest(
      String prompt, String? systemPrompt, String? imagePath) async {
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';

    final parts = <Map<String, dynamic>>[];

    // 画像がある場合 base64 で送信
    if (imagePath != null) {
      final bytes = await File(imagePath).readAsBytes();
      final base64Data = base64Encode(bytes);
      final mimeType = _mimeType(imagePath);
      parts.add({
        'inlineData': {'mimeType': mimeType, 'data': base64Data}
      });
    }
    parts.add({'text': prompt});

    final body = <String, dynamic>{
      'contents': [
        {
          'role': 'user',
          'parts': parts,
        }
      ],
      'generationConfig': {'maxOutputTokens': 2048},
    };

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      body['systemInstruction'] = {
        'parts': [
          {'text': systemPrompt}
        ]
      };
    }

    final resp = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (resp.statusCode != 200) {
      throw AiChatException(
          _parseError(resp.body, resp.statusCode), resp.statusCode);
    }

    final json = jsonDecode(resp.body);
    final candidates = json['candidates'] as List?;
    if (candidates != null && candidates.isNotEmpty) {
      final parts = candidates[0]['content']?['parts'] as List?;
      if (parts != null && parts.isNotEmpty) {
        return parts[0]['text'] as String? ?? '';
      }
    }
    return '';
  }

  // ── Claude（テキスト + マルチモーダル対応）──

  Future<String> _claudeRequest(
      String prompt, String? systemPrompt, String? imagePath) async {
    const apiUrl = 'https://api.anthropic.com/v1/messages';

    final content = <Map<String, dynamic>>[];

    if (imagePath != null) {
      final bytes = await File(imagePath).readAsBytes();
      final base64Data = base64Encode(bytes);
      final mimeType = _mimeType(imagePath);
      content.add({
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': mimeType,
          'data': base64Data,
        }
      });
    }
    content.add({'type': 'text', 'text': prompt});

    final body = <String, dynamic>{
      'model': model,
      'max_tokens': 2048,
      'messages': [
        {'role': 'user', 'content': content}
      ],
    };

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      body['system'] = systemPrompt;
    }

    final resp = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode(body),
    );

    if (resp.statusCode != 200) {
      throw AiChatException(
          _parseError(resp.body, resp.statusCode), resp.statusCode);
    }

    final json = jsonDecode(resp.body);
    final contentBlocks = json['content'] as List?;
    if (contentBlocks != null && contentBlocks.isNotEmpty) {
      return contentBlocks
          .where((b) => b['type'] == 'text')
          .map((b) => b['text'] as String)
          .join('\n');
    }
    return '';
  }

  // ── FastAPI サーバー経由 ──

  Future<String> _fastapiRequest(
      String prompt, String? systemPrompt, String? imagePath) async {
    if (serverUrl == null || serverUrl!.isEmpty) {
      throw AiChatException('サーバーURLが未設定です', 0);
    }

    // 画像がある場合はサーバーのvision APIを試す
    if (imagePath != null) {
      try {
        return await _fastapiVision(imagePath, prompt);
      } catch (_) {
        // vision API 失敗時はチャットAPIにフォールバック
      }
    }

    // チャットAPIを単発で使う（stream: false）
    final apiUrl = '${serverUrl!}/ai/chat';
    final body = <String, dynamic>{
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
      'max_tokens': 2048,
      'stream': false,
    };
    if (model.isNotEmpty) body['model'] = model;
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      body['system'] = systemPrompt;
    }

    final resp = await http.post(
      Uri.parse(apiUrl),
      headers: _serverHeaders(),
      body: jsonEncode(body),
    );

    if (resp.statusCode != 200) {
      throw AiChatException(
          _parseError(resp.body, resp.statusCode), resp.statusCode);
    }

    final json = jsonDecode(resp.body);
    final contentBlocks = json['content'] as List?;
    if (contentBlocks != null && contentBlocks.isNotEmpty) {
      return contentBlocks
          .where((b) => b['type'] == 'text')
          .map((b) => b['text'] as String)
          .join('\n');
    }
    // role + content が直接文字列の場合
    if (json['content'] is String) return json['content'];
    return '';
  }

  /// サーバーのvision/analyze エンドポイントで画像分析
  Future<String> _fastapiVision(String imagePath, String prompt) async {
    final apiUrl = '${serverUrl!}/vision/analyze';
    final request = http.MultipartRequest('POST', Uri.parse(apiUrl));
    request.headers.addAll(_serverHeaders());
    request.files
        .add(await http.MultipartFile.fromPath('file', imagePath));

    final streamedResp = await request.send();
    final resp = await http.Response.fromStream(streamedResp);

    if (resp.statusCode != 200) {
      throw AiChatException('Vision API error', resp.statusCode);
    }

    final json = jsonDecode(resp.body);
    final caption = json['caption'] as String? ?? '';
    final labels = (json['detections']?['labels'] as List?)
            ?.cast<String>()
            .join(', ') ??
        '';
    return [
      if (caption.isNotEmpty) caption,
      if (labels.isNotEmpty) '検出: $labels',
    ].join('\n');
  }

  Map<String, String> _serverHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (serverToken != null && serverToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $serverToken';
    }
    return headers;
  }

  String _mimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  String _parseError(String body, int statusCode) {
    try {
      final json = jsonDecode(body);
      return json['error']?['message'] ??
          json['detail'] ??
          'HTTP $statusCode';
    } catch (_) {
      return 'HTTP $statusCode';
    }
  }
}
